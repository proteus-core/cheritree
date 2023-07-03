/*
 ============================================================================
 Name        : user_enclave.S
 Description : Adapted to work on Morello by CAP-TEE 2021
 ============================================================================
 */

 //------------------------------------------------
 //register mapping
 //Note: proteus cheri-RISCV has seperate integer and capability register files
 //Morello has a single register file so need to ensure values are not overwritten when converting code
 //Inputs: (see RiscvToArm.md)
 //ca0 (riscv) -> c0 (Morello) -> code_cap FUNCTION ARGUMENT
 //ca1 (riscv) -> c1 (Morello) -> data_cap FUNCTION ARGUMENT
 //a7 (riscv) -> x7 (Morello) -> what program does FUNCTION ARGUMENT
 //c31 (ct6, but not used as temp reg) (riscv) -> c29 (Morello) -> C31(riscv)/c29(Morello) is set equal to capability register cs2 (data capability) and unsealed during CInvoke/BRS
 //Saved registers:
 // cs0 (riscv) -> c19 (Morello) ->
 //Other registers:
 //ct0 (riscv) -> c9 (Morello) -> first cap in data section (seal)
 //ct1 (riscv) -> c10 (Morello) -> enclave data (after the 4 capabilities)
 //ct2 (riscv) -> c11 (Morello) -> copy of program counter cap
 //ct3 (riscv) -> c12 (Morello) -> capability to entry pointer
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
 #include "cheri_extra.h" //CAP_LEN

 //Notes:
 //@progbits - means section Section contains either initialized data and instructions or instructions only.

    //comment this out if force in regForEL1N.S
    .section .enclave.user.text, "ax", @progbits
	.align 4

   // # 4 capabilities for the struct enclave of sensor
   // # 1 capability for the buffer to send a nonce to sensor
   // # 32 bytes for SHA256 id
    #define ENCLAVE_DATA_SIZE       (5 * CAP_LEN + 32)
    #define DATA_OFFSET_SENSOR_CODE (0 * CAP_LEN)
    #define DATA_OFFSET_SENSOR_DATA (1 * CAP_LEN)
    #define DATA_OFFSET_SENSOR_ENC  (2 * CAP_LEN)
    #define DATA_OFFSET_SENSOR_SIGN (3 * CAP_LEN)
    #define DATA_OFFSET_ARGS        (4 * CAP_LEN)
    #define DATA_OFFSET_BUF         (6 * CAP_LEN)

// user_code_start: label added by CAP-TEE
// .word set_sensor_enclave - user_code_start can't be pre-computed in LLVM Morello
// it needs to have an address before the linker stage
// user_code_start commented out in linker script
.global user_code_start //added by CAP-TEE
//removes warning: could not determine size of cap reloc
.size user_code_start, 4 //added by CAP-TEE
user_code_start: //added by CAP-TEE

    #include "enclave_entry.S"

//enclave_entries_start address
enclave_entries_start:
	// array of function pointers relative to start of section (file)
    .word set_sensor_enclave - user_code_start //this points to set_sensor_enclave as a relative address from start
    .word use_sensor - user_code_start //this points to use_sensor as a relative address from start
enclave_entries_end:

set_sensor_enclave:
    //# ca0 (c0) contains a pointer to a sensor struct enclave
    //which was set up in enclave_invoke c code
    //The struct is as follows:
    //	code cap
    //	data_cap
    //	enc seal
    //	sign seal
    //# We store the entry capabilities and seals at the beginning of our data
    //# section. ct1(c10) points here. The space after that is used as a buffer
    //# for EStoreId.
    //# To verify the enc seal, we pass its base to EStoreId
    //# TODO check perm

    //-------------------------------------------------
    // Get the enc_seal from the sensor struct
    //-------------------------------------------------
    //CIncOffsetImm ct2, ca0, 2 * CAP_LEN//(riscv)
    //lc.cap ct2, (ct2) # ct2 = enclave->enc_seal//(riscv)
    BX#4 //flip state back to c64
    LDR  c11, [c0,#2 * CAP_LEN] //load enc_seal capability from struct//(Morello)


    //-------------------------------------------------
    // Branch to fail if not a valid enc_seal capability from sensor struct
    //-------------------------------------------------
    //CGetTag t0, ct2//(riscv)
    //beqz t0, set_sensor_enclave_fail//(riscv)
    GCTAG x13, c11 //get tag//(Morello)
    CMP x13, XZR //(compare x13 to zero)//(Morello)
    B.EQ set_sensor_enclave_fail //(branch if x13=0)//(Morello)

    //-------------------------------------------------
    // else get base addr of enc_seal from sensor struct
    // this is the otype to go into the ESTORE_ID instruction
    //-------------------------------------------------
    //CGetBase t0, ct2//(riscv)
    GCBASE x13, c11 // get base addr of enc_seal//(Morello)

    //-------------------------------------------------
	//# Create pointer to the buffer for EStoreId in user enclave data section
	//-------------------------------------------------
    //CIncOffsetImm ct3, ct1, DATA_OFFSET_BUF//(riscv)
    //CSetBoundsImm ct3, ct3, 32 # length=256 bits//(riscv)
    //inc offset
    GCOFF x14, c10 //(get current offset of pointer to data)//(Morello)
    ADD x14, x14, #DATA_OFFSET_BUF //(add offset)//(Morello)
    SCOFF c12, c10, x14 //(set offset)//(Morello)
    //set bounds
    MOV X14, #32 //(Immediate to reg first) 32 # length=256 bits //(Morello)
    SCBNDSE c12, c12, x14 //(no immediate, reg only)//(Morello)

    //-------------------------------------------------
    //make ID
    //-------------------------------------------------
    //EStoreId t1, t0, ct3//(riscv)
	//-------------------------------------
	//NEW ESTORE_ID INSTRUCTION TO GO HERE
	//-------------------------------------
    //Inputs:
    //x0 otype
    //c1 memhashcap
    //save c0

    STP c0, c1, [csp, #-32]! //save the pointer to the struct enclave, remember to clear after
    MOV x0, x13 //get the otype
    MOV c1, c12 //copy hashcap to c1, keep in c12 for later
	HVC #HVC_ESTOREID
    //output: x0 boolean success/failure
	MOV x14, x0
    LDP c0, c1, [csp], #32 //restore the pointer to the  struct enclave, remember to clear after


    //-------------------------------------------------
    //if returned ID is zero, then branch to fail
    //-------------------------------------------------
    //beqz t1, set_sensor_enclave_fail//(riscv)
    CMP x14, XZR //(compare x1 to zero) //(Morello)
    B.EQ set_sensor_enclave_fail //(branch if x1=0)//(Morello)

    //-------------------------------------------------
	//# Else Check ID against expected one
	//-------------------------------------------------
    //# First create a pointer to the expected id based on PCC
    //CSpecialR ct4, pcc//(riscv)
    //la t1, sensor_id_start//(riscv)
    //CSetOffset ct4, ct4, t1//(riscv)
    //la t2, sensor_id_end//(riscv)
    //ADR c4, #0 //(get PCC)
    //set offset of c4 to point to sensor_id_start
    //bounds of c4 are same as PCC, so sensor_id_start must be in range

    ADR c4, sensor_id_start //(get PCC)
    ADR c15, sensor_id_end //(Morello) actual sensor_ID end addr
	GCOFF x15, c15 //get the offset
1:
    //lw.cap t3, (ct3) # Word of actual id//(riscv)
    //lw.cap t4, (ct4) # Word of expected id//(riscv)
    //Pointer to actual id ct3 (c12), value t3 (x6)
    //Pointer to expected id ct4 (c4)calc above, value t4 (x3)
    LDR w6, [c12,#0]//actual ID (Morello)
    LDR w3, [c4,#0]//expected ID (Morello)

    //-------------------------------------------------
    //branch to fail if ID not the same
    //-------------------------------------------------
    //bne t3, t4, set_sensor_enclave_fail//(riscv)
    CMP w6, w3 //(compare x6 to x3, or use SUBS XZR, x1, x2)
    B.NE set_sensor_enclave_fail //(branch if x6-x3!=0)

    //-------------------------------------------------
    // else increment actual and expected ID cap pointers by 4 (should get to sensor_id_end)
    //-------------------------------------------------
    //CIncOffsetImm ct3, ct3, 4//(riscv)
    //ct3(c12)actual ID cap
    GCOFF x14, c12 //(get current offset of pointer to data)//(Morello)
    ADD x14, x14, #4 //(add offset)//(Morello)
    SCOFF c12, c12, x14 //(set offset)//(Morello)
    //CIncOffsetImm ct4, ct4, 4//(riscv)
    //ct4(c4)expected ID cap
    GCOFF x14, c4 //(get current offset of pointer to data)//(Morello)
    ADD x14, x14, #4 //(add offset)//(Morello)
    SCOFF c4, c4, x14 //(set offset)//(Morello)

    //-------------------------------------------------
    // branch back to 1 label if t3(x6)actual ID +4 POS less than t2(x15) expected ID +4 POS
    //-------------------------------------------------
    //CGetOffset t3, ct4//(riscv)
    //get expected ID offset (expected sensor_ID end addr)
    GCOFF x6, c4//(Morello)
    //blt t3, t2, 1b//(riscv)
    //t2(x15) is sensor_id_end (actual sensor_ID end addr)
    //branch if t3(x6)actual < t2(x15)expected
    CMP x6, x15 //(compare x6 to x15)//(Morello)
    B.MI 1b //(branch if x6-x15=-ve )//(Morello)

    //-------------------------------------------------
    //# To verify the sign seal, we check if its base is one larger than the one
    //# of the enc seal
    //-------------------------------------------------
    //# TODO check perm
    //CIncOffsetImm ct3, ca0, 3 * CAP_LEN//(riscv)
    //lc.cap ct3, (ct3) # ct3 = enclave->sign_seal//(riscv)
    //CGetBase t1, ct3//(riscv)
    //addi t1, t1, -1//(riscv)
    //ct3(c12)actual ID cap, ca0(c0)pointer to struct
    GCOFF x14, c0 //(get current offset of pointer ID cap)//(Morello)
    ADD x14, x14, #3 * CAP_LEN //(add offset)//(Morello)
    SCOFF c12, c0, x14 //(set offset)//(Morello)
    LDR c12, [c12,#0]//enclave->sign_seal (Morello)
    GCBASE x14, c12 // get base addr of sign_seal//(Morello)
    ADD x14, x14, #-1//(Morello)
    //-------------------------------------------------
    // branch to fail if not equal
    //-------------------------------------------------
    //bne t0, t1, set_sensor_enclave_fail//(riscv)
    //t0(x13)base addr of enc_seal from struct, t1(x14)sign_seal base addr-1
    CMP x13, x14 //(compare x13 to x14, or use SUBS XZR, x1, x2) //(Morello)
    B.NE set_sensor_enclave_fail //(branch if x1-x2!=0)//(Morello)

    //-------------------------------------------------
    // copy the entry capabilities and seals from the struct to the enclave data
    //-------------------------------------------------
    //# enc_seal/sign_seal struct are already in ct2/ct3 (c11/c12)
    //# ca0(c0) = struct enclave, ct1(c10) = base of data section (after our seal)
    //CIncOffsetImm ct5, ct1, DATA_OFFSET_SENSOR_CODE//(riscv)
    //lc.cap ct4, (ca0)//(riscv)
    //sc.cap ct4, (ct5) # enclave->code_cap//(riscv)
    //CIncOffsetImm ca0, ca0, CAP_LEN//(riscv)
    //CIncOffsetImm ct5, ct1, DATA_OFFSET_SENSOR_DATA//(riscv)
    //lc.cap ct4, (ca0)//(riscv)
    //sc.cap ct4, (ct5) # enclave->data_cap//(riscv)
    //CIncOffsetImm ct5, ct1, DATA_OFFSET_SENSOR_ENC//(riscv)
    //sc.cap ct2, (ct5) # enclave->enc_seal//(riscv)
    //CIncOffsetImm ct5, ct1, DATA_OFFSET_SENSOR_SIGN//(riscv)
    //sc.cap ct3, (ct5) # enclave->sign_seal//(riscv)
	//copy SENSOR_CODE
	LDR c4, [c0,#0]//load struct:enclave->code_cap (Morello)
    STR c4, [c10,#DATA_OFFSET_SENSOR_CODE]//save to DATA: DATA_OFFSET_SENSOR_CODE (Morello)
	//copy SENSOR_DATA
	LDR c4, [c0,#CAP_LEN]//load struct:enclave->data_cap (Morello)
    STR c4, [c10,#DATA_OFFSET_SENSOR_DATA]//save to DATA: DATA_OFFSET_SENSOR_CODE (Morello)
	//copy SENSOR_ENC
    STR c11, [c10,#DATA_OFFSET_SENSOR_ENC]//save to DATA: DATA_OFFSET_SENSOR_CODE (Morello)
	//copy SENSOR_SIGN
    STR c12, [c10,#DATA_OFFSET_SENSOR_SIGN]//save to DATA: DATA_OFFSET_SENSOR_CODE (Morello)


    //-------------------------------------------------
    // BENCHMARK t9 return to el1 function
    // enable and then reset counter clk cycles here before return
    //-------------------------------------------------
    #if defined(BENCHMARK2)
        //enable counter
		MRS x13, PMCNTENSET_EL0
		// bit[0]  enable
		//"ORR  x13, x13, #(1 << 0)\n\t"
		ORR  x13, x13, #(1 << 31)
		// set register value and enable
		//"MSR  PMCR_EL0, x13\n\t"
		MSR  PMCNTENSET_EL0, x13
		ISB
		MRS x13, PMCR_EL0
		// bit[2] reset
		ORR  x13, x13, #(1 << 2)
		MSR  PMCR_EL0, x13
		ISB
		// remove reset
		// create mask 1111 1111 1111 1011
		MOV x14, #0xFFFF
		MOVK x14, #0xFFFB,LSL #16
		// and mask with contents of register to remove bit[2]
		AND x13, x13, x14 // disable
		MSR PMCR_EL0, x13 // write
		ISB
	#endif



    //j enclave_exit//(riscv)
	B enclave_exit //no return (Morello)

//-----------------------------------------------------------------
// set_sensor_enclave_fail:
//-----------------------------------------------------------------
set_sensor_enclave_fail:
    //CClearTag ca0, ca0//(riscv)
    //j enclave_exit//(riscv)
    //clear the tag bit of the sensor structure
    CLRTAG c0, c0//(Morello)
    B enclave_exit //no return (Morello)

//-----------------------------------------------------------------
// use_sensor:
//-----------------------------------------------------------------
use_sensor:

    //-------------------------------------------------
    // BENCHMARK t8 entry to enclave function
    // stop counting clk cycles here on function entry
    //-------------------------------------------------
    #if defined(BENCHMARK2)
    //get current register value
	MRS x13, PMCNTENCLR_EL0
    // bit[31]  disable
	ORR  x13, x13, #(1 << 31)
	//set register
	MSR  PMCNTENCLR_EL0, x13
	ISB
	#endif

   //-------------------------------------------------
   //# ca0 (c0) contains a capability to [nonce, space for result]
   //-------------------------------------------------
   // # Load nonce
   // lw.cap t0, (ca0) //(riscv)
   BX #4 //change PSTATE if a64 go to c64 as changes on a function branch
   LDR w13, [c0,#0]//load nonce (Morello)

   //-------------------------------------------------
   // # Store capability to [nonce, space for result] ca0 (c0) on the stack
   //-------------------------------------------------
   // CIncOffsetImm csp, csp, -CAP_LEN//(riscv)
   // sc.cap ca0, (csp)//(riscv)
   SUB csp, csp, #CAP_LEN//(Morello)
   STR c0, [csp]//(Morello)


   //-------------------------------------------------
   //# Create new ca0(c0) capability to argument buffer in enclave data [our enc seal, nonce, result]
   //-------------------------------------------------
   //CIncOffsetImm ca0, ct1, DATA_OFFSET_ARGS//(riscv)
   //CSetBoundsImm ca0, ca0, CAP_LEN + 2 * __riscv_xlen//(riscv)
   GCOFF x0, c10 //(get current offset of pointer ID cap)//(Morello)
   ADD x0, x0, #DATA_OFFSET_ARGS //(add offset)//(Morello)
   SCOFF c0, c10, x0 //(set offset)//(Morello)
   //__riscv_xlen is a defined macro for riscv in the compiler and is either 64, for 64 bit, or 32 for 32 bit
   //changed __riscv_xlen to __morello_xlen, which is 64bit needs to be in bytes though (8)
   MOV x14, #CAP_LEN + 2 * __morello_xlen //(Immediate to reg first) // (Morello)
   SCBNDSE c0, c0, x14 //(no immediate, reg only)// (Morello)

   //-------------------------------------------------
   //# Create and store our public enc seal in ca0(c0), offset #0
   //enc seal with SEAL permissions
   //-------------------------------------------------
   //CSetBoundsImm ct2, ct0, 1//(riscv)
   //li t1, (1 << PERM_PERMIT_SEAL)//(riscv)
   //CAndPerm ct2, ct2, t1//(riscv)
   //sc.cap ct2, (ca0)//(riscv)
   //set bounds
   MOV X14, #1 //(Immediate to reg first) //(Morello)
   SCBNDSE c11, c9, x14 //(no immediate, reg only)//(Morello)
   // we need to remove all permissions except seal so need to invert
   ORN x14, xzr, #(0x1 << PERM_PERMIT_SEAL)//(Morello)
   CLRPERM c11, c11, x14 //(reduce permissions)//(Morello)
   STR c11, [c0]//save to DATA: args [enc_seal (Morello)

   //-------------------------------------------------
   //# Store the nonce t0 (w13) in ca0(c0), offset #CAP_LEN
   //-------------------------------------------------
   //CIncOffsetImm ct2, ca0, CAP_LEN
   //sw.cap t0, (ct2)//(riscv)
   STR w13, [c0,#CAP_LEN]//save to DATA: args [enc_seal nonce (Morello)

   //-------------------------------------------------
   // # Load sensor enc seal from ct1 (c10), offset #DATA_OFFSET_SENSOR_ENC into ct2(c11)
   //-------------------------------------------------
   //CIncOffsetImm ct2, ct1, DATA_OFFSET_SENSOR_ENC//(riscv)
   //lc.cap ct2, (ct2)//(riscv)
   LDR c11, [c10,#DATA_OFFSET_SENSOR_ENC]//load DATA_OFFSET_SENSOR_ENC (Morello)

   //-------------------------------------------------
   //# Seal the pointer to args ca0 (c0), with the sensor enc_seal ct2 (c11)
   //-------------------------------------------------
   //CSeal ca0, ca0, ct2//(riscv)
   CSEAL c0, c0, c11 // (Morello)

   //-------------------------------------------------
   //# Load sensor entry capabilities from ct1 (c10) enclave data
   // to ct2 (c11) sensor code, and ct3 (c12) sensor data
   //-------------------------------------------------
   //CIncOffsetImm ct2, ct1, DATA_OFFSET_SENSOR_CODE//(riscv)
   //lc.cap ct2, (ct2)//(riscv)
   //CIncOffsetImm ct3, ct1, DATA_OFFSET_SENSOR_DATA//(riscv)
   //lc.cap ct3, (ct3)//(riscv)
   LDR c11, [c10,#DATA_OFFSET_SENSOR_CODE]//load DATA_OFFSET_SENSOR_CODE (Morello)
   LDR c12, [c10,#DATA_OFFSET_SENSOR_DATA]//load DATA_OFFSET_SENSOR_DATA (Morello)

   //-------------------------------------------------
   // set up enclave invoke (in enclave_entry for user) to go to sensor enclave read
   //-------------------------------------------------
   //# Load sensor.read entry index
   // this directs to first function pointer in sensor_enclave.S which is read
   //li a7, 1//(riscv)
   MOV x7, #1

   //ADDED NOW - SAVE CURRENT RETURN ADDRESS
   SUB csp, csp, #CAP_LEN//(Morello)
   STR c30, [csp]//(Morello)

   //# Load return address ra (x30) with branch label 1 forward (1:)
   //TO RETURN TO AFTER ENCLAVE INVOKE
   //la ra, 1f//(riscv)
   //LDR x30, =backu
   ADR c30, backu //needs to be a capability

   //# Invoke sensor
   //j enclave_invoke//(riscv)
   B enclave_invoke // go to enclave_invoke in enclave_entry for user enclave

backu:
   //-------------------------------------------------
   // Unseal sensor result ca0 (c0) with its sign seal DATA_OFFSET_SENSOR_SIGN
   // return arg is ca0, ct1 (c10) is pointer to enclave data
   // ct2 (c11) is loaded with DATA_OFFSET_SENSOR_SIGN
   //-------------------------------------------------
   //CIncOffsetImm ct2, ct1, DATA_OFFSET_SENSOR_SIGN //(riscv)
   //lc.cap ct2, (ct2) //(riscv)
   //CUnseal ct2, ca0, ct2 //(riscv)
   BX#4 // flips to a64, so change back to c64 mode

   //RESTORE RETURN ADDRESS
   LDR c30, [csp]//(Morello)
   ADD csp, csp, #CAP_LEN//(Morello)

   LDR c11, [c10,#DATA_OFFSET_SENSOR_SIGN]//load DATA_OFFSET_SENSOR_SIGN (Morello)
   UNSEAL c11, c0, c11 //unseal result c0 with sensor_sign c11

   //-------------------------------------------------
   //# Load the encrypted cap and decrypt
   //-------------------------------------------------
   //lc.cap ct2, (ct2) //(riscv)
   //CUnseal ct2, ct2, ct0 //(riscv)
   LDR c11, [c11]// (Morello)
   UNSEAL c11, c11, c9 //unseal sensor sign c11 with user seal c9 at start of data section

   //-------------------------------------------------
   // # load original capability to [nonce, space for result] ca0 (c0) from the stack
   //-------------------------------------------------
   //# Pop original ca0 (our arguments) from the stack
   //lc.cap ca0, (csp) //(riscv)
   //CIncOffsetImm csp, csp, CAP_LEN //(riscv)
   LDR c0, [csp]//(Morello)
   ADD csp, csp, #CAP_LEN//(Morello)

   //------------------------------------------------
   // CAP-TEE Moved here from enclave_return_entry
   // because stack saved
   //before finished being restored
   //------------------------------------------------
 	// # Store csp (this should probably be done when exiting)
 	//CIncOffsetImm ct3, c31, DATA_OFFSET_CSP //(riscv)
    //sc.cap csp, (ct3) //(riscv)
    MOV c12, csp // can't save csp directly//(Morello)
    STR c12, [c29,#DATA_OFFSET_CSP]//(Morello)


   //-------------------------------------------------
   //# Compare original nonce ca0(c0) with the one returned from sensor result ct2(c11)
   // branch to fail if not equal
   //-------------------------------------------------
   //ca0(c0) - original nonce
   //ct2(c11) - unsealed decrypted nonce cap from sensor result
   //CIncOffsetImm ct3, ct2, CAP_LEN //(riscv)
   //lw.cap t0, (ca0) //(riscv)
   //lw.cap t1, (ct3) //(riscv)
   //bne t0, t1, use_sensor_fail //(riscv)
   LDR w13, [c0]//original nonce (Morello)
   LDR w14, [c11,#CAP_LEN]//unsealed decrypted nonce cap from sensor result (Morello)
   //branch to fail if two not equal
   CMP x13, x14 //(compare x13 to x14, or use SUBS XZR, x13, x14)
   B.NE use_sensor_fail //(branch if x13-x14!=0)

   //-------------------------------------------------
   // Load and process result
   //-------------------------------------------------
   //# Load result returned from sensor result ct2(c11)
   //CIncOffsetImm ct2, ct2, CAP_LEN + __riscv_xlen //(riscv)
   //lw.cap t0, (ct2) //(riscv)
   //__riscv_xlen is a defined macro for riscv in the compiler and is either 64, for 64 bit, or 32 for 32 bit
   //changed __riscv_xlen to __morello_xlen, which is 64bit
   LDR w13, [c11,#(CAP_LEN + __morello_xlen)]//load result (Morello)

   //# "Process" result by doubling it
   //add t0, t0, t0 //(riscv)
   ADD w13, w13, w13

   //# Store result t0 (w13) to buffer in enclave data
   //CIncOffsetImm ct2, ca0, 4 //why is this 4 and not a defined offset???????????
   //sw.cap t0, (ct2)
   STR w13, [c0,#4]//store result to buffer (Morello) ca0

   //-------------------------------------------------
   // seal result with sign seal
   //-------------------------------------------------
   //# Seal result with our signing seal (full seal in ct0, offset=1 is sign)
   //ct0 (c9) start data section
   //CIncOffsetImm ct2, ct0, 1 //(riscv)
   //CSeal ca0, ca0, ct2 //(riscv)
   GCOFF x14, c9 //(get current offset)//(Morello)
   ADD x14, x14, #1 //(add offset)//(Morello)
   SCOFF c11, c9, x14 //(set offset)//(Morello)

   //we need to seal ca0 (c0))
   CSEAL c0, c0, c11

   //j enclave_exit
   B enclave_exit //no return. enclave_exit in enclave_entry.S//(Morello)


use_sensor_fail:
   //CMove ca0, c0 //c0 is zero register //(riscv)
   //j enclave_exit //(riscv)
   MOV x0, xzr // clear return arg c0
   B enclave_exit //no return. enclave_exit in enclave_entry.S//(Morello)

   .section .enclave.sensor.id, "ax", @progbits
sensor_id_start:
   .fill 32, 1, 0
sensor_id_end:

//WARNING - THIS CAUSES 1ST INVOKE TO FAIL
//.global user_code_end //added by CAP-TEE
//removes warning: could not determine size of cap reloc when use sensor_code_end as address label
// if use label in linker, gives cap reloc issue, unless remove .align(16) in linker
//.size user_code_end, 4 //added by CAP-TEE
//.align 4 //2^4 = 16
//user_code_end: //added by CAP-TEE
