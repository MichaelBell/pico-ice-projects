NAME    = pwm_blink
CPU     = cortex-m0plus
ARMGNU  = arm-none-eabi
AFLAGS  = --warn --fatal-warnings -mcpu=$(CPU) -g
LDFLAGS = -nostdlib
PICOSDK = ~/pico/pico-sdk

all: $(NAME).hex

$(NAME).o: $(NAME).s
	$(ARMGNU)-as $(AFLAGS) $(NAME).s -o $(NAME).o

$(NAME).bin: boot_stage2.ld $(NAME).s $(NAME).o
	$(ARMGNU)-ld $(LDFLAGS) --entry 0x20041f01 -T boot_stage2.ld $(NAME).o -o $(NAME).elf
	$(ARMGNU)-objdump -D $(NAME).elf > $(NAME).list
	$(ARMGNU)-objcopy -O binary $(NAME).elf $(NAME).bin

$(NAME).bit: $(NAME).bin
	$(PICOSDK)/src/rp2_common/boot_stage2/pad_checksum -p 256 -s 0xFFFFFFFF $(NAME).bin $(NAME).bit-s
	$(ARMGNU)-as $(AFLAGS) $(NAME).bit-s -o $(NAME).bit-o
	$(ARMGNU)-ld $(LDFLAGS) --entry 0x20041f01 -T boot_stage2.ld $(NAME).bit-o -o $(NAME).bit-elf
	$(ARMGNU)-objcopy -O binary $(NAME).bit-elf $(NAME).bit

$(NAME).hex: $(NAME).bit
	od -t x2 -w2 -v $(NAME).bit | cut -d' ' -f2 -s > $(NAME).hex

clean: 
	rm -f *.bin *.o *.elf *.list *.uf2 *.bit* *.hex
