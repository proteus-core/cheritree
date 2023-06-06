/*
 ============================================================================
 Name        : sensor_enclave.S
 Description : Adapted to work on Morello by CAP-TEE 2021
 ============================================================================
 */

 //------------------------------------------------
 //register mapping
 //Note: proteus cheri-RISCV has seperate integer and capability register files
 //Morello has a single register file so need to ensure values are not overwritten when converting code
 //Inputs: (see RiscvToArm.md)
 //ca0 (riscv) -> c0 (Morello) -> FUNCTION ARGUMENT
 //ca1 (riscv) -> c1 (Morello) -> FUNCTION ARGUMENT
 //a7 (riscv) -> x7 (Morello) -> what program does FUNCTION ARGUMENT
 //c31 (ct6, but not used as temp reg) (riscv) -> c29 (Morello) -> C31(riscv)/c29(Morello) is set equal to capability register cs2 (data capability) and unsealed during CInvoke/BRS
 //Saved registers:
 // cs0 (riscv) -> c19 (Morello) ->
 //Other registers:
 //ct0 (riscv) -> c9 (Morello) -> first cap in data section (seal)
 //ct1 (riscv) -> c10 (Morello) ->
 //ct2 (riscv) -> c11 (Morello) ->
 //ct3 (riscv) -> c12 (Morello) ->
 //ct4 (riscv) -> c4 (Morello) ->
 //ct5 (riscv) -> c5 (Morello) ->
 //t0 (riscv) -> x13 (Morello) -> temp reg
 //t1 (riscv) -> x14 (Morello) -> temp reg
 //t2 (riscv) -> x15 (Morello) -> temp reg
 //t3 (riscv) -> x6 (Morello) -> temp reg
 //t4 (riscv) -> x3 (Morello) -> temp reg
 //cs0 (riscv) -> c19 (Morello) -> saved reg
//cra (riscv) ->c30 (Morello) -> return addr

 //#include "cheri.h"
 #include "cheri_extra.h" //CAP_LEN, __morello_xlen

.section .enclave.sensor.text, "ax", @progbits
.align 4                   // Align to 2^4 byte (16 byte) boundary added by CAP-TEE
#define ENCLAVE_DATA_SIZE CAP_LEN
#define DATA_OFFSET_RETURN_VAL (0 * CAP_LEN)

// sensor_code_start: label added by CAP-TEE
// .word read - sensor_code_start: can't be pre-computed in LLVM Morello
// it needs to have an address before the linker stage
// sensor_code_start: commented out in linker script
.global sensor_code_start //added by CAP-TEE
//.type sensor_code_start, %object
//removes warning: could not determine size of cap reloc
.size sensor_code_start, 4 //added by CAP-TEE
sensor_code_start: //added by CAP-TEE
//.size sensor_code_start, . - sensor_code_start

#include "enclave_entry.S"

enclave_entries_start:
  // sensor_code_start no longer defined in linker script
    .word read - sensor_code_start //this points to read as a relative address from start
enclave_entries_end:

read:
    //read is called by a CInvoke (BRS - Morello) from the user_enclave, ca0 and a7=1 (x7 - Morello) are passed as func args
    //ca0 (c0) is a pointer to [enc seal, nonce, space for return value] from the caller (user enclave)
    //ct0 (c9) points to seal at beg of sensor data section [seal, code_cap, data_cap, csp, enclave data, stack]
    //ct1 (c10) points to the sensor enclave data

    //-------------------------------------------------
    //# Unseal user ca0 (c0) first with our full seal in ct0 (c9) (offset=0 == enc)
    //-------------------------------------------------
    //CUnseal ca0, ca0, ct0//(riscv)
    BX #4 //ensure capability mode
    UNSEAL c0, c0, c9 //unseal user enc seal with sensor seal(Morello)

    //# Load the enc seal of the caller (user) into ct2 (c11)
    //lc.cap ct2, (ca0)//(riscv)
    //THIS SHOULD HAVE VALUE 8 AND PERMS OF 800
    LDR c11, [c0]//(Morello)

    //-------------------------------------------------
    // BENCHMARK testing
    // Adding processing to the enclave
    // Keep alignment with 8 instr. otherwise can't shrink heap cap
    // use the nonce to set the number of loops
    //-------------------------------------------------
    //use nonce to set the number of processing loops
    #if defined(BENCHMARK1) || defined(BENCHMARK2)
    LDR w14, [c0,#CAP_LEN]//(Morello)
    //7 instructions
    loopb:
    SUB x14, x14, #0x01
    CMP x14, xzr
    NOP
    NOP
    NOP
    NOP
    B.NE loopb
    #endif



    //-------------------------------------------------
    //# Store a result in user ca0, we keep the enc seal and the nonce in place
    //-------------------------------------------------
    //li t1, 123 # value
    //CIncOffsetImm ct3, ca0, CAP_LEN + __riscv_xlen//(riscv)
    //sw.cap t1, (ct3)
    MOV x14, #123
    //__riscv_xlen is a defined macro for riscv in the compiler and is either 64, for 64 bit, or 32 for 32 bit
    //changed __riscv_xlen to __morello_xlen, which is 64bit
    //STORES IN CORRECT BIT, BUT UPPER BYTES?
    STR x14, [c0,#(CAP_LEN + __morello_xlen)]//(Morello)

    //-------------------------------------------------
    //# Seal ca0 with the enc seal of the caller (user) into ct2 (c11)
    //-------------------------------------------------
    //CSeal ct2, ca0, ct2//(riscv)
    CSEAL c11, c0, c11

    //-------------------------------------------------
    //# Store ct2 (c11) it in our data section ct1 (c10), using ct3 (c12)
    //-------------------------------------------------
    //CIncOffsetImm ct3, ct1, DATA_OFFSET_RETURN_VAL//(riscv)
    //CSetBoundsImm ct3, ct3, CAP_LEN//(riscv)
    //sc.cap ct2, (ct3)//(riscv)
    GCOFF x14, c10 //(get current offset)//(Morello)
    ADD x14, x14, #DATA_OFFSET_RETURN_VAL //(add offset) //(Morello)
    SCOFF c12, c10, x14 //(set offset)(no immediate, reg only)//(Morello)
    MOV x14,#CAP_LEN // set bounds length//(Morello)
    SCBNDSE c12,c12,x14//(Morello)
    STR c11, [c12]//(Morello)

    //# Make cap to our data section read-only
    //li t0, ~(1 << PERM_PERMIT_STORE)//(riscv)
    //CAndPerm ct3, ct3, t0//(riscv)
    MOV x13, #(1 << PERM_PERMIT_STORE) //(Morello does a clear of the bit selected so doesn't need the invert)
    CLRPERM c12, c12, x13 //(reduce permissions and clear store)


    //# Seal ct3 (c12) and save in ca0 (c0) return argument with our signing seal in ct0 (c9) (offset=1 == sign)
    //CIncOffsetImm ct2, ct0, 1//(riscv)
    //CSeal ca0, ct3, ct2//(riscv)
    GCOFF x14, c9 //(get current offset)//(Morello)
    ADD x14, x14, #1 //(add offset) //(Morello)
    SCOFF c11, c9, x14 //(no immediate, reg only)//(Morello
    CSEAL c0, c12, c11 //return arg c0 (Morello

    //# We assume to be called by another enclave, otherwise this won't work.
    //j enclave_return//(riscv)
    B enclave_return // return a sealed pointer to return val of sensor enclave , enclave data.

//WARNING - THIS CAUSES 1ST INVOKE TO FAIL
//.global sensor_code_end //added by CAP-TEE
//removes warning: could not determine size of cap reloc when use sensor_code_end as address label
// if use label in linker, gives cap reloc issue, unless remove .align(16) in linker
//.size sensor_code_end, 4 //added by CAP-TEE
//.align 4
//sensor_code_end: //added by CAP-TEE
