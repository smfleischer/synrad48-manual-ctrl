; Generate the CTRL signal for a Synrad 48 type CO2 laser
; 
; Allows to generate the required PWM signal using an ATmega8 microcontroller.
; Expects a 10k potentiometer between +5V and GND, with the wiper connected to
; ADC0 (pin 23) and a 4Mhz crystal oscillator as external clock. The CTRL
; signal is generated at OC1A (pin 15).
; 
; If the pot is in the lower ~20% of its range, just generate the "tickle"
; signal required by the laser: 1us square pulses of +5V at a 5kHz repetition
; rate. For higher settings of the potentiometer, keep the PWM frequency but
; proportionally increase to duty cycle up to ~100%.

    .include "m7def.inc"

    .def tmp1 = r16                      ; general purpose working registers
    .def tmp2 = r17
    .def width_l = r18                   ; pulse width for PWM output
    .def width_h = r19

    .equ XTAL = 4000000                  ; external clock frequency in Hz
    .equ CYCLES_IN_1us = 4               ; "tickle" pulse width in cycles
    .equ CYCLES_IN_200us = XTAL/5000     ; 200us = 1/5kHz (PWM frequency)
    .equ MOD_STEPS = 200                 ; no. of steps for PWM (255-55=200)

    rjmp init

init:
    ldi tmp1, HIGH(RAMEND)		; initialize stack pointer
    out SPH, tmp1
    ldi tmp1, LOW(RAMEND)
    out SPL, tmp1
    

    ; Set up timer 1 for PWM

    ; Mode 14: fast PWM, TOP from ICR1 -> WGM1 bits 3:0  1110
    ; prescaler 1 -> CS1 bits 2:0  001 
    ; set at bottom, clear at match -> COM1A bits 1:0  10
    
    ldi tmp1, 1<<COM1A1 | 1<<WGM11
    out TCCR1A, tmp1

    ldi tmp1, 1<<WGM13 | 1<<WGM12 | 1<<CS10
    out TCCR1B, tmp1

    ; set TOP for counter (ICR1) to 799 (0x31f): 4.0MHz / 800 = 5kHz
    ldi tmp1, HIGH(CYCLES_IN_200us-1)
    out ICR1H, tmp1
    ldi tmp1, LOW(CYCLES_IN_200us-1)
    out ICR1L, tmp1

    ; compare value; OC1A switched off when counter reaches this value
    ; 4 cycles gives 1us pulse
    ldi tmp1, HIGH(CYCLES_IN_1us-1)      ; this is zero anyway
    out OCR1AH, tmp1
    ldi tmp1, LOW(CYCLES_IN_1us-1)
    out OCR1AL, tmp1

    ; set OC1A(PB1) to output in data direction register B (DDRB)
    sbi DDRB, DDB1
    

    ; set up ADC1
    ; int. reference AVcc, left adjust result (ADLAR), MUX to ADC0
    ; REFS bits 1:0  01, MUX bits 3:0  0000
    ldi tmp1, 1<<REFS0 | 1<<ADLAR | 0x00
    out ADMUX, tmp1
    
    ; in ADCSRA:
    ; ADC enable, ADC Free Running, ADC start conversion, prescaler 32
    ; ASPS bits 2:0  101 (0x05)
    ldi tmp1, 1<<ADEN | 1<<ADFR | 1<<ADSC | 0x05
    out ADCSRA, tmp1


main:
    ; check if new ADC value is available; if not jump to start of loop
    in tmp1, ADCSRA
    ANDI tmp1, 1<<ADIF
    breq main

    ; OK, we have a new ADC value!

    ; get latest ADC conversion result as 8bit value
    in tmp1, ADCH

    ; default pulse width (1us "tickle")
    ldi width_h, HIGH(CYCLES_IN_1us-1)
    ldi width_l, LOW(CYCLES_IN_1us-1)

    ; subtract 55 to create a threshold before turning on laser:
    ; if ADC value < 55, stick with 1us pulse length 
    subi tmp1, 55
    brcs setwidth

    ; otherwise lengthen pulse proportionally
    ldi tmp2, (CYCLES_IN_200us/MOD_STEPS) ; multiplier to reach 100% duty cycle
    mul tmp1, tmp2

    add width_l, r0   ; add result to prev. set default width (low byte)   
    adc width_h, r1   ; ...and high byte

setwidth:
    ; write to OCR1AL to set PWM pulse length
    out OCR1AH, width_h
    out OCR1AL, width_l
    sbi ADCSRA, ADIF   ; clear ADC interrupt flag (AVR does this by writing 1)

    rjmp main          ; ...and loop back for the next round

