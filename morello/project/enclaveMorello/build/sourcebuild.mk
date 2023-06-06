 #============================================================================
 #Name        : sourceBuild - source build inputs
 #Author      : CAP-TEE 2023
 #============================================================================

# include header directories
IDIR += \
-I"$(DIRLIB)/libtomcrypt/src/headers" \
-I"../src/common" \
-I"../src/EL1Code" \
-I"../src/EL2Code" \
-I"../src/EL3Code" \
-I"../src/EL2Code/instructions" \
-I"../src/EL1Code/enclavecode" \
-I"../src"

# source files directories
SRCDIR1 := $(DIRLIB)/libtomcrypt/src/hashes
SRCDIR2 := $(DIRLIB)/libtomcrypt/src/hashes/sha2
SRCDIR3 := $(DIRLIB)/libtomcrypt/src/misc
SRCDIR4 := $(DIRLIB)/libtomcrypt/src/misc/crypt
SRCDIR5 := ../src/EL1Code
SRCDIR6 := ../src/EL1Code/enclavecode
SRCDIR7 := ../src/EL2Code
SRCDIR8 := ../src/EL2Code/bootup
SRCDIR9 := ../src/EL2Code/instructions
SRCDIR10 := ../src/common
# for tests
SRCDIR11 := ../src/EL1Code/tests

# input c files  
C_SRCS += \
$(DIRLIB)/libtomcrypt/src/hashes/sha2/sha256.c \
$(DIRLIB)/libtomcrypt/src/misc/compare_testvector.c \
$(DIRLIB)/libtomcrypt/src/misc/crypt/crypt.c \
$(DIRLIB)/libtomcrypt/src/misc/crypt/crypt_argchk.c \
$(DIRLIB)/libtomcrypt/src/misc/crypt/crypt_cipher_descriptor.c \
$(DIRLIB)/libtomcrypt/src/misc/crypt/crypt_cipher_is_valid.c \
$(DIRLIB)/libtomcrypt/src/misc/crypt/crypt_constants.c \
$(DIRLIB)/libtomcrypt/src/misc/crypt/crypt_find_cipher.c \
$(DIRLIB)/libtomcrypt/src/misc/crypt/crypt_find_cipher_any.c \
$(DIRLIB)/libtomcrypt/src/misc/crypt/crypt_find_cipher_id.c \
$(DIRLIB)/libtomcrypt/src/misc/crypt/crypt_find_hash.c \
$(DIRLIB)/libtomcrypt/src/misc/crypt/crypt_find_hash_any.c \
$(DIRLIB)/libtomcrypt/src/misc/crypt/crypt_find_hash_id.c \
$(DIRLIB)/libtomcrypt/src/misc/crypt/crypt_find_hash_oid.c \
$(DIRLIB)/libtomcrypt/src/misc/crypt/crypt_find_prng.c \
$(DIRLIB)/libtomcrypt/src/misc/crypt/crypt_fsa.c \
$(DIRLIB)/libtomcrypt/src/misc/crypt/crypt_hash_descriptor.c \
$(DIRLIB)/libtomcrypt/src/misc/crypt/crypt_hash_is_valid.c \
$(DIRLIB)/libtomcrypt/src/misc/crypt/crypt_inits.c \
$(DIRLIB)/libtomcrypt/src/misc/crypt/crypt_ltc_mp_descriptor.c \
$(DIRLIB)/libtomcrypt/src/misc/crypt/crypt_prng_descriptor.c \
$(DIRLIB)/libtomcrypt/src/misc/crypt/crypt_prng_is_valid.c \
$(DIRLIB)/libtomcrypt/src/misc/crypt/crypt_prng_rng_descriptor.c \
$(DIRLIB)/libtomcrypt/src/misc/crypt/crypt_register_all_ciphers.c \
$(DIRLIB)/libtomcrypt/src/misc/crypt/crypt_register_all_hashes.c \
$(DIRLIB)/libtomcrypt/src/misc/crypt/crypt_register_all_prngs.c \
$(DIRLIB)/libtomcrypt/src/misc/crypt/crypt_register_cipher.c \
$(DIRLIB)/libtomcrypt/src/misc/crypt/crypt_register_hash.c \
$(DIRLIB)/libtomcrypt/src/misc/crypt/crypt_register_prng.c \
$(DIRLIB)/libtomcrypt/src/misc/crypt/crypt_sizes.c \
$(DIRLIB)/libtomcrypt/src/misc/crypt/crypt_unregister_cipher.c \
$(DIRLIB)/libtomcrypt/src/misc/crypt/crypt_unregister_hash.c \
$(DIRLIB)/libtomcrypt/src/misc/crypt/crypt_unregister_prng.c \
../src/EL1Code/EL1Debug.c \
../src/EL1Code/performance_EL1.c \
../src/EL1Code/printf.c \
../src/EL1Code/uartN_redirect.c \
../src/EL1Code/enclavecode/capattest.c \
../src/EL1Code/enclavecode/unique_alloc.c \
../src/EL2Code/EL2Entry.c \
../src/EL2Code/exceptionHandlerFuncsEL1N.c \
../src/EL2Code/exceptionHandlerFuncsEL2N.c \
../src/EL2Code/uartEL2N.c \
../src/EL2Code/bootup/initfunc.c \
../src/EL2Code/instructions/EINIT_CODE.c \
../src/EL2Code/instructions/EINIT_DATA.c \
../src/EL2Code/instructions/ESTORE_ID.c \
../src/EL2Code/instructions/enclaveIDManager.c \
../src/EL2Code/instructions/enclaveid.c \
../src/EL2Code/instructions/hash.c \
../src/EL2Code/instructions/identityStore.c \
../src/EL2Code/instructions/regsweep.c \
../src/EL2Code/instructions/sealingCapability.c \
../src/common/capfuncs.c \
../src/common/performance.c \
../src/EL1Code/tests/test_EINIT_CODE.c \
../src/EL1Code/tests/test_EINIT_DATA.c \
../src/EL1Code/tests/test_ESTORE_ID.c \
../src/EL1Code/EL1Nentry.c \
../src/EL1Code/test_EL1Nentry.c \

#Input assembly files
S_UPPER_SRCS += \
../src/EL1Code/regForEL1N.S \
../src/EL1Code/enclavecode/sensor_enclave.S \
../src/EL1Code/enclavecode/user_enclave.S \
../src/EL2Code/el2_stg1ForEl1nmmusetup.S \
../src/EL2Code/el2_stg2ForEl1nmmusetup.S \
../src/EL2Code/el2nmmusetup.S \
../src/EL2Code/exceptionHandlerFuncsEL1Nass.S \
../src/EL2Code/regForEL2N.S \
../src/EL2Code/vectorTableEL1N.S \
../src/EL2Code/vectorTableEL2N.S \
../src/EL2Code/bootup/crt0.S \
../src/EL2Code/bootup/rdimon-aem-el3.S \
../src/EL1Code/el1nMemAccess.S 

#outputs
OBJS += \
$(DIROUT)/sha256.o \
$(DIROUT)/compare_testvector.o \
$(DIROUT)/crypt.o \
$(DIROUT)/crypt_argchk.o \
$(DIROUT)/crypt_cipher_descriptor.o \
$(DIROUT)/crypt_cipher_is_valid.o \
$(DIROUT)/crypt_constants.o \
$(DIROUT)/crypt_find_cipher.o \
$(DIROUT)/crypt_find_cipher_any.o \
$(DIROUT)/crypt_find_cipher_id.o \
$(DIROUT)/crypt_find_hash.o \
$(DIROUT)/crypt_find_hash_any.o \
$(DIROUT)/crypt_find_hash_id.o \
$(DIROUT)/crypt_find_hash_oid.o \
$(DIROUT)/crypt_find_prng.o \
$(DIROUT)/crypt_fsa.o \
$(DIROUT)/crypt_hash_descriptor.o \
$(DIROUT)/crypt_hash_is_valid.o \
$(DIROUT)/crypt_inits.o \
$(DIROUT)/crypt_ltc_mp_descriptor.o \
$(DIROUT)/crypt_prng_descriptor.o \
$(DIROUT)/crypt_prng_is_valid.o \
$(DIROUT)/crypt_prng_rng_descriptor.o \
$(DIROUT)/crypt_register_all_ciphers.o \
$(DIROUT)/crypt_register_all_hashes.o \
$(DIROUT)/crypt_register_all_prngs.o \
$(DIROUT)/crypt_register_cipher.o \
$(DIROUT)/crypt_register_hash.o \
$(DIROUT)/crypt_register_prng.o \
$(DIROUT)/crypt_sizes.o \
$(DIROUT)/crypt_unregister_cipher.o \
$(DIROUT)/crypt_unregister_hash.o \
$(DIROUT)/crypt_unregister_prng.o \
$(DIROUT)/EL1Debug.o \
$(DIROUT)/performance_EL1.o \
$(DIROUT)/printf.o \
$(DIROUT)/regForEL1N.o \
$(DIROUT)/uartN_redirect.o \
$(DIROUT)/capattest.o \
$(DIROUT)/sensor_enclave.o \
$(DIROUT)/unique_alloc.o \
$(DIROUT)/user_enclave.o \
$(DIROUT)/EL2Entry.o \
$(DIROUT)/el2_stg1ForEl1nmmusetup.o \
$(DIROUT)/el2_stg2ForEl1nmmusetup.o \
$(DIROUT)/el2nmmusetup.o \
$(DIROUT)/exceptionHandlerFuncsEL1N.o \
$(DIROUT)/exceptionHandlerFuncsEL1Nass.o \
$(DIROUT)/exceptionHandlerFuncsEL2N.o \
$(DIROUT)/regForEL2N.o \
$(DIROUT)/uartEL2N.o \
$(DIROUT)/vectorTableEL1N.o \
$(DIROUT)/vectorTableEL2N.o \
$(DIROUT)/crt0.o \
$(DIROUT)/initfunc.o \
$(DIROUT)/rdimon-aem-el3.o \
$(DIROUT)/EINIT_CODE.o \
$(DIROUT)/EINIT_DATA.o \
$(DIROUT)/ESTORE_ID.o \
$(DIROUT)/enclaveIDManager.o \
$(DIROUT)/enclaveid.o \
$(DIROUT)/hash.o \
$(DIROUT)/identityStore.o \
$(DIROUT)/regsweep.o \
$(DIROUT)/sealingCapability.o \
$(DIROUT)/capfuncs.o \
$(DIROUT)/performance.o \
$(DIROUT)/el1nMemAccess.o \
$(DIROUT)/test_EINIT_CODE.o \
$(DIROUT)/test_EINIT_DATA.o \
$(DIROUT)/test_ESTORE_ID.o 
#$(DIROUT)/EL1Nentry.o 
#$(DIROUT)/test_EL1Nentry.o

C_DEPS += \
$(DIROUT)/sha256.d \
$(DIROUT)/compare_testvector.d \
$(DIROUT)/crypt.d \
$(DIROUT)/crypt_argchk.d \
$(DIROUT)/crypt_cipher_descriptor.d \
$(DIROUT)/crypt_cipher_is_valid.d \
$(DIROUT)/crypt_constants.d \
$(DIROUT)/crypt_find_cipher.d \
$(DIROUT)/crypt_find_cipher_any.d \
$(DIROUT)/crypt_find_cipher_id.d \
$(DIROUT)/crypt_find_hash.d \
$(DIROUT)/crypt_find_hash_any.d \
$(DIROUT)/crypt_find_hash_id.d \
$(DIROUT)/crypt_find_hash_oid.d \
$(DIROUT)/crypt_find_prng.d \
$(DIROUT)/crypt_fsa.d \
$(DIROUT)/crypt_hash_descriptor.d \
$(DIROUT)/crypt_hash_is_valid.d \
$(DIROUT)/crypt_inits.d \
$(DIROUT)/crypt_ltc_mp_descriptor.d \
$(DIROUT)/crypt_prng_descriptor.d \
$(DIROUT)/crypt_prng_is_valid.d \
$(DIROUT)/crypt_prng_rng_descriptor.d \
$(DIROUT)/crypt_register_all_ciphers.d \
$(DIROUT)/crypt_register_all_hashes.d \
$(DIROUT)/crypt_register_all_prngs.d \
$(DIROUT)/crypt_register_cipher.d \
$(DIROUT)/crypt_register_hash.d \
$(DIROUT)/crypt_register_prng.d \
$(DIROUT)/crypt_sizes.d \
$(DIROUT)/crypt_unregister_cipher.d \
$(DIROUT)/crypt_unregister_hash.d \
$(DIROUT)/crypt_unregister_prng.d \
$(DIROUT)/EL1Debug.d \
$(DIROUT)/performance_EL1.d \
$(DIROUT)/printf.d \
$(DIROUT)/uartN_redirect.d \
$(DIROUT)/capattest.d \
$(DIROUT)/unique_alloc.d \
$(DIROUT)/EL2Entry.d \
$(DIROUT)/exceptionHandlerFuncsEL1N.d \
$(DIROUT)/exceptionHandlerFuncsEL2N.d \
$(DIROUT)/uartEL2N.d \
$(DIROUT)/initfunc.d \
$(DIROUT)/EINIT_CODE.d \
$(DIROUT)/EINIT_DATA.d \
$(DIROUT)/ESTORE_ID.d \
$(DIROUT)/enclaveIDManager.d \
$(DIROUT)/enclaveid.d \
$(DIROUT)/hash.d \
$(DIROUT)/identityStore.d \
$(DIROUT)/regsweep.d \
$(DIROUT)/sealingCapability.d \
$(DIROUT)/capfuncs.d \
$(DIROUT)/performance.d \
$(DIROUT)/el1nMemAccess.d \
$(DIROUT)/test_EINIT_CODE.d \
$(DIROUT)/test_EINIT_DATA.d \
$(DIROUT)/test_ESTORE_ID.d 
#$(DIROUT)/EL1Nentry.d \
#$(DIROUT)/test_EL1Nentry.d \


# build o and d files into outputs directory for every source directory defined
# "S@" is output "$<" is input
#$(CFLAGS) $(DIROUT) defined in parent file, $(IDIR) is include directories and defined here

# SRCDIR1
$(DIROUT)/%.o: $(SRCDIR1)/%.c
	@ mkdir -p $(DIROUT) #make directory if it doesn't exist
	@echo 'Build file: $<'
	@echo 'Using: LLVM C Compiler 11.0.0'
	$(CC) $(CFLAGS) $(IDIR) -O0 -g -MMD -MP -c -o "$@" "$<"
	@echo 'Done: $<'
	@echo ' '

# SRCDIR2
$(DIROUT)/%.o: $(SRCDIR2)/%.c
	@ mkdir -p $(DIROUT) #make directory if it doesn't exist
	@echo 'Build file: $<'
	@echo 'Using: LLVM C Compiler 11.0.0'
	$(CC) $(CFLAGS) $(IDIR) -O0 -g -MMD -MP -c -o "$@" "$<"
	@echo 'Done: $<'
	@echo ' '

# SRCDIR3
$(DIROUT)/%.o: $(SRCDIR3)/%.c
	@ mkdir -p $(DIROUT) #make directory if it doesn't exist
	@echo 'Build file: $<'
	@echo 'Using: LLVM C Compiler 11.0.0'
	$(CC) $(CFLAGS) $(IDIR) -O0 -g -MMD -MP -c -o "$@" "$<"
	@echo 'Done: $<'
	@echo ' '

# SRCDIR4
$(DIROUT)/%.o: $(SRCDIR4)/%.c
	@ mkdir -p $(DIROUT) #make directory if it doesn't exist
	@echo 'Build file: $<'
	@echo 'Using: LLVM C Compiler 11.0.0'
	$(CC) $(CFLAGS) $(IDIR) -O0 -g -MMD -MP -c -o "$@" "$<"
	@echo 'Done: $<'
	@echo ' '

# SRCDIR5
$(DIROUT)/%.o: $(SRCDIR5)/%.c
	@ mkdir -p $(DIROUT) #make directory if it doesn't exist
	@echo 'Build file: $<'
	@echo 'Using: LLVM C Compiler 11.0.0'
	$(CC) $(CFLAGS) $(IDIR) -O0 -g -MMD -MP -c -o "$@" "$<"
	@echo 'Done: $<'
	@echo ' '

# SRCDIR5 asm
$(DIROUT)/%.o: $(SRCDIR5)/%.S
	@ mkdir -p $(DIROUT) #make directory if it doesn't exist
	@echo 'Build file: $<'
	@echo 'Using: LLVM Assembler 11.0.0'
	$(CC) $(CFLAGS) $(IDIR) -c -o "$@" "$<"
	@echo 'Done: $<'
	@echo ' '

# SRCDIR6
$(DIROUT)/%.o: $(SRCDIR6)/%.c
	@ mkdir -p $(DIROUT) #make directory if it doesn't exist
	@echo 'Build file: $<'
	@echo 'Using: LLVM C Compiler 11.0.0'
	$(CC) $(CFLAGS) $(IDIR) -O0 -g -MMD -MP -c -o "$@" "$<"
	@echo 'Done: $<'
	@echo ' '

# SRCDIR6 asm
$(DIROUT)/%.o: $(SRCDIR6)/%.S
	@ mkdir -p $(DIROUT) #make directory if it doesn't exist
	@echo 'Build file: $<'
	@echo 'Using: LLVM Assembler 11.0.0'
	$(CC) $(CFLAGS) $(IDIR) -c -o "$@" "$<"
	@echo 'Done: $<'
	@echo ' '

# SRCDIR7
$(DIROUT)/%.o: $(SRCDIR7)/%.c
	@ mkdir -p $(DIROUT) #make directory if it doesn't exist
	@echo 'Build file: $<'
	@echo 'Using: LLVM C Compiler 11.0.0'
	$(CC) $(CFLAGS) $(IDIR) -O0 -g -MMD -MP -c -o "$@" "$<"
	@echo 'Done: $<'
	@echo ' '

# SRCDIR7 asm
$(DIROUT)/%.o: $(SRCDIR7)/%.S
	@ mkdir -p $(DIROUT) #make directory if it doesn't exist
	@echo 'Build file: $<'
	@echo 'Using: LLVM Assembler 11.0.0'
	$(CC) $(CFLAGS) $(IDIR) -c -o "$@" "$<"
	@echo 'Done: $<'
	@echo ' '

# SRCDIR8
$(DIROUT)/%.o: $(SRCDIR8)/%.c
	@ mkdir -p $(DIROUT) #make directory if it doesn't exist
	@echo 'Build file: $<'
	@echo 'Using: LLVM C Compiler 11.0.0'
	$(CC) $(CFLAGS) $(IDIR) -O0 -g -MMD -MP -c -o "$@" "$<"
	@echo 'Done: $<'
	@echo ' '

# SRCDIR8 asm
$(DIROUT)/%.o: $(SRCDIR8)/%.S
	@ mkdir -p $(DIROUT) #make directory if it doesn't exist
	@echo 'Build file: $<'
	@echo 'Using: LLVM Assembler 11.0.0'
	$(CC) $(CFLAGS) $(IDIR) -c -o "$@" "$<"
	@echo 'Done: $<'
	@echo ' '

# SRCDIR9
$(DIROUT)/%.o: $(SRCDIR9)/%.c
	@ mkdir -p $(DIROUT) #make directory if it doesn't exist
	@echo 'Build file: $<'
	@echo 'Using: LLVM C Compiler 11.0.0'
	$(CC) $(CFLAGS) $(IDIR) -O0 -g -MMD -MP -c -o "$@" "$<"
	@echo 'Done: $<'
	@echo ' '

# SRCDIR10
$(DIROUT)/%.o: $(SRCDIR10)/%.c
	@ mkdir -p $(DIROUT) #make directory if it doesn't exist
	@echo 'Build file: $<'
	@echo 'Using: LLVM C Compiler 11.0.0'
	$(CC) $(CFLAGS) $(IDIR) -O0 -g -MMD -MP -c -o "$@" "$<"
	@echo 'Done: $<'
	@echo ' '

# SRCDIR11 - for tests
$(DIROUT)/%.o: $(SRCDIR11)/%.c
	@ mkdir -p $(DIROUT) #make directory if it doesn't exist
	@echo 'Build file: $<'
	@echo 'Using: LLVM C Compiler 11.0.0'
	$(CC) $(CFLAGS) $(IDIR) -O0 -g -MMD -MP -c -o "$@" "$<"
	@echo 'Done: $<'
	@echo ' '


