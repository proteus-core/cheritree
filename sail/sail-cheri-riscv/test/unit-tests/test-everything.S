#include "riscv_test.h"
#include "setup_macros.h"

// More expansive scenario test involving a caller and a callee, with one-way attestation
// I.e., the caller attests the identity of the callee
// Concretely, the control flow (party involved between brackets) of the example is as follows:
// initcode -> getpubkey (caller) -> loadkeys (callee) -> sendnonce (caller)
// -> signnonce (callee) -> verifynonce (caller)

RVTEST_RV64U
RVTEST_CODE_BEGIN

/////////////////////////////////////////////
// Setup first enclave
/////////////////////////////////////////////
ENCLAVE_CODE_SECTION(c1, enclave, end_enclave)
ENCLAVE_DATA_SECTION(c2, enclave_data, end_enclave_data)

/////////////////////////////////////////////
// Setup second enclave
/////////////////////////////////////////////
ENCLAVE_CODE_SECTION(c5, enclave_caller, end_enclave_caller)
ENCLAVE_DATA_SECTION(c6, enclave_caller_data, end_enclave_caller_data)

// Setup ddc and pcc
RESTRICT_DDC_PCC_JUMP(c7, _start, enclave, initcode)

initcode:
    // Init enclave 1
    einitcode c1, c1
    einitdata c2, c1, c2
    cmove c20, c1
    cmove c21, c2

    // Init enclave 2
    einitcode c5, c5
    einitdata c6, c5, c6
    cmove c22, c5
    cmove c23, c6

    // Start by calling enclave 2
    li x1, 0
    cinvoke c22, c23

/////////////////////////////////////////////
// Code of enclave 1
/////////////////////////////////////////////

enclave:
    // Jump "table", the entry point of the enclave
    beqz x1, loadkeys
    li x10, 1
    beq x1, x10, signnonce

loadkeys:
    // Load our public keys in c18 and c19 for later use by the other enclave

    // Load private keys into registers
    lc.cap c5, (c31)

    // Create public keys (c18 = enc, c19 = sign)
    cmove c18, c5
    li x10, 0b0000000010000001 //global, permit seal
    candperm c18, c18, x10
    cincoffsetimm c18, c18, 1 //point to enc seal
   	li x10, 1
    csetboundsexact c18, c18, x10 //only access enc seal

    cmove c19, c5
    li x10, 0b0000001000000001 //global, permit unseal
    candperm c19, c19, x10
    li x10, 1
    csetboundsexact c19, c19, x10 //only access sign seal

    // Clear registers that should not leak
    cmove c31, c0
    cmove c5, c0

    // Return to caller
    li x1, 1
    cinvoke c22, c23

signnonce:
    // Load private keys
    lc.cap c5, (c31)
    cincoffsetimm c5, c5, 1 //encrypt seal

    // Decrypt with private key
	  cunseal c2, c2, c5
    // Sign nonce in-place (note; in general, nonce would be copied over and put in same buffer as return value)
    cincoffsetimm c5, c5, -1 //sign seal
	  cseal c2, c2, c5

    // Clear registers
    cmove c31, c0
    cmove c5, c0

    // Call other enclave
    li x1, 2
    cinvoke c22, c23

end_enclave:


/////////////////////////////////////////////
// Code of enclave 2
/////////////////////////////////////////////

.p2align 2
enclave_caller:
    // Entry point
    beqz x1, getpubkeys
    li x10, 1
    beq x1, x10, sendnonce
    li x10, 2
    beq x1, x10, verifynonce
getpubkeys:
    // Jump to the callee to get its keys

    // Clear registers
    cmove c31, c0

    // Call other enclave
    li x1, 0
    cinvoke c20, c21

sendnonce:
    // We just received keys, we can now start callee and caller attestation
    // In a real scenario we should also store the public keys because they could be overwritten after calling another enclave

    // Load private signing key (for later)
    lc.cap c6, (c31)

    /////////////////////////////////////////////
    // Verify callee's signing key
    /////////////////////////////////////////////

    // Set up cap to store hash in c30
    LA_OTHER(c30,hash,c31)

    // Point c31 to the expected hash
    LA_OTHER(c29,expected_hash,c31)

    //Load relative offset of `end_hash` in x6
    la x6, enclave_caller_data
    la x7, end_hash
    sub x6, x7, x6

    // Get address of the callee's public signing key
    cgetaddr x10, c19
    // We store the id in our own data section (c30) for convenience
    estoreid x10, x10, c30
    beqz x10, fail // Should be 1

    1:
        lw.cap x7, (c30)
        lw.cap x8, (c29)
        bne x7, x8, fail
        CIncOffsetImm c30, c30, 4
        CIncOffsetImm c29, c29, 4
        CGetOffset x7, c30
        blt x7, x6, 1b

    /////////////////////////////////////////////
    // Verify callee's encryption key
    /////////////////////////////////////////////
    //NOTE: following is more implementation-dependent than just calling `estoreid` again and repeating the previous verification procedure

    //Sign should be one less than the encryption key...
    cgetaddr x10, c18
    cgetaddr x11, c19
    sub x12, x10, x11
    addi x12, x12, -1
    bnez x12, fail

	  //... and same value after >>2
    srli x10, x10, 2
    srli x11, x11, 2
    bne x10, x11, fail

    /////////////////////////////////////////////
    // Nonce creation
    /////////////////////////////////////////////
    //NOTE: a better way of creating nonces would be to simply have the nonce value as the address on a NULL-capability

    // The id checks out, we now send a nonce to be signed by the callee    
    li x12, 5872034 // Generate a nonce https://xkcd.com/221/

    // Store the nonce privately in `nonce_priv` so we can access it later
    LA_OTHER(c30,nonce_priv,c31)
    sw.cap x12, (c30)

    // Store the nonce a second time, publicly, in `nonce_pub`
   	LA_OTHER(c30,nonce_pub,c31)
    sw.cap x12, (c30)

    // Create a public capability with access to only the nonce
    li x11, 4
    csetboundsexact c2, c31, x11

    // Make nonce memory read only: allows reuse
    li x11, 0b0000000000010101
	  candperm c2, c2, x11

    // Encrypt with public `enc` key of other enclave
    cseal c2, c2, c18

    // Wipe sensitive capabilities
    cmove c5, c0
    cmove c29, c0
    cmove c30, c0
    cmove c31, c0

    // Call other enclave
    li x1, 1
    cinvoke c20, c21

verifynonce:
    // Verify signature and load nonce inside of capability
    // NOTE: this is not actually secure, as we do not check the caller's sign key again
    cunseal c2, c2, c19
    lw.cap x12, (c2)

    // Load nonce that we stored ourselves
    LA_OTHER(c30,nonce_priv,c31)
    lw.cap x11, (c31)

    // Verify
    bne x12, x11, fail

pass:
    RVTEST_PASS

fail:
    RVTEST_FAIL

end_enclave_caller:
RVTEST_CODE_END

RVTEST_DATA_BEGIN
.p2align 4
enclave_data:
  .fill CAP_LEN
end_enclave_data:

.p2align 4
enclave_caller_data:
  .fill CAP_LEN
hash:
  .fill HASH_LEN //reserve space for final hash
end_hash:
expected_hash:
  .fill HASH_LEN //Store expected hash of callee here during make
nonce_priv:
  .fill 4
nonce_pub:
 	.fill 4
end_enclave_caller_data:
RVTEST_DATA_END
