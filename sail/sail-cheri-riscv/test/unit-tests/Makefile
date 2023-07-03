# The CLANG env variable should be set to the path to the custom clang compiler
TESTS = test-EInitCode.elf test-EInitData.elf test-EDeinit.elf test-IsUnique.elf test-sweep.elf

TESTS_PROT = prot-EInitCode.elf prot-EInitData.elf prot-EStoreId.elf

ENCLAVE_WRITE_TESTS = test-EStoreId.elf test-everything.elf
ENCLAVE_WRITE_TESTS_OUT = $(patsubst %, %-Out.elf, $(basename $(ENCLAVE_WRITE_TESTS)))

FLAGS = -nostdlib -Ttext 0x80000000 --target=riscv64-unknown-freebsd -march=rv64gxcheri -mno-relax #-mabi=l64pc128d

ENCLAVE_ID = ./enclave_id.py


all: $(TESTS) $(TESTS_PROT) $(ENCLAVE_WRITE_TESTS_OUT)

unit: $(TESTS)

prot: $(TESTS_PROT)

write: $(ENCLAVE_WRITE_TESTS_OUT)

%.elf: %.S setup_macros.h riscv_test.h
	$(CLANG) $< $(FLAGS) -o $@

# Trick: the elf dependency will be compiled first
$(ENCLAVE_WRITE_TESTS_OUT): %-Out.elf : %.elf
	$(ENCLAVE_ID) $< -o $@
	@rm $<

clean:
	rm *.elf
	rm *.cout
