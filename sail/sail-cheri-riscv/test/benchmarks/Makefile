# The CLANG env variable should be set to the path to the custom clang compiler
TESTS = full.elf no-caller-attestation.elf no-callee-attestation.elf no-hash-full.elf no-init.elf init.elf no-callee-attestation-no-hash.elf no-caller-attestation-no-hash.elf deinit.elf only-fac.elf

FLAGS = -nostdlib -Ttext 0x80000000 --target=riscv64-unknown-freebsd -march=rv64gxcheri -mno-relax

all: $(TESTS)

%.elf: %.S
	$(CLANG) $< $(FLAGS) -o $@

clean:
	rm *.elf
