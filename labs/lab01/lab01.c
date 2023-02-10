#include "pico/stdlib.h"

uint LED_STATE = 0;

void blink_led (uint LED_PIN, uint LED_DELAY) {
    
    
    gpio_put(LED_PIN, LED_STATE);
    sleep_ms(LED_DELAY);

    LED_STATE = !LED_STATE;

}
int main() {

    // Specify the PIN number and sleep delay
    const uint LED_PIN   =  25;
    const uint LED_DELAY = 500;

    // Setup the LED pin as an output.
    gpio_init(LED_PIN);
    gpio_set_dir(LED_PIN, GPIO_OUT);

    // Do forever...
    while (true) {
        blink_led(LED_PIN, LED_DELAY);
    }

    // Should never get here due to infinite while-loop.
    return 0;

}