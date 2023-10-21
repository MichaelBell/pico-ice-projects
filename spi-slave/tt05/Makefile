NAME    = tt05
CPU     = cortex-m0plus
ARMGNU  = arm-none-eabi
AFLAGS  = --warn --fatal-warnings -mcpu=$(CPU) -g
LDFLAGS = -nostdlib
PICOSDK = ~/pico/pico-sdk

all: $(NAME).txt

$(NAME).o: $(NAME).s
	$(ARMGNU)-as $(AFLAGS) $(NAME).s -o $(NAME).o

$(NAME).bin: memmap.ld $(NAME).s $(NAME).o
	$(ARMGNU)-ld $(LDFLAGS) --entry 0x10000201 -T memmap.ld $(NAME).o -o $(NAME).elf
	$(ARMGNU)-objdump -D $(NAME).elf > $(NAME).list
	$(ARMGNU)-objcopy -O binary $(NAME).elf $(NAME).bin

$(NAME).txt: $(NAME).bin
	od -Ax -tx4 -w4 $(NAME).bin|awk 'BEGIN{OFS=""} {print NR-1, ": rp2040_rom2 = 32\047h", $$2, ";"}' > $(NAME).txt

clean: 
	rm -f *.bin *.o *.elf *.list *.uf2 $(NAME).txt
