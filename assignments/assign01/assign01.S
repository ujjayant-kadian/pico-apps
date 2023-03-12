@ Ujjayant Kadian
@ 22330954
#include "hardware/regs/addressmap.h"
#include "hardware/regs/io_bank0.h"
#include "hardware/regs/timer.h"
#include "hardware/regs/m0plus.h"

.syntax unified
.cpu    cortex-m0plus
.thumb
.global main_asm
.align  4

.equ    DFLT_STATE_STRT, 1            @ Specify the value to start flashing
.equ    DFLT_STATE_STOP, 0            @ Specify the value to stop flashing
.equ    DFLT_ALARM_TIME, 1000000      @ Specify the default alarm timeout

.equ    GPIO_BTN_DN_MSK, 0x00040000   @ Bit-18 for falling-edge event on GP20
.equ    GPIO_BTN_EN_MSK, 0x00400000   @ Bit-22 for falling-edge event on GP21
.equ    GPIO_BTN_UP_MSK, 0x04000000   @ Bit-26 for falling-edge event on GP22

.equ    GPIO_BTN_DN,  20              @ Specify pin for the "down" button
.equ    GPIO_BTN_EN,  21              @ Specify pin for the "enter" button
.equ    GPIO_BTN_UP,  22              @ Specify pin for the "up" button
.equ    GPIO_LED_PIN, 25              @ Specify pin for the built-in LED
.equ    GPIO_DIR_IN,   0              @ Specify input direction for a GPIO pin
.equ    GPIO_DIR_OUT,  1              @ Specify output direction for a GPIO pin

.equ    LED_VAL_ON,    1              @ Specify value that turns the LED "on"
.equ    LED_VAL_OFF,   0              @ Specify value that turns the LED "off"

.equ    GPIO_ISR_OFFSET, 0x74         @ GPIO is int #13 (vector table entry 29)
.equ    ALRM_ISR_OFFSET, 0x40         @ ALARM0 is int #0 (vector table entry 16)

@ Entry point to the ASM portion of the program
main_asm:
        bl      init_gpio_led         @ Go to subroutine for initialising GPIO LED pin
        bl      init_gpio_btns        @ Go to subroutine for initilaising the required GPIO pins
        bl      install_alrm_isr      @ Install the alarm interrupt service routine
        bl      install_gpio_isr      @ Install the GPIO interrupt service routine
main_loop:
        bl      set_alarm             @ Subroutine for setting alarm with required delay
        wfi                           @ Wait until an interrupt occurs
        b       main_loop             @ Jump back to the start of main_loop  

@ Subroutine used to initialise the PI Pico built-in LED
init_gpio_led:
        push    {lr}                  @ Store the link register to the stack (as we call subroutines)

        movs    r0, #GPIO_LED_PIN     @ This value is the GPIO LED pin on the PI PICO board
        bl      asm_gpio_init         @ Call the subroutine to initialise the GPIO pin specified by r0
        movs    r0, #GPIO_LED_PIN     @ This value is the GPIO LED pin on the PI PICO board
        movs    r1, #GPIO_DIR_OUT     @ We want this GPIO pin to be setup as an output pin
        bl      asm_gpio_set_dir      @ Call the subroutine to set the GPIO pin specified by r0 to state specified by r1

        pop     {pc}                  @ Pop the link register from the stack to the program counter

@ Subroutine used to initialise the GPIO PINS 20(down), 21(enter), 22(up)
init_gpio_btns:
        push    {lr}                  @ Store the link register to the stack (as we call subroutines)

        movs    r0, #GPIO_BTN_DN      @ This value is the GPIO down button pin on the PI PICO board
        bl      asm_gpio_init         @ Call the subroutine to initialise the GPIO pin specified by r0
        movs    r0, #GPIO_BTN_DN      @ This value is the GPIO down button pin on the PI PICO board
        movs    r1, #GPIO_DIR_IN      @ We want this GPIO pin to be setup as an input pin
        bl      asm_gpio_set_dir      @ Call the subroutine to set the GPIO pin specified by r0 to state specified by r1
        movs    r0, #GPIO_BTN_DN      @ This value is the GPIO down button pin on the PI PICO board
        bl      asm_gpio_set_irq      @ Call the subroutine to enable interrupts at the falling edge for the button

        movs    r0, #GPIO_BTN_EN      @ This value is the GPIO enter button pin on the PI PICO board
        bl      asm_gpio_init         @ Call the subroutine to initialise the GPIO pin specified by r0
        movs    r0, #GPIO_BTN_EN      @ This value is the GPIO enter button pin on the PI PICO board
        movs    r0, #GPIO_DIR_IN      @ We want this GPIO pin to be setup as an input pin
        bl      asm_gpio_set_dir      @ Call the subroutine to set the GPIO pin specified by r0 to state specified by r1
        movs    r0, #GPIO_BTN_EN      @ This value is the GPIO enter button pin on the PI PICO board
        bl      asm_gpio_set_irq      @ Call the subroutine to enable interrupts at the falling edge for the button

        movs    r0, #GPIO_BTN_UP      @ This value is the GPIO up button pin on the PI PICO board
        bl      asm_gpio_init         @ Call the subroutine to initialise the GPIO pin specified by r0
        movs    r0, #GPIO_BTN_UP      @ This value is the GPIO up button pin on the PI PICO board
        movs    r1, #GPIO_DIR_IN      @ We want this GPIO pin to be setup as an input pin
        bl      asm_gpio_set_dir      @ Call the subroutine to set the GPIO pin specified by r0 to state specified by r1
        movs    r0, #GPIO_BTN_UP      @ This value is the GPIO up button pin on the PI PICO board
        bl      asm_gpio_set_irq      @ Call the subroutine to enable interrupts at the falling edge for the button

        pop     {pc}                  @ Pop the link register from the stack to the program counter

@ Set alarm with the corresponding delay
set_alarm:
        @ Enable the alarm timer interrupts
        ldr     r2, =TIMER_BASE                @ Load the address pointed to by TIMER_BASE into r2
        ldr     r1, =1                         @ Load 1 into r1 to set TIMER_INTE HIGH
        str     r1, [r2, #TIMER_INTE_OFFSET]   @ store r1 to address of TIMER_BASE with offset of TIMER_INTE_OFFSET - to enable alarm timer interrupts
        @ Get the current timer count and add time delay
        ldr     r1, [r2, #TIMER_TIMELR_OFFSET] @ Load r1 with address of TIMER_BASE with offset of TIMER_TIMELR_OFFSET - load current timer count in r1
        ldr     r3, =ltimer                    @ Load address of default alarm timeout into r3
        ldr     r0, [r3]                       @ Load the value stored in r3 into r0
        add     r1, r0                         @ Add default alarm timeout to current timer count - add the time delay
        str     r1, [r2, #TIMER_ALARM0_OFFSET] @ Store this value at TIMER_BASE + TIMER_ALARM0_OFFSET
        bx      lr                             @ Return to main_loop
.align 4
msg:    .asciz "Hello World!\n"

.data
lstate: .word   DFLT_STATE_STRT
ltimer: .word   DFLT_ALARM_TIME