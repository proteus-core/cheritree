    #include "cheri.h"

    .section .enclave.user.text, "ax", @progbits

    # 4 capabilities for the struct enclave of sensor
    # 1 capability for the buffer to send a nonce to sensor
    # 32 bytes for SHA256 id
    #define ENCLAVE_DATA_SIZE       (5 * CAP_LEN + 32)
    #define DATA_OFFSET_SENSOR_CODE (0 * CAP_LEN)
    #define DATA_OFFSET_SENSOR_DATA (1 * CAP_LEN)
    #define DATA_OFFSET_SENSOR_ENC  (2 * CAP_LEN)
    #define DATA_OFFSET_SENSOR_SIGN (3 * CAP_LEN)
    #define DATA_OFFSET_ARGS        (4 * CAP_LEN)
    #define DATA_OFFSET_BUF         (6 * CAP_LEN)

    #include "enclave_entry.S"

enclave_entries_start:
    .word set_sensor_enclave - user_code_start
    .word use_sensor - user_code_start
enclave_entries_end:

set_sensor_enclave:
    # ca0 contains a pointer to a struct enclave
    # We store the entry capabilities and seals at the beginning of our data
    # section. ct1 points here. The space after that is used as a buffer
    # for EStoreId.
    # To verify the enc seal, we pass its base to EStoreId
    # TODO check perm
    CIncOffsetImm ct2, ca0, 2 * CAP_LEN
    lc.cap ct2, (ct2) # ct2 = enclave->enc_seal
    CGetTag t0, ct2
    beqz t0, set_sensor_enclave_fail
    CGetBase t0, ct2

    # Create pointer to the buffer for EStoreId
    CIncOffsetImm ct3, ct1, DATA_OFFSET_BUF
    CSetBoundsImm ct3, ct3, 32 # length=256 bits

    EStoreId t1, t0, ct3
    beqz t1, set_sensor_enclave_fail

    # Check id against expected one
    # First create a pointer to the expected id based on PCC
    CSpecialR ct4, pcc
    la t1, sensor_id_start
    CSetOffset ct4, ct4, t1
    la t2, sensor_id_end

1:
    lw.cap t3, (ct3) # Word of actual id
    lw.cap t4, (ct4) # Word of expected id
    bne t3, t4, set_sensor_enclave_fail

    CIncOffsetImm ct3, ct3, 4
    CIncOffsetImm ct4, ct4, 4
    CGetOffset t3, ct4
    blt t3, t2, 1b

    # To verify the sign seal, we check if its base is one larger than the one
    # of the enc seal
    # TODO check perm
    CIncOffsetImm ct3, ca0, 3 * CAP_LEN
    lc.cap ct3, (ct3) # ct3 = enclave->sign_seal
    CGetBase t1, ct3
    addi t1, t1, -1
    bne t0, t1, set_sensor_enclave_fail

    # Store the entry capabilities and seals in our data section
    # enc_seal/sign_seal are already in ct2/ct3
    # ca0 = struct enclave, ct1 = base of data section (after our seal)
    CIncOffsetImm ct5, ct1, DATA_OFFSET_SENSOR_CODE
    lc.cap ct4, (ca0)
    sc.cap ct4, (ct5) # enclave->code_cap
    CIncOffsetImm ca0, ca0, CAP_LEN
    CIncOffsetImm ct5, ct1, DATA_OFFSET_SENSOR_DATA
    lc.cap ct4, (ca0)
    sc.cap ct4, (ct5) # enclave->data_cap
    CIncOffsetImm ct5, ct1, DATA_OFFSET_SENSOR_ENC
    sc.cap ct2, (ct5) # enclave->enc_seal
    CIncOffsetImm ct5, ct1, DATA_OFFSET_SENSOR_SIGN
    sc.cap ct3, (ct5) # enclave->sign_seal

    j enclave_exit

set_sensor_enclave_fail:
    CClearTag ca0, ca0
    j enclave_exit

use_sensor:
    # ca0 contains a capability to [nonce, space for result]
    # Load nonce
    lw.cap t0, (ca0)

    # Store ca0 on the stack
    CIncOffsetImm csp, csp, -CAP_LEN
    sc.cap ca0, (csp)

    # Create capability to argument buffer [our enc seal, nonce, result]
    CIncOffsetImm ca0, ct1, DATA_OFFSET_ARGS
    CSetBoundsImm ca0, ca0, CAP_LEN + 2 * __riscv_xlen

    # Create and store our public enc seal
    CSetBoundsImm ct2, ct0, 1
    li t1, (1 << PERM_PERMIT_SEAL)
    CAndPerm ct2, ct2, t1
    sc.cap ct2, (ca0)

    # Store the nonce
    CIncOffsetImm ct2, ca0, CAP_LEN
    sw.cap t0, (ct2)

    # Load sensor enc seal
    CIncOffsetImm ct2, ct1, DATA_OFFSET_SENSOR_ENC
    lc.cap ct2, (ct2)

    # Seal the argument with the enc seal
    CSeal ca0, ca0, ct2

    # Load sensor entry capabilities from ct1
    CIncOffsetImm ct2, ct1, DATA_OFFSET_SENSOR_CODE
    lc.cap ct2, (ct2)
    CIncOffsetImm ct3, ct1, DATA_OFFSET_SENSOR_DATA
    lc.cap ct3, (ct3)

    # Load sensor.read entry index
    li a7, 1

    # Load return address
    la ra, 1f

    # Invoke sensor
    j enclave_invoke

1:
    # Unseal sensor result with its sign seal
    CIncOffsetImm ct2, ct1, DATA_OFFSET_SENSOR_SIGN
    lc.cap ct2, (ct2)
    CUnseal ct2, ca0, ct2

    # Load the encrypted cap and decrypt
    lc.cap ct2, (ct2)
    CUnseal ct2, ct2, ct0

    # Pop original ca0 (our arguments) from the stack
    lc.cap ca0, (csp)
    CIncOffsetImm csp, csp, CAP_LEN

    # Compare original nonce from the one returned from sensor
    CIncOffsetImm ct3, ct2, CAP_LEN
    lw.cap t0, (ca0)
    lw.cap t1, (ct3)
    bne t0, t1, use_sensor_fail

    # Load result from sensor
    CIncOffsetImm ct2, ct2, CAP_LEN + __riscv_xlen
    lw.cap t0, (ct2)

    # "Process" result by doubling it
    add t0, t0, t0

    # Store result to output buffer
    CIncOffsetImm ct2, ca0, 4
    sw.cap t0, (ct2)

    # Seal result with our signing seal (full seal in ct0, offset=1 is sign)
    CIncOffsetImm ct2, ct0, 1
    CSeal ca0, ca0, ct2

    j enclave_exit

use_sensor_fail:
    CMove ca0, c0
    j enclave_exit

    .section .enclave.sensor.id, "ax", @progbits
sensor_id_start:
    .fill 32, 1, 0
sensor_id_end:
