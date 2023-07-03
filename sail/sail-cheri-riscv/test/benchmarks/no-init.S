#include "test_macros_2.h"

RVTEST_RV64U
RVTEST_CODE_BEGIN

/////////////////////////////////////////////
// Setup
/////////////////////////////////////////////

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
