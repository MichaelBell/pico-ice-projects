// Copyright (c) 2023 Michael Bell

	.syntax unified
	.cpu cortex-m0plus
	.thumb

/* reset handler */
	.section .entry, "ax"
	.align 2
	.thumb_func
	.global _reset
_reset:
	ldr r2, =0x40038000   // UART1 SET BASE
	movs r1, #38
	str r1, [r2, #0x24]   // Set divisor somewhere near 9600 baud
	movs r1, #0x70
	str r1, [r2, #0x2c]   // UART LCR_H. Enable FIFOs, 8 bits, 1 stop, no parity
	ldr r1, =0x101        // While ldr =0x101 is longer the mov add sequence is actually worse for synthesis
	//movs r1, #0x81
	//adds r1, r1, #0x80
	str r1, [r2, #0x30]   // UART CR: Enable, transmit only

	movs r1, #2           // Function 2 (UART)
	str r1, [r7, #0x30]   // GPIO 20

	// Read number of blinks
	ldr r5, =0x10000100
	ldr r1, [r5]

	// Send 0x55 to allow the baud rate to be figured out
	// Surprisingly, it is not a saving to split the UART send out into a function
	// Though if we sent more than 2 bytes it would be.
	movs r6, #0x55
	str r6, [r2, #0]

	// Send number of blinks
	str r1, [r2]
	//lsrs r1, r1, #8    // Only send low byte as we are struggling to fit in one Tiny Tapeout tile
	//str r1, [r2]

	// Random source
	ldr r5, =0x10000400

	// Set up PWM
	movs r1, #4           // Function 4 (PWM)
	str  r1, [r7, #0x58]  // GPIO 25

	ldr r3, =0x40050050   // PWM channel 4 control

_pwm_loop:
	movs r0, #1           // Enable PWM
	str r0, [r3, #0x0]

	lsls r1, r0, #13
_fade:
    add r0, r0, r1
	cmp r0, #1
	bne 1f
	negs r1, r1
	add r0, r0, r1
1:
	str r0, [r3, #0x0c]  // PWM duty cycle

	ldr r4, [r7, #0x4c]  // GPIO 24 status
	lsls r4, r4, #14
	bmi _fade

	// Read from ROSC in TT
	ldr r1, [r5]

	// Invalidate cache so we get a different value next time
	str r1, [r5]

	// Write to UART
	str r6, [r2, #0]
	str r1, [r2]
	lsrs r1, r1, #8
	str r1, [r2]

	// Write bottom bit of random data to LED
	lsls r1, r1, #31
	asrs r1, r1, #16
	str r1, [r3, #0x0c]

	// Wait for button release
2:
	ldr r4, [r7, #0x4c]  // GPIO 24 status
	lsls r4, r4, #14
	bpl 2b

	b _pwm_loop

.global literals
literals:
.ltorg

.end
