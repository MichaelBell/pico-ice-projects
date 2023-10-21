// ----------------------------------------------------------------------------
// Second stage boot code / TT05 test program
// Copyright (c) 2019-2021 Raspberry Pi (Trading) Ltd.
// Copyright (c) 2023 Michael Bell
// SPDX-License-Identifier: BSD-3-Clause
//
// Building:    * This code must be position-independent, and use stack only
//              * The code will be padded to a size of 256 bytes, including a
//                4-byte checksum. Therefore code size cannot exceed 252 bytes.
// ----------------------------------------------------------------------------

//#include "pico/asm_helper.S"
#include "hardware/regs/addressmap.h"
#include "hardware/regs/ssi.h"
#include "hardware/regs/pads_qspi.h"
#include "hardware/regs/resets.h"
#include "hardware/regs/rosc.h"

.syntax unified
.cpu cortex-m0plus
.thumb

.macro regular_func x
.global \x
.type \x,%function
.thumb_func
\x:
.endm

// ----------------------------------------------------------------------------
// Config section
// ----------------------------------------------------------------------------
// It should be possible to support most flash devices by modifying this section

// The serial flash interface will run at clk_sys/PICO_FLASH_SPI_CLKDIV.
// This must be a positive, even integer.
// The bootrom is very conservative with SPI frequency, but here we should be
// as aggressive as possible.
#ifndef PICO_FLASH_SPI_CLKDIV
#define PICO_FLASH_SPI_CLKDIV 6
#endif

#define CMD_READ 0x6B

// Value is number of address bits divided by 4
#define ADDR_L 6

#define CTRLR0_XIP \
    (SSI_CTRLR0_SPI_FRF_VALUE_QUAD << SSI_CTRLR0_SPI_FRF_LSB) |  /* QSPI frames */ \
    (31 << SSI_CTRLR0_DFS_32_LSB)  |                            /* 32 data bits per data frame */ \
    (SSI_CTRLR0_TMOD_VALUE_EEPROM_READ  << SSI_CTRLR0_TMOD_LSB) /* Send instr + addr, receive data */

#define SPI_CTRLR0_XIP \
    (CMD_READ << SSI_SPI_CTRLR0_XIP_CMD_LSB) |        /* Value of instruction prefix */ \
    (ADDR_L << SSI_SPI_CTRLR0_ADDR_L_LSB) |           /* Total number of address + mode bits */ \
    (2 << SSI_SPI_CTRLR0_INST_L_LSB) |                /* 8 bit command prefix (field value is bits divided by 4) */ \
    (2 << SSI_SPI_CTRLR0_WAIT_CYCLES_LSB) |    /* Hi-Z dummy clocks following address + mode */ \
    (SSI_SPI_CTRLR0_TRANS_TYPE_VALUE_1C1A << SSI_SPI_CTRLR0_TRANS_TYPE_LSB) /* command and address both in serial format */

// ----------------------------------------------------------------------------
// Start of 2nd Stage Boot Code
// ----------------------------------------------------------------------------

.section .text

regular_func _stage2_boot
    // Take PWM, UART1 and IOBANK0 out of reset
    ldr  r3, =(RESETS_BASE | REG_ALIAS_CLR_BITS)  // 0x4000c000
    ldr  r2, =(RESETS_RESET_UART1_BITS | RESETS_RESET_PWM_BITS | RESETS_RESET_IO_BANK0_BITS)  // 0x804020
    str  r2, [r3, #0]

    // Set GPIO 23-25 to SIO control
    movs r1, #5
    ldr  r7, =0x40014074   // A handily picked value in the middle of the IOBANK0 range
    str  r1, [r7, #0x48]   // GPIO23
    str  r1, [r7, #0x50]   // GPIO24
    str  r1, [r7, #0x58]   // GPIO25

    // Pull up GPIO 23 and 24
    ldr  r5, =PADS_BANK0_BASE  // 0x4001c000
    movs r0, #0x4a         // Input, pull up
    str  r0, [r5, #0x60]   // GPIO 23
    str  r0, [r5, #0x64]   // GPIO 24

    lsls r6, r7, #26      // 0xD000_0000: SIO_BASE
	lsls r2, r1, #25      // Bits 25 and 27 set.  27 doesn't matter as SIO control not enabled.
	str  r2, [r6, #0x20]  // Enable output on GPIO 25

    movs r1, #0           // Counter for blink loops

_blink:
    ldr  r0, [r7, #0x4c]  // GPIO 24 status
    lsls r0, r0, #14
    bpl  _exit_blink      // Exit blink on GPIO 24 low

	str  r2, [r6, #0x1c]  // XOR GPIO 25

	lsrs r4, r6, #13      // Delay loop
1:
	subs r4, r4,#1
	bne 1b
    adds r1, #1
	b   _blink

_exit_blink:
#define CTRL0_SPI_TXRX \
    (31 << SSI_CTRLR0_DFS_32_LSB) | /* 32 bits per data frame */ \
    (SSI_CTRLR0_TMOD_VALUE_TX_AND_RX << SSI_CTRLR0_TMOD_LSB)

    //ldr r3, =XIP_SSI_BASE             // Use as base address where possible
    movs r3, #0x18
    lsls r3, r3, #24

    // Disable SSI otherwise config doesn't work
    movs r2, #0
    str r2, [r3, #SSI_SSIENR_OFFSET]

    //ldr r2, =(CTRL0_SPI_TXRX)           // Set to transmit mode
    movs r2, #0x1f
    lsls r2, #16
    str r2, [r3, #SSI_CTRLR0_OFFSET]

    movs r2, #1
    str r2, [r3, #SSI_SSIENR_OFFSET]

    // Store number of blinks to address 0x100
    ldr r5, =0x02000100               // Write command to address 0x100
    str r5, [r3, #SSI_DR0_OFFSET]
    str r1, [r3, #SSI_DR0_OFFSET]     // Store number of blinks

    // Read GPIO 23
    ldr  r0, [r7, #0x44]  // GPIO 23 status
    lsls r0, r0, #14
    bpl  _change_clock   // Branch on low

    // Write 0xab0 to address 0x104
    movs r1, #0xab
    lsls r1, r1, #4
    str r1, [r3, #SSI_DR0_OFFSET]

    b _finish_boot

_change_clock:

    // Wait for SSI idle    
    ldr r2, [r3, #SSI_SR_OFFSET]
    cmp r2, #0xe
    bne _change_clock

    // Clear RX FIFO
    ldr r2, [r3, #SSI_DR0_OFFSET]
    ldr r1, [r3, #SSI_DR0_OFFSET]

    // Read value from 0x104
    ldr r2, =0x03000104               // Write command to address 0x100
    str r2, [r3, #SSI_DR0_OFFSET]
    str r1, [r3, #SSI_DR0_OFFSET]

    // Wait for SSI idle    
1:
    ldr r2, [r3, #SSI_SR_OFFSET]
    cmp r2, #0xe
    bne 1b

    // Read result
    ldr r2, [r3, #SSI_DR0_OFFSET]
    ldr r1, [r3, #SSI_DR0_OFFSET]

    // Change clock divider
    ldr r4, =ROSC_BASE              // 0x40060000
    str r1, [r4, #ROSC_DIV_OFFSET]

    // Decrement divider and write back
    subs r1, r1, #1
    adds r2, r5, #4               // Write command to address 0x104
    str r2, [r3, #SSI_DR0_OFFSET]
    str r1, [r3, #SSI_DR0_OFFSET]

_finish_boot:

    ldr r2, [r3, #SSI_SR_OFFSET]
    cmp r2, #0xe
    bne _finish_boot

    // Disable SSI to allow further config
    movs r2, #0
    str r2, [r3, #SSI_SSIENR_OFFSET]

    ldr r1, =(CTRLR0_XIP)
    str r1, [r3, #SSI_CTRLR0_OFFSET]

    ldr r1, =(SPI_CTRLR0_XIP)
    adds r3, #SSI_SPI_CTRLR0_OFFSET
    str r1, [r3]
    subs r3, #SSI_SPI_CTRLR0_OFFSET

    // NDF=0 (single 32b read)
    str r2, [r3, #SSI_CTRLR1_OFFSET]

    // Re-enable SSI
    movs r1, #1
    str r1, [r3, #SSI_SSIENR_OFFSET]

// We are now in XIP mode. Any bus accesses to the XIP address window will be
// translated by the SSI into read commands to the external flash (if cache is missed),
// and the data will be returned to the bus.

    ldr r1, =0x10000201
    bx r1

.global literals
literals:
.ltorg

.end
