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

	ldr  r3, _reset_clear  ;@ Resets.reset (Atomic bitmask clear)
	ldr  r2, _gpio25_ctrl  ;@ PWM | IO_BANK0 + some other stuff
	str  r2, [r3, #0]

	movs r1, #4           ;@Function 4 (PWM)
	str  r1, [r2, #0x2c]  ;@IO_BANK0.GPIO25_CTRL

	ldr r3, =0x40050050   
	                      ;@PWM channel 4 control
	@str r1, [r3, #0x4]   ;@Setting the integer part of the divider to 0 appears to mean 256

	str r3, [r3, #0xc]   ;@ This is on for ~quarter of the period

	mov r0, #1       ;@ Enable
	@str r0, [r3, #0x0]
	stm r3!, {r0, r1}  ;@ Unfortunately we can't use r3 in source unless it is the first argument

_loop:
	b _loop
	@nop

@.align 4 Don't align as this is actually aligning more strictly

_reset_clear: .word 0x4000f000
_gpio25_ctrl: .word 0x400140a0
