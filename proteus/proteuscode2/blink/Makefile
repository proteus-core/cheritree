RISCV_PREFIX = riscv32-unknown-elf
CC = $(RISCV_PREFIX)-gcc
LD = $(RISCV_PREFIX)-gcc
OBJCOPY = $(RISCV_PREFIX)-objcopy
ARCHFLAGS = -march=rv32im -mabi=ilp32
CFLAGS = $(ARCHFLAGS) -Ttext=0x80000000 -ffreestanding -nostdlib

all: blink.ihex blink.bin

blink.elf: blink.S
	$(CC) $(CFLAGS) -o $@ $<

%.ihex: %.elf
	$(OBJCOPY) -O ihex $< $@

%.bin: %.elf
	$(OBJCOPY) -O binary $< $@

clean:
	rm blink.elf blink.bin blink.ihex
