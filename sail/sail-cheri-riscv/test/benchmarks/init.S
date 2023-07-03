#include "test_macros.h"

RVTEST_RV64U
RVTEST_CODE_BEGIN

/////////////////////////////////////////////
// Setup
/////////////////////////////////////////////

// la replacements
cspecialrw c3, pcc, c0
la x10, enclave
auipc x11, 0
sub x10, x10, x11
addi x10, x10, 12
cincoffset c3, c3, x10
cgetaddr x25, c3

cspecialrw c3, pcc, c0
la x10, end_enclave
auipc x11, 0
sub x10, x10, x11
addi x10, x10, 12
cincoffset c3, c3, x10
cgetaddr x26, c3

cspecialrw c3, pcc, c0
la x10, initcode
auipc x11, 0
sub x10, x10, x11
addi x10, x10, 12
cincoffset c3, c3, x10
cgetaddr x27, c3

// Setup code capability in c1
cspecialrw c1, ddc, c0
cmove c2, c1
mv x10, x25 // la x10, enclave
csetaddr c2, c2, x10
mv x11, x26 // la x11, end_enclave
sub x11, x11, x10 // Length
csetboundsexact c1, c2, x11

// Setup for data section (base = 0x80100000, length = 512 in c3)
cspecialrw c3, ddc, c0
li x10, 0x80100000
cmove c4, c3
csetoffset c4, c4, x10
li x10, 512
csetboundsexact c3, c4, x10
li x12, 0b1111111111111101 // If permit execute is set ccall will raise an exception
candperm c3, c3, x12

// Move ddc after enclave, so we can write to tohost
cspecialrw c4, ddc, c0
cmove c5, c4
csetaddr c5, c5, x26
li x10, 512
csetboundsexact c4, c5, x10
cspecialrw c4, ddc, c4

// Change pcc so it has only the required permissions
cspecialrw c6, pcc, c0
mv x10, x27 // la x10, initcode
csetaddr c6, c6, x10
mv x11, x25 // la enclave
sub x11, x11, x10
csetboundsexact c6, c6, x11
cjalr c4, c6 // PCC is read only so we use this instead

// Call einitcode and einitdata and jump to enclave
initcode:
    xor x2, x2, x2
    xor x4, x4, x4
    xor x5, x5, x5
    xor x6, x6, x6
    einitcode c2, c1
    einitdata c4, c2, c3 // Initialisation is done here
    RVTEST_PASS
    RVTEST_CODE_END

.align 4
enclave:
    // Load keys into registers (c5 = enc, c6 = sign)
    lc.cap c5, (c31)
    li x10, 0x10
    csetoffset c31, c31, x10
    lc.cap c6, (c31)

    /////////////////////////////////////////////
    // Test basic properties on keys
    /////////////////////////////////////////////

    // The length should be 1
    li x11, 1
    cgetlen x10, c5
    bne x10, x11, fail
    cgetlen x10, c6
    bne x10, x11, fail

    // Offset should be zero
    cgetoffset x11, c5
    bnez x11, fail
    cgetoffset x11, c6
    bnez x11, fail

    // Base should be 2 and 3 (since this is the first time einitdata was called)
    li x10, 2
    cgetbase x11, c5
    bne x10, x11, fail
    li x10, 3
    cgetbase x11, c6
    bne x10, x11, fail

    /////////////////////////////////////////////
    // Test encryption/signing
    /////////////////////////////////////////////

    // Create public keys (c7 = enc_p, c8 = sign_p)
    cmove c7, c5
    cmove c8, c6
    li x10, 0b0000000010000001
    candperm c7, c7, x10
    li x10, 0b0000001000000001
    candperm c8, c8, x10

    // Instead of passing the keys to another enclave, we just try using them ourself
    // Encryption test
    cspecialrw c1, ddc, c0 // Random cap to encrypt
    cseal c9, c1, c7 // Encrypt
    cgetsealed x10, c9
    beqz x10, fail
    cunseal c9, c9, c5 // Decrypt
    cgetsealed x10, c9
    bnez x10, fail

    // Signing test
    cseal c9, c1, c6 // Sign
    cgetsealed x10, c9
    beqz x10, fail
    cunseal c9, c9, c8 // Verify signature
    cgetsealed x10, c9
    bnez x10, fail
end_enclave:
fail:
    RVTEST_FAIL


.align 6; .global tohost; tohost: .dword 0;
