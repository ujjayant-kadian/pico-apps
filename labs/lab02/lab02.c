// #define WOKWI             // Uncomment if running on Wokwi RP2040 emulator.

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "pico/stdlib.h"
#include "pico/float.h"     // Required for using single-precision variables.
#include "pico/double.h"    // Required for using double-precision variables.

//For the number of iterations to be performed by the algorithm
#define number_of_iterations 100000

//Using single precision (float) floating-point representation
float wallis_product_float () {
    float product = 1; //pi/2
    float n = 0;
    for (int i = 1; i <= number_of_iterations; i++){
        n = i;
        product = product * (4*n*n)/(4*n*n - 1);
    }
    return product * 2; //pi
}

//Using double precision (double) floating-point representation
double wallis_product_double () {
    double product = 1;//pi/2
    double n = 0;
    for (int i = 1; i <= number_of_iterations; i++){
        n = i;
        product = product * (4*n*n)/(4*n*n - 1);
    }
    return product * 2;//pi
}

int main() {
    
#ifndef WOKWI
    // Initialise the IO as we will be using the UART
    // Only required for hardware and not needed for Wokwi
    stdio_init_all();
#endif

    // Print a console message to inform user what's going on.

    //Actual value of pi:
    double pi = 3.14159265359;
    printf("Actual value of pi: %.11f\n", pi);

    //single-precision
    float wallis_product_pi_float;
    wallis_product_pi_float = wallis_product_float();
    printf("Using single-precision floating-point representation: %.11f\n", wallis_product_pi_float);
    printf("Approximate Error: %.11f\n", pi - wallis_product_pi_float);

    //double-precision
    double wallis_product_pi_double;
    wallis_product_pi_double = wallis_product_double();
    printf("Using double-precision floating-point representation: %.11f\n", wallis_product_pi_double);
    printf("Approximate Error: %.11f\n", pi - wallis_product_pi_double);

    // Returning zero indicates everything went okay.
    return 0;
}