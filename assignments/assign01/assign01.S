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
        movs    r1, #GPIO_DIR_IN      @ We want this GPIO pin to be setup as an input pin
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
        ldr     r2, =TIMER_BASE                @ Load the address pointed to by TIMER_BASE into r2
        movs    r1, #1                         @ Move 1 into r1 to set TIMER_INTE HIGH
        str     r1, [r2, #TIMER_INTE_OFFSET]   @ Store r1 to address of TIMER_BASE with offset of TIMER_INTE_OFFSET - to enable alarm timer interrupts

        ldr     r1, [r2, #TIMER_TIMELR_OFFSET] @ Load r1 with the value at address of TIMER_BASE with offset of TIMER_TIMELR_OFFSET - load current timer count in r1
        ldr     r3, =ltimer                    @ Load address of default alarm timeout into r3
        ldr     r0, [r3]                       @ Load the value stored in r3 into r0
        add     r1, r0                         @ Add default alarm timeout to current timer count - add the time delay

        str     r1, [r2, #TIMER_ALARM0_OFFSET] @ Store this value at TIMER_BASE + TIMER_ALARM0_OFFSET
        bx      lr                             @ Return to main_loop

@ Subroutine used to install the alarm interrupt service handler
install_alrm_isr:
        ldr     r2, =(PPB_BASE + M0PLUS_VTOR_OFFSET)    @ Load r2 with address of PPB_BASE added to M0PLUS_VTOR_OFFSET - load address of vector table in r2
        ldr     r1, [r2]                                @ Load r1 with the value at address stored in r2
        movs    r2, #ALRM_ISR_OFFSET                    @ Move the ALRM_ISR_OFFSET in r2
        add     r2, r1                                  @ Add the vector table address and the offset and store it in r2
        ldr     r0, =alrm_isr                           @ Load address of alarm service handler into r0
        str     r0, [r2]                                @ Store the address of alarm service handler to correct offset in vector table

        movs    r0, #1                                  @ Move 1 into r0 to set values high in the corresponding registers
        ldr     r1, =(PPB_BASE+M0PLUS_NVIC_ICPR_OFFSET) @ Load r1 with address of PPB_BASE added to M0PLUS_NVIC_ICPR_OFFSET
        str     r0, [r1]                                @ Store 1 in this register address to disable the alarm interrupt requests
        ldr     r1, =(PPB_BASE+M0PLUS_NVIC_ISER_OFFSET) @ Load r1 with address of PPB_BASE added to M0PLUS_NVIC_ISER_OFFSET
        str     r0, [r1]                                @ Store 1 in this register to enable the alarm interrupt requests
	
	bx      lr                                      @ Return to main_asm

@ Alarm interrupt service handler routine
.thumb_func @ Required for all interrupt service routines
alrm_isr:
        push    {lr}                           @ Store the link register to the stack (as we call subroutines)

        ldr     r0, =alrm_event                @ Load the statement to be displayed
        bl      printf                         @ Print the statement

        ldr     r2, =TIMER_BASE                @ Load the address pointed to by TIMER_BASE into r2
        movs    r1, #1                         @ Load 1 into r1 to set the ICPR (interrupt clear-pending register) high
        str     r1, [r2, #TIMER_INTR_OFFSET]   @ Store r1 to address of TIMER_BASE with offset of TIMER_INTR_OFFSET - to clear pending alarm timer interrupts

        ldr     r2, =enter_state               @ Load the address of enter_state into r2
        ldr     r1, [r2]                       @ Load r1 with the value at address stored in r2
        movs    r3, #0                         @ For comparing enter_state
        cmp     r1, r3                         @ If the current alarm enter state is low then
        beq     alrm_isr_done                  @ No need to fire an interrupt - LED state should remain the same, OTHERWISE

        ldr     r2, =lstate                    @ Load the address of lstate into r2
        ldr     r1, [r2]                       @ Load r1 with the value at address stored in r2
        movs    r3, #1                         @ For comparing led state
        cmp     r1, r3                         @ If the current led state is high then turn off the led
        beq     led_set_off
led_set_on:
        movs    r1, #LED_VAL_ON                @ Move the HIGH value (1) into r1
        ldr     r2, =lstate                    @ Load the address of lstate
        str     r1, [r2]                       @ Store the current state of LED in lstate
        b       led_set_state                  @ Set the LED state
led_set_off:
        movs    r1, #LED_VAL_OFF                @ Move the LOW value (0) into r1
        ldr     r2, =lstate                    @ Load the address of lstate
        str     r1, [r2]                       @ Store the current state of LED in lstate
led_set_state:
        movs    r0, #GPIO_LED_PIN              @ This value is the GPIO LED pin on the PI PICO board
        bl      asm_gpio_put                   @ Update the value of the LED GPIO pin (based on value in r1)
alrm_isr_done:
        pop     {pc}                           @ Pop the link register from the stack to the program counter - return from the interrupt service

@ Subroutine used to install the alarm interrupt service handler
install_gpio_isr:
        ldr     r2, =(PPB_BASE + M0PLUS_VTOR_OFFSET)    @ Load r2 with address of PPB_BASE added to M0PLUS_VTOR_OFFSET - load address of vector table in r2
        ldr     r1, [r2]                                @ Load r1 with the value at address stored in r2
        movs    r2, #GPIO_ISR_OFFSET                    @ Move the GPIO_ISR_OFFSET in r2
        add     r2, r1                                  @ Add the vector table address and the offset and store it in r2
        ldr     r0, =gpio_isr                           @ Load address of GPIO service handler into r0
        str     r0, [r2]                                @ Store the address of GPIO service handler to correct offset in vector table

        ldr    r0, =8192                                @ Move 8192 (2^13) into r1 so that we can disable and enable the GPIO interrupt requests
        ldr     r1, =(PPB_BASE+M0PLUS_NVIC_ICPR_OFFSET) @ Load r1 with address of PPB_BASE added to M0PLUS_NVIC_ICPR_OFFSET
        str     r0, [r1]                                @ Store 8192 in this register address to disable the gpio interrupt requests
        ldr     r1, =(PPB_BASE+M0PLUS_NVIC_ISER_OFFSET) @ Load r1 with address of PPB_BASE added to M0PLUS_NVIC_ISER_OFFSET
        str     r0, [r1]                                @ Store 8192 in this register address to enable the gpio interrupt requests

@ GPIO interrupt service handler routine
.thumb_func @ Required for all interrupt service routines
gpio_isr:
        push    {lr}                                                @ Store the link register to the stack (as we call subroutines)
        
        ldr     r2, =(IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET)  @ Load r2 with address of IO_BANK0_BASE added to IO_BANK0_PROC0_INTS2_OFFSET - load address of interrupt status event register in r2
        ldr     r1, [r2]                                            @ Load r1 with the value (interrupt status) at address stored in r2
        ldr     r2, =(IO_BANK0_BASE+IO_BANK0_INTR2_OFFSET)          @ Load r2 with address of IO_BANK0_BASE added to IO_BANK0_INTR2_OFFSET
        str     r1, [r2]                                            @ Store the value in r1 in this register address to disable the gpio interrupt requests

        ldr     r0, =GPIO_BTN_EN_MSK                                @ Load mask for the enter button into r0
        cmp     r1, r0                                              @ Compare the interrupt status and enter button mask to check if enter button was pressed
        beq     btn_enter                                           @ If pressed go to btn_enter

        ldr     r2, =enter_state                                    @ Load the address of enter_state into r2
        ldr     r4, [r2]                                            @ Load this state value into r4
        movs    r3, #0                                              @ To check current enter_state = 0
        cmp     r4, r3                                              @ Compare current enter_state with 0
        beq     ltimer_reset                                        @ If current enter state is low reset blinking speed

        ldr     r0, =GPIO_BTN_DN_MSK                                @ Load mask for the down button into r0
        cmp     r1, r0                                              @ Compare the interrupt status and down button mask to check if down button was pressed
        beq     btn_down                                            @ If pressed go to btn_down 

        ldr     r0, =GPIO_BTN_UP_MSK                                @ Load mask for the up button into r0
        cmp     r1, r0                                              @ Compare the interrupt status and up button mask to check if up button was pressed
        beq     btn_up                                              @ If pressed go to btn_up
        
        b       gpio_isr_done                                       @ Otherwise, disable interrupt requests
ltimer_reset:
        ldr     r0, =reset_speed               @ Load the statement to be displayed
        bl      printf                         @ Print the statement

        ldr     r1, =DFLT_ALARM_TIME           @ Load DFLT_ALARM_TIME into r1
        ldr     r2, =ltimer                    @ Load address of ltimer into r2
        str     r1, [r2]                       @ Store the default alarm time (DFLT_ALARM_TIME) in ltimer
        b       gpio_isr_done                  @ Proceed to end of the subroutine 

btn_down: 
        ldr     r0, =down_btn_pressed          @ Load the statement to be displayed
        bl      printf                         @ Print the statement

        ldr     r2, =ltimer                    @ Load address of ltimer into r2
        ldr     r1, [r2]                       @ Load value of the current time delay into r1
        movs    r4, r1, lsl #1                 @ Shift bits to the right by 1 to double the current time delay - decrease speed
        ldr     r2, =ltimer                    @ Load address of ltimer into r2
        str     r4, [r2]                       @ Store the new time delay in ltimer
        b       gpio_isr_done                  @ Proceed to end of the subroutine 
btn_up: 
        ldr     r0, =up_btn_pressed            @ Load the statement to be displayed
        bl      printf                         @ Print the statement

        ldr     r2, =ltimer                    @ Load address of ltimer into r2
        ldr     r1, [r2]                       @ Load value of the current time delay into r1
        movs    r0, r1, lsr #1                 @ Shift bits to the left by 1 to half the current time delay - increase speed
        ldr     r2, =ltimer                    @ Load address of ltimer into r2
        str     r0, [r2]                       @ Store the new time delay in ltimer
        b       gpio_isr_done                  @ Proceed to end of the subroutine 
btn_enter:
        ldr     r0, =enter_btn_pressed         @ Load the statement to be displayed
        bl      printf                         @ Print the statement

        ldr     r2, =enter_state               @ Load address of the enter_state into r2
        ldr     r1, [r2]                       @ Load value of the current enter_state into r1
        movs    r3, #1                         @ To check if current enter_state is 1
        cmp     r1, r3                         @ Compare current enter_state with 1
        beq     enter_off                      @ If current enter_state is 1, set it to 0
enter_on:	
        movs    r1, #1                         @ Move 1 into r1 to set current_enter state as 1
        ldr     r2, =enter_state               @ Load address of enter_state into r2
        str     r1, [r2]                       @ Store the new enter_state value
        b       gpio_isr_done                  @ Proceed to end of the subroutine 
enter_off:	
        movs    r1, #0                         @ Move 0 into r1 to set current_enter state as 0
        ldr     r2, =enter_state               @ Load address of enter_state into r2
        str     r1, [r2]                       @ Store the new enter_state value

gpio_isr_done:
        pop     {pc}                           @ Pop the link register from the stack to the program counter


.align 4
reset_speed:          .asciz "Speed Reset!\n"
alrm_event:           .asciz "Alarm Event Occurred!\n"
enter_btn_pressed:    .asciz "Enter Button Pressed! Flashing behaviour toggled\n"
up_btn_pressed:       .asciz "Up Button Pressed! Flashing speed doubled\n"
down_btn_pressed:     .asciz "Down Button Pressed! Flashing speed halved\n"

.data
lstate:        .word   DFLT_STATE_STRT
ltimer:        .word   DFLT_ALARM_TIME
enter_state:  .word    1                 @ To toggle current state of LED based on the previous enter state (enter button) value