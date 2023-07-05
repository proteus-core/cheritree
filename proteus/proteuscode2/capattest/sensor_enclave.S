    .section .enclave.sensor.text, "ax", @progbits

    #define ENCLAVE_DATA_SIZE CAP_LEN
    #define DATA_OFFSET_RETURN_VAL (0 * CAP_LEN)
    #include "enclave_entry.S"


enclave_entries_start:
    .word read - sensor_code_start
enclave_entries_end:

read:
    # ca0 is a pointer to [enc seal, nonce, space for return value]
    # Unseal it first with our full seal in ct0 (offset=0 == enc)
    CUnseal ca0, ca0, ct0

    # Load the enc seal of the caller
    lc.cap ct2, (ca0)

    # Emulate useful work by looping for NB_ITERATIONS. The # of instructions executed is `2 * NB_ITERATIONS + 2`.
    li t1, NB_ITERATIONS + 1
sensor_loop:
    addi t1, t1, -1
   	bnez t1, sensor_loop

sensor_exit:
    # Store result, we keep the enc seal and the nonce in place
    li t1, 123 # value
    CIncOffsetImm ct3, ca0, CAP_LEN + __riscv_xlen
    sw.cap t1, (ct3)

    # Seal ca0 with the enc seal of the caller
    CSeal ct2, ca0, ct2

    # Store it in our data section
    CIncOffsetImm ct3, ct1, DATA_OFFSET_RETURN_VAL
    CSetBoundsImm ct3, ct3, CAP_LEN
    sc.cap ct2, (ct3)

    # Make cap to our data section read-only
    li t0, ~(1 << PERM_PERMIT_STORE)
    CAndPerm ct3, ct3, t0

    # Seal with our signing seal (offset=1 == sign)
    CIncOffsetImm ct2, ct0, 1
    CSeal ca0, ct3, ct2

    # We assume to be called by another enclave, otherwise this won't work.
    j enclave_return
