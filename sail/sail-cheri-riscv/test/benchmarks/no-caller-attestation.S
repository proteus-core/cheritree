#include "test_macros.h"

RVTEST_RV64U
RVTEST_CODE_BEGIN

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

cspecialrw c3, pcc, c0
la x10, enclave2
auipc x11, 0
sub x10, x10, x11
addi x10, x10, 12
cincoffset c3, c3, x10
cgetaddr x28, c3

cspecialrw c3, pcc, c0
la x10, end_enclave_2
auipc x11, 0
sub x10, x10, x11
addi x10, x10, 12
cincoffset c3, c3, x10
cgetaddr x29, c3

cspecialrw c3, pcc, c0
la x10, hash_1_1
auipc x11, 0
sub x10, x10, x11
addi x10, x10, 12
cincoffset c3, c3, x10
cgetaddr x13, c3

cspecialrw c3, pcc, c0
la x10, hash_2_1
auipc x11, 0
sub x10, x10, x11
addi x10, x10, 12
cincoffset c3, c3, x10
cgetaddr x19, c3

cspecialrw c3, pcc, c0
la x10, start_data
auipc x11, 0
sub x10, x10, x11
addi x10, x10, 12
cincoffset c3, c3, x10
cgetaddr x30, c3


/////////////////////////////////////////////
// Setup first enclave
/////////////////////////////////////////////

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

/////////////////////////////////////////////
// Setup second enclave
/////////////////////////////////////////////

// Setup code capability in c5
cspecialrw c5, ddc, c0
cmove c6, c5
mv x10, x28 // la x10, enclave
csetaddr c6, c6, x10
mv x11, x29 // la x11, end_enclave
sub x11, x11, x10 // Length
csetboundsexact c5, c6, x11

// Setup for data section (base = 0x80200000, length = 512 in c3)
cspecialrw c7, ddc, c0
li x10, 0x80200000
cmove c8, c7
csetoffset c8, c8, x10
li x10, 512
csetboundsexact c7, c8, x10
li x12, 0b1111111111111101 // If permit execute is set ccall will raise an exception
candperm c7, c7, x12

// Setup ddc and pcc
// Move ddc after enclave, so we can write to tohost
cspecialrw c14, ddc, c0
cmove c15, c14
csetaddr c15, c15, x30
li x10, 0x4000
csetbounds c14, c15, x10
cspecialrw c14, ddc, c14

// Change pcc so it has only the required permissions
cspecialrw c16, pcc, c0
mv x10, x27 // la x10, initcode
csetaddr c16, c16, x10
mv x11, x25 // la enclave
sub x11, x11, x10
csetboundsexact c16, c16, x11
cjalr c4, c16 // PCC is read only so we use this instead

initcode:
    xor x2, x2, x2
    xor x4, x4, x4
    xor x6, x6, x6
    xor x8, x8, x8
    xor x14, x14, x14
    xor x15, x15, x15
    xor x16, x16, x16

    // Init enclave 1
    einitcode c2, c1
    einitdata c4, c2, c3
    cmove c20, c2
    cmove c21, c4
    
    // Init enclave 2   
    einitcode c6, c5
    einitdata c8, c6, c7
    cmove c22, c6
    cmove c23, c8

    // Start by calling enclave 2
    cinvoke c22, c23
    j fail // This should never be reached

/////////////////////////////////////////////
// Code of enclave 1
/////////////////////////////////////////////

.align 4
enclave:
    // Jump "table", the entry point of the enclave
    beqz x1, loadkeys
    li x10, 1
    beq x1, x10, fac

loadkeys:
    // Load our public keys in c7 and c8 for later use by the other enclave
    // Load private keys into registers (c5 = enc, c6 = sign)
    lc.cap c5, (c31)
    li x10, 0x10
    csetoffset c31, c31, x10
    lc.cap c6, (c31)

    // Create public keys (c7 = enc_p, c8 = sign_p)
    cmove c7, c5
    cmove c8, c6
    li x10, 0b0000000010000001
    candperm c7, c7, x10
    li x10, 0b0000001000000001
    candperm c8, c8, x10

    // Clear registers that should not leak
    xor x31, x31, x31
    xor x5, x5, x5
    xor x6, x6, x6
    // Call other enclave

    li x1, 1
    cinvoke c22, c23

fac:
    // Load private keys
    lc.cap c5, (c31)
    li x10, 0x10
    csetoffset c31, c31, x10
    lc.cap c6, (c31)

    // Decrypt with private key
    cunseal c2, c2, c5
    // Read nonce
    ld.cap x12, (c2)
    // Read n
    cincoffsetimm c2, c2, 8
    ld.cap x11, (c2)

    // Calculate fac
    li x10, 1
    fac_loop:
        beqz x11, end_fac
        mul x10, x10, x11
        addi x11, x11, -1
        j fac_loop
    end_fac:
    // Result is in x10
    
    // Store nonce and result
    li x11, 0x20
    csetoffset c31, c31, x11
    sd.cap x12, (c31)
    cmove c2, c31
    cincoffsetimm c31, c31, 8
    sd.cap x10, (c31)

    // Make cap for nonce and result
    li x12, 0x10
    csetboundsexact c2, c2, x12

    // Encrypt with caller public key
    cseal c2, c2, c17

    // Store
    li x11, 0x30
    csetoffset c31, c31, x11
    sc.cap c2, (c31)   
    csetboundsexact c2, c31, x12

    // Make cap read-only
    li x11, 0b0000000000010101
    candperm c2, c2, x11
    // Sign with private key
    cseal c2, c2, c6

    // Clear registers
    xor x31, x31, x31
    xor x5, x5, x5
    xor x6, x6, x6

    // Call other enclave
    li x1, 2
    cinvoke c22, c23

end_enclave:

/////////////////////////////////////////////
// Code of enclave 2
/////////////////////////////////////////////

.align 8
enclave2:
    // Entry point
    beqz x1, getpubkeys
    li x10, 1
    beq x1, x10, call_fac
    li x10, 2
    beq x1, x10, get_result
getpubkeys:
    // Load our own public keys into registers and ask the other enclave to do the same
    // Load keys into registers (c5 = enc, c6 = sign)
    lc.cap c5, (c31)
    li x10, 0x10
    csetoffset c31, c31, x10
    lc.cap c6, (c31)

    // Create public keys, store them in c17 (enc) and c18 (sign)
    cmove c17, c5
    cmove c18, c6
    li x10, 0b0000000010000001
    candperm c17, c17, x10
    li x10, 0b0000001000000001
    candperm c18, c18, x10

    // Clear registers
    xor x31, x31, x31
    xor x5, x5, x5
    xor x6, x6, x6

    // Call other enclave
    xor x1, x1, x1
    cinvoke c20, c21

get_result:
    // Load private enc key
    lc.cap c5, (c31)

    // Verify signature
    cunseal c2, c2, c8
    // Load encrypted cap
    lc.cap c2, (c2)
    // Decrypt
    cunseal c2, c2, c5

    // Load nonce
    ld.cap x10, (c2)

    // Load nonce that we stored ourself
    li x11, 0x20
    csetoffset c31, c31, x11
    ld.cap x11, (c31)

    // Verify
    bne x10, x11, fail

    // Load result
    cincoffsetimm c2, c2, 8
    ld.cap x11, (c2)

pass:
    RVTEST_PASS
    RVTEST_CODE_END

fail:
    RVTEST_FAIL

call_fac:
    // We just received keys, we can now start callee and caller attestation
    // In a real scenario we should also store the public keys because they could be overwritten after calling another enclave

    // Load private signing key (for later)
    li x10, 0x10
    csetoffset c31, c31, x10
    lc.cap c6, (c31)

    // Verify enc
    li x10, 0x20
    csetoffset c31, c31, x10
    cgetaddr x10, c7
    estoreidenc x10, x10, c31
    beqz x10, fail

    // Test if the id is correct (part 1)
    ld.cap x10, (c31)
    cspecialrw c2, ddc, c0
    mv x11, x13 // la x11, hash_1_1
    csetaddr c2, c2, x11
    ld.cap x11, (c2)
    //bne x10, x11, fail

    // Part 2
    li x10, 0x08
    cincoffset c31, c31, x10
    cincoffset c2, c2, x10
    ld.cap x10, (c31)
    ld.cap x11, (c2)
    //bne x10, x11, fail

    // Part 3
    li x10, 0x08
    cincoffset c31, c31, x10
    cincoffset c2, c2, x10
    ld.cap x10, (c31)
    ld.cap x11, (c2)
    //bne x10, x11, fail

    // Part 4
    li x10, 0x08
    cincoffset c31, c31, x10
    cincoffset c2, c2, x10
    ld.cap x10, (c31)
    ld.cap x11, (c2)
    //bne x10, x11, fail

    // Next verify sign
    li x10, 0x20
    csetoffset c31, c31, x10
    cgetaddr x10, c8
    estoreidsign x10, x10, c31
    beqz x10, fail

    // Test if the id is correct (part 1)
    ld.cap x10, (c31)
    cspecialrw c2, ddc, c0
    mv x11, x13 // la x11, hash_1_1
    csetaddr c2, c2, x11
    ld.cap x11, (c2)
    //bne x10, x11, fail

    // Part 2
    li x10, 0x08
    cincoffset c31, c31, x10
    cincoffset c2, c2, x10
    ld.cap x10, (c31)
    ld.cap x11, (c2)
    //bne x10, x11, fail

    // Part 3
    li x10, 0x08
    cincoffset c31, c31, x10
    cincoffset c2, c2, x10
    ld.cap x10, (c31)
    ld.cap x11, (c2)
    //bne x10, x11, fail

    // Part 4
    li x10, 0x08
    cincoffset c31, c31, x10
    cincoffset c2, c2, x10
    ld.cap x10, (c31)
    ld.cap x11, (c2)
    //bne x10, x11, fail

    // The id checks out, we now send a nonce to be signed by the callee    
    li x10, 5872034539797251818 // Generate a nonce https://xkcd.com/221/

    // Store the nonce so we can access it later
    li x11, 0x20
    csetoffset c31, c31, x11
    sd.cap x10, (c31)

    // Store nonce and argument for callee
    li x11, 0x50
    csetoffset c31, c31, x11
    sd.cap x10, (c31)
    cmove c2, c31
    cincoffsetimm c31, c31, 8
    li x10, 5
    sd.cap x10, (c31)

    // Create a capability with access to only the nonce and argument
    li x11, 16
    csetboundsexact c2, c2, x11
    
    // Encrypt with public key of other enclave
    cseal c2, c2, c7

    xor x31, x31, x31
    xor x6, x6, x6

    // Call other enclave
    li x1, 1
    cinvoke c20, c21

end_enclave_2:

// This helps us avoid needing exact bounds on the ddc
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop
nop

start_data:

.align 6; .global tohost; tohost: .dword 0;

.rodata
.align 8
.global hash_1_1; hash_1_1: .dword 0x1D80950B3DC413AB;
.global hash_1_2; hash_1_2: .dword 0xE6FD97ABFB2200E3;
.global hash_1_3; hash_1_3: .dword 0x62C7924382DE148B;
.global hash_1_4; hash_1_4: .dword 0xE76D367CD8441070;

.global hash_2_1; hash_2_1: .dword 0x9927C3B3294B5197;
.global hash_2_2; hash_2_2: .dword 0x6D63954B1D615697;
.global hash_2_3; hash_2_3: .dword 0x6D87DEF3C4998EDB;
.global hash_2_4; hash_2_4: .dword 0x97F2259892645F67;
