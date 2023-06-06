
 #============================================================================
 #Name        : makefile
 #Author      : CAP-TEE 2023
 #============================================================================
 

#edit this path
#path to clang
CC=/home/projects/baremetalsources/llvm-project-releases/bin/clang

#-DBENCHMARK1 #-DBENCHMARK2
CFLAGS= --target=aarch64-none-elf -march=morello+c64 -mabi=purecap -DNO_SEMIHOSTING

#relative path to libtomcrypt
DIRLIB=../../../libs

#Output directory
DIROUT=./outputs

-include sourcebuild.mk

# Build for enclave project
all: enclaveMorello.elf

# Generate executable via linker
# This generates an elf binary file for the project
enclaveMorello.elf: $(OBJS) $(DIROUT)/EL1Nentry.o 
	@ mkdir -p $(DIROUT) #make directory if it doesn't exist
	@echo 'Build target: $@'
	@echo 'Using: LLVM C Linker 11.0.0'
	$(CC) $(CFLAGS) -nostartfiles -Xlinker -T./../src/linker-script.ld -v -o "enclaveMorello.elf" $(OBJS) $(DIROUT)/EL1Nentry.o $(LIBS)
	@echo 'Done target: $@'
	@echo ' '
	@echo 'Post-build: Inserting hash into elf'
	"../scripts/hash_make.sh"
	@echo 'Made $@ with the hash ID'
	@echo ' '

#build for tests
test: enclaveMorello_test.elf

# Generate executable via linker
# This generates an elf binary file for running some tests
# Select the test number to run in test_EL1Nentry.c and rebuild
enclaveMorello_test.elf: $(OBJS) $(DIROUT)/test_EL1Nentry.o
	@ mkdir -p $(DIROUT) #make directory if it doesn't exist
	@echo 'Build TEST target: $@'
	@echo 'Using: LLVM C Linker 11.0.0'
	$(CC) $(CFLAGS) -nostartfiles -Xlinker -T./../src/linker-script.ld -v -o "enclaveMorello_test.elf" $(OBJS) $(DIROUT)/test_EL1Nentry.o $(LIBS)
	@echo 'Done TEST target: $@'
	@echo ' '

# Clean object files and executables
clean:
	rm -f $(OBJS) $(DIROUT)/EL1Nentry.o $(DIROUT)/EL1Nentry.d $(DIROUT)/test_EL1Nentry.o $(DIROUT)/test_EL1Nentry.d $(C_DEPS) "enclaveMorello.elf" "enclaveMorello_noid.elf" "enclaveMorello_test.elf"
	-@echo ' '

.PHONY: all clean test
