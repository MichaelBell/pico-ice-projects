// Copyright 2023 (c) Michael Bell
// The BSD 3 clause license applies
#pragma once

#include <stdint.h>

// Configuration: GPIOs for the SPI interface
#define SIM_SRAM_SPI_MOSI 3
#define SIM_SRAM_SPI_SCK  4  // Must be MOSI + 1
#define SIM_SRAM_SPI_CS   5  // Must be MOSI + 2
#define SIM_SRAM_SPI_MISO 6

// The PIO SMs and DMA channels are hardcoded as using dynamic
// allocation and then reading the values from memory is slightly slower.

// Configuration: PIO and SMs to use
// A different PIO must be used for each of read and write 
// as the total program size is too large to fit in one PIO
#define SIM_SRAM_pio_read_sm   1
#define SIM_SRAM_pio_read      pio1
#define SIM_SRAM_pio_write_sm  1
#define SIM_SRAM_pio_write     pio0

// Configuration: DMA channels
#define SIM_SRAM_rx_channel    9
#define SIM_SRAM_tx_channel    10
#define SIM_SRAM_tx_channel2   11

// 16 or 24 address bits
#define SIM_SRAM_ADDR_BITS 24

// Setup the simulated SRAM and launch core1 to service the commands.
//
// It is best to call this before other initialization, so that
// the hardcoded DMA channels and SMs are claimed before other resources
// are claimed.
uint8_t* setup_simulated_sram();

extern uint8_t emu_ram[1 << 17];