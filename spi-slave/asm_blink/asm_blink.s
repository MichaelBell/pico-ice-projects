;@ Copyright (c) 2023 CarlosFTM
;@ Modifications (c) 2023 Michael Bell
;@ This code is loosely based on https://github.com/carlosftm/RPi-Pico-Baremetal/
;@ This code is licensed under MIT license (see LICENSE.txt for details)

	.cpu cortex-m0plus
	.thumb

/* reset handler */
	.section .entry, "ax"
	.align 2
	.thumb_func
	.global _reset
_reset:
	ldr  r3, _iobank0  ;@ Resets.reset (Atomic bitmask clear)
	movs r2, #32          ;@ IO_BANK0
	str  r2, [r3, #0]

	ldr  r3, _gpio25_ctrl  ;@IO_BANK0.GPIO25_CTRL - 0x18
	movs r1, #5           ;@Function 5 (SIO)
	str  r1, [r3, #0x18]

	lsl  r3, r3, #26      ;@SIO_BASE
	lsl  r2, r2, #20      ;@GPIO25
	str  r2, [r3, #0x20]  ; @.GPIO_OE

_blink:
	str  r2, [r3, #0x1c]  ; @.GPIO_XOR

	lsr r4, r3, #14
_loop:
	sub r4,r4,#1
	bne _loop
	b   _blink

/* .align 4 Don't align as this is actually aligning more strictly */

_iobank0:     .word 0x4000f000
_gpio25_ctrl: .word 0x400140b4
