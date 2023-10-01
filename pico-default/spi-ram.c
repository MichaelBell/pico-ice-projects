#include "hardware/spi.h"
#include "hardware/gpio.h"
#include <stdio.h>

#define PV_SCK 6  // ICE 20_G3
#define PV_MISO 4  // ICE 26
#define PV_MOSI 7   // ICE 18
#define PV_CSN 5   // ICE 23

#define CMD_READ                0x03
#define CMD_WRITE               0x02

void spi_write(uint32_t addr, const uint8_t* data, uint32_t len)
{
    uint8_t command[] = { CMD_WRITE, addr >> 16, addr >> 8, addr };
    gpio_put(PV_CSN, 0);

    spi_write_blocking(spi0, command, 4);
    spi_write_blocking(spi0, data, len);
    gpio_put(PV_CSN, 1);
}

void spi_read(uint32_t addr, uint8_t* data, uint32_t len)
{
    uint8_t command[] = { CMD_READ, addr >> 16, addr >> 8, addr };
    gpio_put(PV_CSN, 0);

    spi_write_blocking(spi0, command, 4);
    spi_read_blocking(spi0, 0, data, len);
    gpio_put(PV_CSN, 1);
}

void test_spi()
{
    gpio_init(PV_CSN);
    gpio_put(PV_CSN, 1);
    gpio_set_dir(PV_CSN, GPIO_OUT);

    gpio_set_function(PV_SCK, GPIO_FUNC_SPI);
    gpio_set_function(PV_MISO, GPIO_FUNC_SPI);
    gpio_set_function(PV_MOSI, GPIO_FUNC_SPI);

    spi_init(spi0, 1 * 1000000);

    uint32_t addr = 0;
    uint8_t test_data[4] = {1, 0xFF, 0xAA, 4};
    //spi_write(0, test_data, 4);

    uint8_t buf[256];
    spi_read(0, buf, 256);

    for (int i = 0; i < 256; i += 4) {
        printf("%02x %02x %02x %02x\n", buf[i+0], buf[i+1], buf[i+2], buf[i+3]);
    }
    
}