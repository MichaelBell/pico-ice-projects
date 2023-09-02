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
#include "pico/multicore.h"
#include "hardware/irq.h"
#include "hardware/gpio.h"
#include "hardware/uart.h"
#include "hardware/dma.h"
#include "hardware/adc.h"

#include <math.h>

// pico-ice-sdk
#include "ice_usb.h"
#include "ice_fpga.h"
#include "ice_led.h"

#include "fft.pio.h"

#include "logic_analyser.h"
#include "st7789_lcd.h"

#define PIN_RESETN 7

#define PIN_SAMPLE_CLK 2
#define PIN_SAMPLE_IN 3
#define PIN_SAMPLE_OUT 4
#define PIN_SAMPLE_SYNC 5

#define PIN_MIC 29

static int sample_in_num = 0;

static int out_idx = 0;
#define NUM_BINS 32
#define BIN_REPEATS 8
static uint16_t bins_out[NUM_BINS*BIN_REPEATS] __attribute__((aligned(2*NUM_BINS*BIN_REPEATS)));
static int max_bin;

static int fft_sm;
static int fft_rx_channel;
static int adc_tx_channel;
#define fft_pio pio0

static ST7789 lcd;
static uint32_t st7789_data_buf[1024];
static uint32_t st7789_ctrl_buf[1024];

static void send_sample(int period)
{
    const int delay = 1;
    float s = sinf(sample_in_num * (float)(2 * M_PI / period));
    if (++sample_in_num == 128) sample_in_num = 0;
    
    uint16_t val = 0x800 + s * 400;
#if 0
    uint16_t out_val = 0;

    //printf("%d %d\n", sample_in_num, val);

    for (int i = 0; i < 16; ++i) {
        gpio_put(PIN_SAMPLE_IN, val & 1);
        val >>= 1;
        sleep_us(delay);

        if (i < 12) {
            out_val >>= 1;
            if (gpio_get(PIN_SAMPLE_OUT)) out_val |= 0x800;
        }

        if (gpio_get(PIN_SAMPLE_SYNC)) {
            out_idx = 0;
            //printf("Sync at sample %d\n", sample_in_num);
            if (i != 0) printf("Misaligned sync at i=%d\n", i);
        }
        gpio_put(PIN_SAMPLE_CLK, 1);
        sleep_us(delay);
        gpio_put(PIN_SAMPLE_CLK, 0);
    }

    if (out_idx < NUM_BINS) {
        //printf(" %d %d\n", out_idx, out_val);
        bins_out[out_idx++] = out_val;
    }

    if (out_idx == NUM_BINS) {
        uint16_t max_val = 0;
        for (int i = 0; i < NUM_BINS; ++i) {
            if (bins_out[i] > max_val) {
                max_val = bins_out[i];
                max_bin = i;
            }
        }
        printf("Max bin: %d  \r", max_bin);
        ++out_idx;
    }
#endif
    pio_sm_put_blocking(fft_pio, fft_sm, val);

#if 0
    while (!pio_sm_is_rx_fifo_empty(fft_pio, fft_sm)) {
        bins_out[out_idx++] = pio_sm_get(fft_pio, fft_sm);
        if (bins_out[out_idx-1] != 0) printf("%d\n", bins_out[out_idx-1]);
        if (out_idx == NUM_BINS) out_idx = 0;
    }
#endif

    if (sample_in_num == 0) {
        uint16_t max_val = 0;
        for (int i = 0; i < NUM_BINS; ++i) {
            if (bins_out[i] > max_val) {
                max_val = bins_out[i];
                max_bin = i;
            }
        }
        printf("Max bin: %d  value: %d \r", max_bin, max_val);
    }
}

static void setup_fft_pio() {
    fft_sm = pio_claim_unused_sm(fft_pio, true);
    int fft_offset = pio_add_program(fft_pio, &fft_program);
    fft_program_init(fft_pio, fft_sm, fft_offset, PIN_SAMPLE_CLK, PIN_SAMPLE_IN, PIN_SAMPLE_OUT, PIN_SAMPLE_SYNC);

    fft_rx_channel = dma_claim_unused_channel(true);

    dma_channel_config c = dma_channel_get_default_config(fft_rx_channel);
    channel_config_set_transfer_data_size(&c, DMA_SIZE_32);
    channel_config_set_dreq(&c, pio_get_dreq(fft_pio, fft_sm, false));
    channel_config_set_read_increment(&c, false);
    channel_config_set_write_increment(&c, true);
    channel_config_set_ring(&c, true, 10);  // LOG2(NUM_BINS*BIN_REPEATS)
    dma_channel_configure(fft_rx_channel, &c,
                          bins_out,              // write address
                          &fft_pio->rxf[fft_sm], // read address
                          0x7FFFFFFF,            // ~forever
                          true);

    adc_run(true);
}

static void start_adc() {
    adc_fifo_setup(
        true,    // Write each completed conversion to the sample FIFO
        true,    // Enable DMA data request (DREQ)
        1,       // DREQ (and IRQ) asserted when at least 1 sample present
        false,   // We won't see the ERR bit because of 8 bit reads; disable.
        false    // Shift each sample to 8 bits when pushing to FIFO
    );

    //adc_set_clkdiv(240); // 200kHz sample rate
    adc_set_clkdiv(4800); // 10kHz sample rate

    adc_tx_channel = dma_claim_unused_channel(true);

    dma_channel_config c = dma_channel_get_default_config(adc_tx_channel);
    channel_config_set_transfer_data_size(&c, DMA_SIZE_16);
    channel_config_set_dreq(&c, DREQ_ADC);
    channel_config_set_read_increment(&c, false);
    channel_config_set_write_increment(&c, false);
    dma_channel_configure(adc_tx_channel, &c,
                          &fft_pio->txf[fft_sm], // write address
                          &adc_hw->fifo,         // read address
                          0x7FFFFFFF,            // ~forever
                          true);
}

void core1_main() {
    while (1) {
        st7789_wait_for_transfer_complete(&lcd);

        const int bin_width = 240 / NUM_BINS;
        for (int i = 1; i < NUM_BINS; ++i) {
            uint32_t val = 0;
            for (int j = 0; j < BIN_REPEATS; ++j) {
                val += bins_out[i + j * NUM_BINS];
            }

            //printf("%d ", val);
            //val >>= 1;

            if (val > 240) val = 240;
            if (val < 240) {
                st7789_start_pixels_at(&lcd, i * bin_width, 0, (i+1) * bin_width - 1, 239-val);
                st7789_repeat_pixel(&lcd, 0, bin_width * (240-val));
            }
            if (val > 0) {
                st7789_start_pixels_at(&lcd, i * bin_width, 240-val, (i+1) * bin_width - 1, 239);
                st7789_repeat_pixel(&lcd, 0x1F, bin_width * val);
            } 
        }
        //printf("\n");
        st7789_trigger_transfer(&lcd);
    }
}

int main(void) {
    set_sys_clock_khz(144 * 1000, true);

    stdio_init_all();

    gpio_init(PIN_RESETN);
    gpio_put(PIN_RESETN, 0);
    gpio_set_dir(PIN_RESETN, GPIO_OUT);
    gpio_set_pulls(PIN_RESETN, false, false);

    adc_init();
    adc_gpio_init(PIN_MIC);
    adc_select_input(3);

#if 0
    gpio_init(PIN_SAMPLE_CLK);
    gpio_init(PIN_SAMPLE_IN);
    gpio_init(PIN_SAMPLE_OUT);
    gpio_init(PIN_SAMPLE_SYNC);
    gpio_put(PIN_SAMPLE_CLK, 0);
    gpio_put(PIN_SAMPLE_IN, 0);
    gpio_set_dir(PIN_RESETN, GPIO_OUT);
    gpio_set_dir(PIN_SAMPLE_CLK, GPIO_OUT);
    gpio_set_dir(PIN_SAMPLE_IN, GPIO_OUT);
    gpio_set_dir(PIN_SAMPLE_OUT, GPIO_IN);
    gpio_set_dir(PIN_SAMPLE_SYNC, GPIO_IN);
    gpio_set_pulls(PIN_SAMPLE_IN, false, false);
    gpio_set_pulls(PIN_SAMPLE_CLK, false, false);
    gpio_set_pulls(PIN_SAMPLE_OUT, false, false);
    gpio_set_pulls(PIN_SAMPLE_SYNC, false, false);
#endif

    // Configure the piping as defined in <tusb_config.h>
    ice_usb_init();

    tud_task();

    // Let the FPGA start
    ice_fpga_init(36);
    ice_fpga_start();

    // Prevent the LEDs from glowing slightly
    ice_led_init();

    setup_fft_pio();
    logic_analyser_init(pio0, 2, 4, 500, 100);
    st7789_init(&lcd, pio1, pio_claim_unused_sm(pio1, true), st7789_data_buf, st7789_ctrl_buf);
    st7789_start_pixels_at(&lcd, 0, 0, 239, 239);
    st7789_repeat_pixel(&lcd, 0, 240*240);
    st7789_trigger_transfer(&lcd);
    sleep_ms(2);

    multicore_launch_core1(&core1_main);

    gpio_put(PIN_RESETN, 1);
    sleep_us(100);
    gpio_put(PIN_RESETN, 0);
    sleep_us(100);
    gpio_put(PIN_RESETN, 1);
    sleep_us(100);

    //logic_analyser_arm(5, true);
    start_adc();

    absolute_time_t next_time = delayed_by_ms(get_absolute_time(), 200);

    //int period = 32;
    //int count = 0;
    while (true) {
        tud_task();

#if 0
        send_sample(period);

        if (++count == 2000) {
            //logic_analyser_print_capture_buf();
            //logic_analyser_arm(5, true);

            printf("\n%d", adc_read());

            if (--period == 4) period = 64;
            printf("\nPeriod %d\n", period);
            //printf("%d\n", dma_hw->ch[fft_rx_channel].transfer_count);
            count = 0;
        }
#endif

#if 0
        if (get_absolute_time() >= next_time) {
            next_time = delayed_by_ms(get_absolute_time(), 200);
            uint32_t max_val = 0;
            for (int i = 1; i < NUM_BINS; ++i) {
                uint32_t val = 0;
                for (int j = 0; j < BIN_REPEATS; ++j) {
                    val += bins_out[i + j * NUM_BINS];
                }
                printf("%d ", val);
                if (val > max_val) {
                    max_val = val;
                    max_bin = i;
                }
            }
            printf("\nMax bin: %d  value: %d\n", max_bin, max_val);
        }
#endif
    }
    return 0;
}
