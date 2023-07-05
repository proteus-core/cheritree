all: main.elf main.bin main.ihex

TOOLCHAIN_PREFIX = riscv32-unknown-elf
GCC = $(TOOLCHAIN_PREFIX)-gcc
AS = $(TOOLCHAIN_PREFIX)-as
OBJDUMP = $(TOOLCHAIN_PREFIX)-objdump
OBJCOPY = $(TOOLCHAIN_PREFIX)-objcopy
AR = $(TOOLCHAIN_PREFIX)-ar

GCC_PATH = $(shell which $(GCC))
TOOLCHAIN_ROOT = $(dir $(GCC_PATH))/..
TOOLCHAIN_INC = $(realpath $(TOOLCHAIN_ROOT)/riscv32-unknown-elf/include)

CC = clang

DEPSFLAGS = -MMD -MP
ASFLAGS = -target riscv32 -march=rv32ixcheri $(DEPSFLAGS) $(EXPERIMENTS_FLAGS)
CFLAGS = -target riscv32 -march=rv32ixcheri $(DEPSFLAGS) -Wall -O2 -I$(TOOLCHAIN_INC)

ENCLAVE_ID = ./enclave_id.py

OBJECTS = boot.o trusted_traps.o trusted_init.o trap.o syscalls.o interrupts.o exceptions.o performance.o capattest.o main.o sensor_enclave.o user_enclave.o unique_alloc.o microbench.o unprotected.o

DEPS = $(OBJECTS:.o=.d)
-include $(DEPS)

main-no-id.elf: $(OBJECTS)
	$(GCC) -T link.ld -o $@ $^

main.elf: main-no-id.elf
	$(ENCLAVE_ID) --enclave sensor $< -o $@

%.ihex: %.elf
	$(OBJCOPY) -O ihex $^ $@

%.bin: %.elf
	$(OBJCOPY) -O binary $^ $@

dump: main.elf
	llvm-objdump --arch riscv32 --mattr +xcheri -d $<

clean:
	rm -f *.o *.elf *.bin *.ihex *.d
