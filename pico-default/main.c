/*
 * MIT License
 *
 * Copyright (c) 2023 tinyVision.ai
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

// pico-sdk
#include "pico/stdlib.h"
#include "pico/stdio.h"
#include "hardware/irq.h"
#include "hardware/gpio.h"
#include "hardware/uart.h"

// pico-ice-sdk
#include "ice_usb.h"
#include "ice_fpga.h"
#include "ice_led.h"
#include "ice_sram.h"
#include "ice_fram.h"
#include "ice_spi.h"

//#include "sram.h"

#include "logic_analyser.h"

void test_spi();

#define UART_TX_PIN 0
#define UART_RX_PIN 1

int main(void) {
    set_sys_clock_khz(120 * 1000, true);
    stdio_init_all();

    ice_fpga_stop();

    // Enable the UART
    uart_init(uart0, 115200);
    gpio_set_function(UART_TX_PIN, GPIO_FUNC_UART);
    gpio_set_function(UART_RX_PIN, GPIO_FUNC_UART);

    // Configure the piping as defined in <tusb_config.h>
    ice_usb_init();
    tud_task();

#if 0
    for (int i = 0; i < 5000; ++i) {
        sleep_ms(1);
        tud_task();
    }
    printf("Hello world\n");
#endif

    //setup_simulated_sram();

#if 0
    ice_fram_init(true);

    uint8_t id[4];
    ice_fram_get_id(id);
    printf("FRAM ID: %02x:%02x:%02x:%02x\n", id[0], id[1], id[2], id[3]);
#endif

    //ice_sram_init();
    //ice_sram_read_blocking(0, emu_ram, 65536);
    //gpio_set_dir(ICE_SRAM_CS_PIN, GPIO_IN);

    // Let the FPGA start
    ice_fpga_init(12);
    ice_fpga_start();

    // Prevent the LEDs from glowing slightly
    ice_led_init();

#if 0
    for (int i = 0; i < 1000; ++i) {
        sleep_ms(1);
        tud_task();
    }

    // Arm the LA
    logic_analyser_init(pio0, 3, 5, 10000, 50);
    logic_analyser_arm(4, false);

    //logic_analyser_print_capture_buf();
#endif

#if 0
    gpio_init(5);
    gpio_put(5, 1);
    gpio_set_dir(5, GPIO_OUT);
#endif

#if 0
    for (int i = 0; i < 1000; ++i) {
        sleep_ms(1);
        tud_task();
    }
    test_spi();
#endif

    bool done_capture = false;
    while (true) {
        tud_task();
#if 0
        if (!done_capture && logic_analyser_is_capture_done()) {
            done_capture = true;
            logic_analyser_print_capture_buf(2500);
        }
#endif
    }
    return 0;
}
