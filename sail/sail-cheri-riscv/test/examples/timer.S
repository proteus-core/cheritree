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
// We first make a cap that is used to access the memory mapped clock
cspecialrw c17, ddc, c0
li x10, 0x2000000
li x11, 0XBFF8
add x10, x10, x11
csetaddr c17, c17, x10
li x10, 8
csetboundsexact c17, c17, x10

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

    // Start by calling enclave 1
    xor x1, x1, x1
    cinvoke c20, c21
    j fail // This should never be reached

/////////////////////////////////////////////
// Code of enclave 1
/////////////////////////////////////////////

.align 4
enclave:
    // Jump "table", the entry point of the enclave
    beqz x1, init
    li x10, 1
    beq x1, x10, loadkeys
    li x10, 2
    beq x1, x10, start_timer
    li x10, 3
    beq x1, x10, stop_timer

init:
    li x10, 0x20
    csetoffset c31, c31, x10
    ld.cap x11, (c31)
    bnez x11, end_init
    li x10, 0x28
    sd.cap x10, (c31)
end_init:
    xor x31, x31, x31
    xor x1, x1, x1
    cinvoke c22, c23

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

start_timer:
    // Load private keys
    lc.cap c5, (c31)
    li x10, 0x10
    csetoffset c31, c31, x10
    lc.cap c6, (c31)

    // Decrypt with private key
    cunseal c2, c2, c5
    // Read argument (nonce)
    ld.cap x10, (c2)

    // Load first free address
    cincoffsetimm c31, c31, 0x10
    ld.cap x11, (c31)
    csetoffset c31, c31, x11
    
    // Store nonce
    sd.cap x10, (c31)
    
    // Load time
    ld.cap x10, (c17)

    // Store time
    li x11, 8
    cincoffset c31, c31, x11
    sd.cap x10, (c31)
    cincoffset c31, c31, x11

    // Update stored offset
    cgetoffset x11, c31
    li x10, 0x20
    csetoffset c31, c31, x10
    sd.cap x11, (c31)

    // Make a cap to send to the caller
    cmove c2, c31
    addi x11, x11, -0x10
    csetoffset c31, c31, x11
    li x10, 0x10
    csetboundsexact c2, c31, x10

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

//TODO use incoffsetimmideate everywhere
stop_timer:
    // Load private keys
    lc.cap c5, (c31)
    li x10, 0x10
    csetoffset c31, c31, x10
    lc.cap c6, (c31)

    // Decrypt with private key
    cunseal c2, c2, c5

    // Read nonce and prev time
    ld.cap x10, (c2)
    cincoffsetimm c2, c2, 8
    ld.cap x12, (c2)

    // Load first free address
    li x11, 0x10
    cincoffset c31, c31, x11
    ld.cap x11, (c31)
    csetoffset c31, c31, x11
    
    // Store nonce
    sd.cap x10, (c31)
    
    // Load time and subtract with prev time
    ld.cap x10, (c17)
    sub x10, x10, x12

    // Store time
    li x11, 8
    cincoffset c31, c31, x11
    sd.cap x10, (c31)
    cincoffset c31, c31, x11

    // Update stored offset
    cgetoffset x11, c31
    li x10, 0x20
    csetoffset c31, c31, x10
    sd.cap x11, (c31)

    // Make a cap to send to the caller
    cmove c2, c31
    addi x11, x11, -0x10
    csetoffset c31, c31, x11
    li x10, 0x10
    csetboundsexact c2, c31, x10

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
    li x1, 3
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
    beq x1, x10, request_time
    li x10, 2
    beq x1, x10, use_time
    li x10, 3
    beq x1, x10, verify_result
getpubkeys:
    // Request pubkeys from enclave
    // Clear registers
    xor x31, x31, x31

    // Call other enclave
    li x1, 1
    cinvoke c20, c21

use_time:
    // Make sure the enclave still exists
    cgetaddr x10, c8
    estoreidsign x10, x10, c0
    beqz x10, fail

    // Verify signature and load nonce inside of capability
    cunseal c2, c2, c8
    ld.cap x10, (c2)

    // Load nonce that we stored ourself
    li x11, 0x20
    csetoffset c31, c31, x11
    ld.cap x11, (c31)

    // Verify
    bne x10, x11, fail
    
    // Load time we got from enclave
    li x10, 8
    cincoffset c2, c2, x10
    ld.cap x12, (c2)

    // Let some time pass
    li x10, 0x10000
    idle_loop:
        li x11, 0x123456789
        addi x10, x10, -1
        bnez x10, idle_loop

    li x10, 11735001631766472958 // Generate a nonce https://xkcd.com/221/

    // Store the nonce so we can access it later
    li x11, 0x20
    csetoffset c31, c31, x11
    sd.cap x10, (c31)

    // Store the nonce a second time somewhere else
    li x11, 0x50
    csetoffset c31, c31, x11
    sd.cap x10, (c31)
    
    // Store the old time
    cincoffsetimm c31, c31, 8
    sd.cap x12, (c31)

    // Create a capability with access to only the args
    li x11, 0x10
    cincoffsetimm c31, c31, -8
    csetboundsexact c2, c31, x11
    
    // Encrypt with public key of other enclave
    cseal c2, c2, c7

    xor x31, x31, x31

    // Call other enclave
    li x1, 3
    cinvoke c20, c21

verify_result:
    // Make sure the enclave still exists
    cgetaddr x10, c8
    estoreidsign x10, x10, c0
    beqz x10, fail

    // Verify signature and load nonce inside of capability
    cunseal c2, c2, c8
    ld.cap x10, (c2)

    // Load nonce that we stored ourself
    li x11, 0x20
    csetoffset c31, c31, x11
    ld.cap x11, (c31)

    // Verify
    bne x10, x11, fail
    
    // Load time we got from enclave
    li x10, 8
    cincoffset c2, c2, x10
    ld.cap x12, (c2)
    
pass:
    RVTEST_PASS
    RVTEST_CODE_END

fail:
    RVTEST_FAIL

request_time:
    // We just received keys, we can now start callee attestation
    // In a real scenario we should also store the public keys because they could be overwritten after calling another enclave

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
    bne x10, x11, fail

    // Part 2
    li x10, 0x08
    cincoffset c31, c31, x10
    cincoffset c2, c2, x10
    ld.cap x10, (c31)
    ld.cap x11, (c2)
    bne x10, x11, fail

    // Part 3
    li x10, 0x08
    cincoffset c31, c31, x10
    cincoffset c2, c2, x10
    ld.cap x10, (c31)
    ld.cap x11, (c2)
    bne x10, x11, fail

    // Part 4
    li x10, 0x08
    cincoffset c31, c31, x10
    cincoffset c2, c2, x10
    ld.cap x10, (c31)
    ld.cap x11, (c2)
    bne x10, x11, fail

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
    bne x10, x11, fail

    // Part 2
    li x10, 0x08
    cincoffset c31, c31, x10
    cincoffset c2, c2, x10
    ld.cap x10, (c31)
    ld.cap x11, (c2)
    bne x10, x11, fail

    // Part 3
    li x10, 0x08
    cincoffset c31, c31, x10
    cincoffset c2, c2, x10
    ld.cap x10, (c31)
    ld.cap x11, (c2)
    bne x10, x11, fail

    // Part 4
    li x10, 0x08
    cincoffset c31, c31, x10
    cincoffset c2, c2, x10
    ld.cap x10, (c31)
    ld.cap x11, (c2)
    bne x10, x11, fail

    // The id checks out, we now send a nonce to be signed by the callee    
    li x10, 5872034539797251818 // Generate a nonce https://xkcd.com/221/

    // Store the nonce so we can access it later
    li x11, 0x20
    csetoffset c31, c31, x11
    sd.cap x10, (c31)

    // Store the nonce a second time somewhere else
    li x11, 0x50
    csetoffset c31, c31, x11
    sd.cap x10, (c31)

    // Create a capability with access to only the nonce
    li x11, 8
    csetboundsexact c2, c31, x11
    
    // Encrypt with public key of other enclave
    cseal c2, c2, c7

    xor x31, x31, x31

    // Call other enclave
    li x1, 2
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
.global hash_1_1; hash_1_1: .dword 0x15BE8BB824DFC420;
.global hash_1_2; hash_1_2: .dword 0x181B81B873764B00;
.global hash_1_3; hash_1_3: .dword 0xED219A935F1A0F88;
.global hash_1_4; hash_1_4: .dword 0xFD3D4BC32C5D8FDB;

.global hash_2_1; hash_2_1: .dword 0x316B80007344C7B0;
.global hash_2_2; hash_2_2: .dword 0xED5DD14C5EE6C290;
.global hash_2_3; hash_2_3: .dword 0xC4F850749B8FF100;
.global hash_2_4; hash_2_4: .dword 0x5AADC5BC7C16C298;
