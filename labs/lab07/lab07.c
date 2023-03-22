#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "pico/stdlib.h"
#include "pico/float.h"     // Required for using single-precision variables.
#include "pico/double.h"    // Required for using double-precision variables.
#include "pico/multicore.h" // Required for using multiple cores on the RP2040.

//For the number of iterations to be performed by the algorithm (used in Lab 2)
// #define number_of_iterations 100000

/**
 * @brief  Function to get the enable status of the XIP cache
 */
bool get_xip_cache_en() {
    bool *cache_status = (bool *)XIP_CTRL_BASE; //Put the address of the XIP_CTRL_BASE (0x14000000) in cache_status

    return cache_status[0]; //return the value of EN in CTRL in register, true if enabled, false if disabled
}

/**
 * @brief  Function to set the enable status of the XIP cache
 */
bool set_xip_cache_en(bool cache_en) {
    bool *set_en_cache = (bool *)XIP_CTRL_BASE;
    *set_en_cache = cache_en;
    return true;
}

/**
 * @brief  Function to flush the XIP cache - used when using cache twice in a single program
 */
void flush_xip_cache() {
    bool *flush_cache = (bool *)XIP_CTRL_BASE + 0x04; //Flush register has an offset of 0x04 from XIP_CTRL_BASE
    *flush_cache = 1; // Write 1 to flush the cache
}

/**
 * @brief This function acts as the main entry-point for core #1.
 *        A function pointer is passed in via the FIFO with one
 *        incoming int used as a parameter. The function will
 *        provide an float return value by pushing it back on 
 *        the FIFO, which also indicates that the result is ready.
 */
void core1_entry() {
    while (1) {
        // 
        float (*func)() = (float(*)()) multicore_fifo_pop_blocking();
        int p = multicore_fifo_pop_blocking();
        float result = (*func)(p);
        multicore_fifo_push_blocking(result);
    }
}

/**
 * @brief  Wallis Product Float 
 *         Using single precision (float) floating-point representation
 * 
 * @param  int  number_of_iterations
 * @return int  pi
 */
float wallis_product_float (int number_of_iterations) {
    float product = 1; //pi/2
    float n = 0;
    for (int i = 1; i <= number_of_iterations; i++){
        n = i;
        product = product * (4*n*n)/(4*n*n - 1);
    }
    return product * 2; //pi
}

/**
 * @brief  Wallis Product Double 
 *         Using double precision (double) floating-point representation
 * 
 * @param  int  number_of_iterations
 * @return int  pi
 */
double wallis_product_double (int number_of_iterations) {
    double product = 1;//pi/2
    double n = 0;
    for (int i = 1; i <= number_of_iterations; i++){
        n = i;
        product = product * (4*n*n)/(4*n*n - 1);
    }
    return product * 2;//pi
}

// Main code entry point for core0.
int main() {
    const int    ITER_MAX   = 100000;

    stdio_init_all();
    multicore_launch_core1(core1_entry);
    //Actual value of pi:
    double pi = 3.14159265359;
    printf("Actual value of pi: %.11f\n", pi);

    // A. Cache is disabled
    set_xip_cache_en(0); // XIP cache is disabled
    printf("XIP CTRL REGISTER EN status: %d\n", get_xip_cache_en());

    // Code for sequential run goes here…
    //    Take snapshot of timer and store
    //    Run the single-precision Wallis approximation
    //    Run the double-precision Wallis approximation
    //    Take snapshot of timer and store
    //    Display time taken for application to run in sequential mode

    absolute_time_t sequential_time_start = get_absolute_time();
    //single-precision
    absolute_time_t wallis_single_start = get_absolute_time();
    float wallis_product_pi_float;
    wallis_product_pi_float = wallis_product_float(ITER_MAX);
    float wallis_product_pi_float_error = (float)pi - wallis_product_pi_float;
    absolute_time_t wallis_single_end = get_absolute_time();
    int64_t wallis_single_runtime = absolute_time_diff_us(wallis_single_start, wallis_single_end);
    //double precision
    absolute_time_t wallis_double_start = get_absolute_time();
    double wallis_product_pi_double;
    wallis_product_pi_double = wallis_product_double(ITER_MAX);
    double wallis_product_pi_double_error = pi - wallis_product_pi_double;
    absolute_time_t wallis_double_end = get_absolute_time();
    int64_t wallis_double_runtime = absolute_time_diff_us(wallis_double_start, wallis_double_end);
    absolute_time_t sequential_time_end = get_absolute_time();
    int64_t sequential_runtime = absolute_time_diff_us(sequential_time_start, sequential_time_end);

    printf("Sequential: \n");
    printf("Using single-precision floating-point representation: %.11f\n", wallis_product_pi_float);
    printf("Approximate Error: %.11f\n", wallis_product_pi_float_error);
    printf("Run time of single-precision floating-point function: %lld\n", wallis_single_runtime);
    printf("Using double-precision floating-point representation: %.11f\n", wallis_product_pi_double);
    printf("Approximate Error: %.11f\n", wallis_product_pi_double_error);
    printf("Run time of double-precision floating-point function: %lld\n", wallis_double_runtime);
    printf("Run time of sequential code: %lld\n", sequential_runtime);

    // Code for parallel run goes here
    //    Take snapshot of timer and store
    //    Run the single-precision Wallis approximation on one core
    //    Run the double-precision Wallis approximation on the other core
    //    Take snapshot of timer and store
    //    Display time taken for application to run in parallel mode

    absolute_time_t parallel_time_start = get_absolute_time();
    absolute_time_t wallis_double_parallel_start = get_absolute_time();

    ///Using core1 for single-precision calculation
    multicore_fifo_push_blocking((uintptr_t) &wallis_product_float);
    multicore_fifo_push_blocking(ITER_MAX); 
    //Using core0 for double-precision calculation (while core1 is also running)
    double wallis_product_pi_double_parallel = wallis_product_double(ITER_MAX);
    double wallis_product_pi_double_parallel_error = pi - wallis_product_pi_double_parallel;
    absolute_time_t wallis_double_parallel_end = get_absolute_time();
    int64_t wallis_double_parallel_runtime = absolute_time_diff_us(wallis_double_parallel_start, wallis_double_parallel_end);
    float wallis_product_pi_float_parallel = multicore_fifo_pop_blocking();
    float wallis_product_pi_float_parallel_error = (float)pi - wallis_product_pi_float_parallel;
    absolute_time_t parallel_time_end = get_absolute_time();
    int64_t parallel_runtime = absolute_time_diff_us(parallel_time_start, parallel_time_end);

    printf("Parallel: \n");
    printf("Using single-precision floating-point representation: %.11f\n", wallis_product_pi_float_parallel);
    printf("Approximate Error: %.11f\n", wallis_product_pi_float_parallel_error);
    printf("Using double-precision floating-point representation: %.11f\n", wallis_product_pi_double_parallel);
    printf("Approximate Error: %.11f\n", wallis_product_pi_double_parallel_error);
    printf("Run time of double-precision floating-point function: %lld\n", wallis_double_parallel_runtime);
    printf("Run time of parallel code: %lld\n", parallel_runtime);

    printf("--------------------------------------------\n");
    // B. When Cache is enabled
    set_xip_cache_en(1); // XIP cache is enabled
    printf("XIP CTRL REGISTER EN status: %d\n", get_xip_cache_en());

    // Code for sequential run goes here…
    absolute_time_t sequential_time_start_cache = get_absolute_time();
    //single-precision
    absolute_time_t wallis_single_start_cache = get_absolute_time();
    float wallis_product_pi_float_cache;
    wallis_product_pi_float_cache = wallis_product_float(ITER_MAX);
    float wallis_product_pi_float_error_cache = (float)pi - wallis_product_pi_float_cache;
    absolute_time_t wallis_single_end_cache = get_absolute_time();
    int64_t wallis_single_runtime_cache = absolute_time_diff_us(wallis_single_start_cache, wallis_single_end_cache);
    //double precision
    absolute_time_t wallis_double_start_cache = get_absolute_time();
    double wallis_product_pi_double_cache;
    wallis_product_pi_double_cache = wallis_product_double(ITER_MAX);
    double wallis_product_pi_double_error_cache = pi - wallis_product_pi_double_cache;
    absolute_time_t wallis_double_end_cache = get_absolute_time();
    int64_t wallis_double_runtime_cache = absolute_time_diff_us(wallis_double_start_cache, wallis_double_end_cache);
    absolute_time_t sequential_time_end_cache = get_absolute_time();
    int64_t sequential_runtime_cache = absolute_time_diff_us(sequential_time_start_cache, sequential_time_end_cache);

    printf("Sequential: \n");
    printf("Using single-precision floating-point representation: %.11f\n", wallis_product_pi_float_cache);
    printf("Approximate Error: %.11f\n", wallis_product_pi_float_error_cache);
    printf("Run time of single-precision floating-point function: %lld\n", wallis_single_runtime_cache);
    printf("Using double-precision floating-point representation: %.11f\n", wallis_product_pi_double_cache);
    printf("Approximate Error: %.11f\n", wallis_product_pi_double_error_cache);
    printf("Run time of double-precision floating-point function: %lld\n", wallis_double_runtime_cache);
    printf("Run time of sequential code: %lld\n", sequential_runtime_cache);

    //Flush the cache memory
    flush_xip_cache();

    // Code for parallel run goes here
    absolute_time_t parallel_time_start_cache = get_absolute_time();
    absolute_time_t wallis_double_parallel_start_cache = get_absolute_time();

    ///Using core1 for single-precision calculation
    multicore_fifo_push_blocking((uintptr_t) &wallis_product_float);
    multicore_fifo_push_blocking(ITER_MAX); 
    //Using core0 for double-precision calculation (while core1 is also running)
    double wallis_product_pi_double_parallel_cache = wallis_product_double(ITER_MAX);
    double wallis_product_pi_double_parallel_error_cache = pi - wallis_product_pi_double_parallel_cache;
    absolute_time_t wallis_double_parallel_end_cache = get_absolute_time();
    int64_t wallis_double_parallel_runtime_cache = absolute_time_diff_us(wallis_double_parallel_start_cache, wallis_double_parallel_end_cache);
    float wallis_product_pi_float_parallel_cache = multicore_fifo_pop_blocking();
    float wallis_product_pi_float_parallel_error_cache = (float)pi - wallis_product_pi_float_parallel_cache;
    absolute_time_t parallel_time_end_cache = get_absolute_time();
    int64_t parallel_runtime_cache = absolute_time_diff_us(parallel_time_start_cache, parallel_time_end_cache);

    printf("Parallel: \n");
    printf("Using single-precision floating-point representation: %.11f\n", wallis_product_pi_float_parallel_cache);
    printf("Approximate Error: %.11f\n", wallis_product_pi_float_parallel_error_cache);
    printf("Using double-precision floating-point representation: %.11f\n", wallis_product_pi_double_parallel_cache);
    printf("Approximate Error: %.11f\n", wallis_product_pi_double_parallel_error_cache);
    printf("Run time of double-precision floating-point function: %lld\n", wallis_double_parallel_runtime_cache);
    printf("Run time of parallel code: %lld\n", parallel_runtime_cache);


    // Returning zero indicates everything went okay.
    return 0;
}