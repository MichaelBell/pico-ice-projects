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

	mov r0, #1       ;@ Enable
	str r0, [r3, #0x0]

	lsl r1, r0, #13
_fade:
    add r0, r0, r1
	cmp r0, #1
	bne 1f
	neg r1, r1
	add r0, r0, r1
1:
	str r0, [r3, #0x0c]
	b _fade
	@nop

@.align 4 Don't align as this is actually aligning more strictly

_reset_clear: .word 0x4000f000
_gpio25_ctrl: .word 0x400140a0
