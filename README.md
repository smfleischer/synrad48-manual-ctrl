# Generate the CTRL signal for a Synrad 48 type CO2 laser

Allows to generate the required PWM signal using an ATmega8 microcontroller.
Expects a 10k potentiometer between +5V and GND, with the wiper connected to
ADC0 (pin 23) and a 4Mhz crystal oscillator as external clock. The CTRL
signal is generated at OC1A (pin 15).

If the pot is in the lower ~20% of its range, just generate the "tickle"
signal required by the laser: 1μs square pulses of +5V at a 5kHz repetition
rate. For higher settings of the potentiometer, keep the PWM frequency but
proportionally increase to duty cycle up to ~100%.
