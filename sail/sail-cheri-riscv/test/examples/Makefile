# The CLANG env variable should be set to the path to the custom clang compiler
TESTS = fac.elf timer.elf

FLAGS = -nostdlib -Ttext 0x80000000 --target=riscv64-unknown-freebsd -march=rv64gxcheri -mno-relax

all: $(TESTS)

%.elf: %.S
	$(CLANG) $< $(FLAGS) -o $@

clean:
	rm *.elf
