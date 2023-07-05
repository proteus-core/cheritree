    #include "cheri.h"
    #include "trusted_traps.h"

    // FIXME move to a better place
    #define WORD_SIZE 4

    # TODO This is not trap-safe as all registers will be leaked! We might be
    # able to solve this by creating a trap handler inside enclaves.

    # The data section of enclaves will be initialized as follows:
    # [seal, trap_data, code_cap, data_cap, csp,
    #  enclave_data (ENCLAVE_DATA_SIZE), stack]
    #define DATA_OFFSET_SEAL     (0 * CAP_LEN)
    #define DATA_OFFSET_CODE_CAP (1 * CAP_LEN + TRAP_DATA_LEN)
    #define DATA_OFFSET_DATA_CAP (2 * CAP_LEN + TRAP_DATA_LEN)
    #define DATA_OFFSET_CSP      (3 * CAP_LEN + TRAP_DATA_LEN)
    #define DATA_OFFSET_ENCLAVE  (4 * CAP_LEN + TRAP_DATA_LEN)

    # The seal is stored by EInitData, code_cap/data_cap are passed in ca0/ca1
    # when invoking init and stored by software.
    # code_cap/data_cap are sealed capabilities for this enclave and can be used
    # to pass as a return callback when calling other enclaves.
    # Enclave code has access to its seal in ct0 and its data section in ct1
    # (ct1 points to enclave_data).

    # Load full enc/sign seal in ct0
    lc.cap ct0, (c31)

    # Dispatch entry point based on a7: 0=init, -1=return, other=entries
    beqz a7, enclave_init

    # Load stack pointer
    li t0, DATA_OFFSET_CSP
    CSetOffset ct1, c31, t0
    lc.cap csp, (ct1)

    # Check if csp has a valid tag. If not, init has not been called yet (or
    # failed).
    CGetTag t0, csp
    beqz t0, enclave_exit

    # Make data section after seal available in ct1
    li t0, DATA_OFFSET_ENCLAVE
    CSetOffset ct1, c31, t0

    li t0, -1
    beq a7, t0, enclave_return_entry

    # Enclaves should define their entry points as an array of function pointers
    # at enclave_entries_start.
    la t0, enclave_entries_start
    la t1, enclave_entries_end

    # Transform 1-based pointer index in a7 to a 0-based byte offset.
    addi t2, a7, -1
    slli t2, t2, 2

    # Calculate address of entry pointer. This address is relative to PCC.
    add t2, t0, t2
    bge t2, t1, enclave_exit

    # Create capability to entry pointer and load it.
    CSpecialR ct2, pcc
    CSetOffset ct3, ct2, t2
    lw.cap t3, (ct3)

    # The entry pointer is an offset from the start of the code section. This
    # means we can directly jump to it as jumps are relative to PCC.
    jr t3

enclave_init:
    # Check if data section is large enough to hold at least 4 capabilities and
    # the requested ENCLAVE_DATA_SIZE
    CGetLen t0, c31 # Data section size
    li t1, 4 * CAP_LEN + ENCLAVE_DATA_SIZE
    blt t0, t1, enclave_exit

    # Store code_cap/data_cap (available in ca0/ca1) in our data section
    li t2, DATA_OFFSET_CODE_CAP
    CSetOffset ct1, c31, t2
    sc.cap ca0, (ct1)
    li t2, DATA_OFFSET_DATA_CAP
    CSetOffset ct1, c31, t2
    sc.cap ca1, (ct1)

    # Create stack
    sub t2, t0, t1 # Stack size = data section length - static data length
    CSetOffset csp, c31, t1 # Stack bottom after static data
    CSetBoundsExact csp, csp, t2
    CSetOffset csp, csp, t2 # Offset to top of stack

    # Store stack pointer
    li t2, DATA_OFFSET_CSP
    CSetOffset ct1, c31, t2
    sc.cap csp, (ct1)

    # Create public enc seal in ca0: seal=base seal, perms=only seal
    CSetBoundsImm ca0, ct0, 1
    li t0, (1 << PERM_PERMIT_SEAL)
    CAndPerm ca0, ca0, t0

    # Create public sign seal in ca1: seal=base seal+1, perms=only unseal
    CIncOffsetImm ca1, ct0, 1
    CSetBoundsImm ca1, ca1, 1
    li t0, (1 << PERM_PERMIT_UNSEAL)
    CAndPerm ca1, ca1, t0

enclave_exit:
    # Clear full enc/sign seal
    CClearTag ct0, ct0

    # Clear data capabilities
    CClearTag ct1, ct1
    CClearTag c31, c31

    # TODO All registers should be cleared! We probably want to implement CClear

    # Code capability will be cleared by return jump
    CJALR cra

    # Invoke another enclave. Put arguments in caX, return address (offset
    # in our code section) in ra, target code/data capabilities in ct2/ct3, and
    # target entry point index in a7 before jumping here.
    #
    # When invoking another enclave, we put our own code/data capabilities in
    # cra/cs0. When the callee wants to return, it can invoke those capabilities
    # passing return values in caX as usual and setting a7=-1.
enclave_invoke:
    # Push cra on the stack
    CIncOffsetImm csp, csp, -CAP_LEN
    sc.cap cra, (csp)

    # Store return capability based on ra on the stack
    CSpecialR ct1, pcc
    CSetOffset ct1, ct1, ra
    CIncOffsetImm csp, csp, -CAP_LEN
    sc.cap ct1, (csp)

    # Store csp
    CIncOffsetImm ct1, c31, DATA_OFFSET_CSP
    sc.cap csp, (ct1)

    # Load our code/data capabilities
    li t0, DATA_OFFSET_CODE_CAP
    CSetOffset ct1, c31, t0
    lc.cap cra, (ct1)
    li t0, DATA_OFFSET_DATA_CAP
    CSetOffset ct1, c31, t0
    lc.cap cs0, (ct1)

    # TODO Clear regs.

    # Invoke callee
    CInvoke ct2, ct3

enclave_return_entry:
    # Load return capability from the stack
    lc.cap ct2, (csp)
    CIncOffsetImm csp, csp, CAP_LEN

    # Load old cra from the stack
    lc.cap cra, (csp)
    CIncOffsetImm csp, csp, CAP_LEN

    # Store csp (this should probably be done when exiting)
    li t0, DATA_OFFSET_CSP
    CSetOffset ct3, c31, t0
    sc.cap csp, (ct3)

    CJALR c0, ct2

enclave_return:
    li a7, -1
    CInvoke cra, cs0
