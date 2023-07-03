/*
 ============================================================================
 Name        : enclave_entry.S
 Description : Adapted to work on Morello by CAP-TEE 2021
 ============================================================================
 */

 //ISSUES: FOR CLEAN BUILD DO THIS
 //		exclude this file from build
 //   - issue is compiler is compiling enclave_entry as separate file, when should only be including in user/sensor encalve file.
 //     ENCLAVE_DATA_SIZE has diff value depending if code in user_enclave or sensor_enclave, dosn't know what this is by self
 //   - need to ignore separate file in compile - solution: resource configuration - exclude from build
 //   - ../src/enclave_entry.S:217:5: error: invalid fixup for movz/movk instruction
 //------------------------------------------------
 //CAP-TEE notes
 //Note: proteus cheri-RISCV has seperate integer and capability register files
 //Morello has a single register file so need to ensure values are not overwritten when converting code
 //This file is pasted directly in to the start of both user_enclave.S, and sensor_enclave.S
 //Inputs: (see RiscvToArm.md)
 //ca0 (riscv) -> c0 (Morello) -> code_cap FUNCTION ARGUMENT
 //ca1 (riscv) -> c1 (Morello) -> data_cap FUNCTION ARGUMENT
 //a7 (riscv) -> x7 (Morello) -> what program does FUNCTION ARGUMENT
 //c31 (ct6, but not used as temp reg) (riscv) -> c29 (Morello) -> C31(riscv)/c29(Morello) is set equal to capability register cs2 (data capability) and unsealed during CInvoke/BRS
 //Other registers:
 //ct0 (riscv) -> c9 (Morello) -> first cap in data section (seal)
 //ct1 (riscv) -> c10 (Morello) -> enclave data (after the 4 capabilities)
 //ct2 (riscv) -> c11 (Morello) -> copy of program counter cap
 //ct3 (riscv) -> c12 (Morello) -> capability to entry pointer
 //t0 (riscv) -> x13 (Morello) -> temp reg
 //t1 (riscv) -> x14 (Morello) -> temp reg
 //t2 (riscv) -> x15 (Morello) -> temp reg
 //t3 (riscv) -> x6 (Morello) -> temp reg
 //cs0 (riscv) -> c19 (Morello) -> saved reg
//cra (riscv) ->c30 (Morello) -> return addr
 //During CInvoke (riscv) CInvoke cs1, cs2. PCC is set equal to capability register cs1
 //and unsealed with the 0th bit of its address set to 0,
 //whilst C31 is set equal to capability register cs2 and unsealed. This provides a
 //constrained form of non-monotonicity, allowing for fast jumps between protection
 //domains, with cs1 providing the target domain’s code and cs2 providing the target
 // domain’s data. The capabilities must have a matching otype to ensure the right
 //data is provided for the given jump target.

 	//#include "cheri.h" //removed by CAP-TEE
 	#include "cheri_extra.h" //CAP_LEN - added by CAP-TEE

   	// # TODO This is not trap-safe as all registers will be leaked! We might be
   	// # able to solve this by creating a trap handler inside enclaves.

   	// # The data section of enclaves will be initialized as follows:
   	// # [seal, code_cap, data_cap, csp, enclave_data (ENCLAVE_DATA_SIZE), stack]
    #define DATA_OFFSET_SEAL     (0 * CAP_LEN)
    #define DATA_OFFSET_CODE_CAP (1 * CAP_LEN)
    #define DATA_OFFSET_DATA_CAP (2 * CAP_LEN)
    #define DATA_OFFSET_CSP      (3 * CAP_LEN)
    #define DATA_OFFSET_ENCLAVE  (4 * CAP_LEN)

   	// # The seal is stored by EInitData, code_cap/data_cap are passed in ca0/ca1
   	// # when invoking init and stored by software.
   	// # code_cap/data_cap are sealed capabilities for this enclave and can be used
   	// # to pass as a return callback when calling other enclaves.
   	// # Enclave code has access to its seal in ct0 and its data section in ct1
   	// # (ct1 points to enclave_data).

   	// # Load full enc/sign seal in ct0 (c9) from first capability at top of data section
   	//WHERE IS C31 SET? - CInvoke,
   	// lc.cap ct0, (c31) //(riscv) c31 is unsealed data capability from CInvoke
   	//c9 points to first part of data section which is seal capability
   	//FIXMe temp fix to deal with BRS changing state from c64 to a64 on entry
   	//Manual says set lsb of target capability (code_cap) to 1 for c64
   	//this will need to be done when code_cap created since can not change a
   	//sealed capability. Doing this caused issue in code, probably checks rely on address
   	//for length calcs. need to ignore bottom bit in checks.
   	BX#4 //on entry hardware defaults to a64, so need to tell it to switch to c64
   	//this instruction fails if enters on a64 mode
   	LDR c9, [c29] //(Morello) c29 is unsealed data capability from BRS

   	//----------------------------------------------
   	//This is set in capatest asm code enclave_init function
   	// # Dispatch entry point based on a7: 0=init, -1=return, other=entries

   	// check a7 (x7)
   	//----------------------------------------------
   	// branch to enclave_init if a7(x7)==0
   	//----------------------------------------------
   	// beqz a7, enclave_init //(riscv)
    CMP x7, XZR //(compare x7 to zero) //(Morello)
    B.EQ enclave_init //(branch if x7=0) //(Morello)
   	//----------------------------------------------
   	// Otherwise Load stack pointer capability from enclave data section
   	//----------------------------------------------
   	// CIncOffsetImm ct1, c31, DATA_OFFSET_CSP //inc offset in c31 and write to ct1 //(riscv)
   	// lc.cap csp, (ct1) //(riscv) Capability register cd is replaced with the capability located in memory at cs1.address
   	// CAN JUST DO THIS INSTEAD in Morello
   	LDR  c10, [c29,#DATA_OFFSET_CSP] //load csp capability from data section of enclave
   	MOV  csp, c10 //move to stack pointer register

   	//# Check if csp has a valid tag. If not, init has not been called yet (or
   	// # failed).
   	// CGetTag t0, csp //(riscv)
   	GCTAG x13, csp //(Morello)

   	//----------------------------------------
   	// branch to enclave_exit if stack pointer tag 0
   	//----------------------------------------
   	// beqz t0, enclave_exit //(riscv)
   	CMP x13, XZR //(compare x13 to zero)
   	B.EQ enclave_exit //(branch if x13=0)//(Morello)

   	//----------------------------------------
   	// make ct1(c10) point to start of data (after csp cap)
   	//----------------------------------------
   	//# Make data section after seal available in ct1
   	//CIncOffsetImm ct1, c31, DATA_OFFSET_ENCLAVE //(riscv)
   	GCOFF x10, c29 //(get current offset) //(Morello)
   	ADD x10, x10, #DATA_OFFSET_ENCLAVE //(add offset) //(Morello)
   	SCOFF c10, c29, x10 //(set offset and create new capability, based on data capability c29) //(Morello)

   	//Check a7 (x7) for return
   	//----------------------------------------------
   	// branch to enclave_return_entry if a7(x7)==-1
   	//----------------------------------------------
   	//li t0, -1 //(riscv)
   	//beq a7, t0, enclave_return_entry //(riscv)
   	MOV x13, #-1//(Morello)
   	CMP x7, x13 // (compare x7 to x13)//(Morello)
   	B.EQ enclave_return_entry //(branch if x7-x13=0)//(Morello)

   	//Check a7 do other
   	//----------------------------------------------
   	// carry on to do enclave entry if a7(x7)==other
   	//----------------------------------------------
   	// # Enclaves should define their entry points as an array of function pointers
   	// # at enclave_entries_start.
   	// la t0, enclave_entries_start //(riscv)
   	// la t1, enclave_entries_end //(riscv)
   	LDR x13, =enclave_entries_start //(Morello)
   	LDR x14, =enclave_entries_end //(Morello)

   	//----------------------------------------
   	// get the pointer offset from enclave_entries_start
   	//----------------------------------------
   	//# Transform 1-based pointer index in a7 to a 0-based byte offset.
   	// addi t2, a7, -1 //(riscv)
   	// slli t2, t2, 2 //(riscv)
   	ADD x15, x7, #-1 //1-1=0(Morello)
   	LSL x15, x15, #2 //(Morello) This is the pointer offset from enclave_entries_start

   	//----------------------------------------
   	// branch to enclave_exit if entry pointer address not valid
   	//----------------------------------------
   	//Branch if greater than or equal
   	// # Calculate address of entry pointer. This address is relative to PCC.
   	// add t2, t0, t2 //(riscv)
   	// bge t2, t1, enclave_exit //(riscv)
   	ADD x16, x13, x15 //enclave_entries_start +0 = set_sensor_enclave(Morello)
   	CMP x16, x14 //(compare x16 to x14) //(Morello)
   	B.PL enclave_exit //(branch if x16-x14=+ve or 0) //(Morello)

   	//----------------------------------------
   	// Otherwise Create capability to entry pointer and load the offset
   	// to the function to run
   	//----------------------------------------
   	// CSpecialR ct2, pcc //(riscv)
   	// CSetOffset ct3, ct2, t2 //(riscv)
   	// lw.cap t3, (ct3) //(riscv)
   	//make a capability based on the program counter with address label of where the
   	//start of the function pointers reside
   	ADR c12, enclave_entries_start
   	//add the offset to point to the correct function pointer
   	GCOFF x17, c12//get current offset and add x15 to it
   	ADD x15, x17, x15
   	SCOFF c12, c12, x15 //set offset
   	//get the offset that the program counter needs to jump to
   	//relative to the base value of the PCC
   	LDR w6, [c12,#0] //(word in armv8a is 32 bit)//(Morello)

   	//----------------------------------------
   	// Create capability to function and branch
   	//----------------------------------------
   	//we now need to change the offset of the capability with this new offset
   	//the capability has the same bounds as PCC so the base is the start of the enclave code
   	SCOFF c12, c12, x6

   	// # The entry pointer is an offset from the start of the code section. This
   	// # means we can directly jump to it as jumps are relative to PCC.
   	// jr t3 //(riscv)

   	//branch to function via offset
   	BR c12
//-----------------------------------------------------------------

//-----------------------------------------------------------------
// enclave_init:
//-----------------------------------------------------------------
 enclave_init:
	//----------------------------------------
	//# Check if data section is large enough to hold at least 4 capabilities and
    //# the requested ENCLAVE_DATA_SIZE
    //----------------------------------------
    //CGetLen t0, c31 # Data section size//(riscv)
    //li t1, 4 * CAP_LEN + ENCLAVE_DATA_SIZE//(riscv)
    GCLEN x13, c29//(Morello)
    MOV x14, #((4 * CAP_LEN) + ENCLAVE_DATA_SIZE) //ENCLAVE_DATA_SIZE defined in user_enclave.S and sensor_enclave.S
   	//----------------------------------------
   	// If not large enough branch to enclave_exit
   	//----------------------------------------
    //blt t0, t1, enclave_exit//(riscv)
    CMP x13, x14 //(compare x13 to x14) //(Morello)
    B.MI enclave_exit // (branch if x3-x14=-ve )//(Morello)

	//----------------------------------------
	// Otherwise # Store code_cap/data_cap (available in ca0/ca1 FUNC ARGS) in our data section
	//----------------------------------------
    //CIncOffsetImm ct1, c31, DATA_OFFSET_CODE_CAP//(riscv)
    //sc.cap ca0, (ct1)//(riscv)
    //CIncOffsetImm ct1, c31, DATA_OFFSET_DATA_CAP//(riscv)
    //sc.cap ca1, (ct1)//(riscv)
    //c29 is pointer to data section in Morello
    STR c0, [c29,#DATA_OFFSET_CODE_CAP]//(Morello) store ca0 func arg
    STR c1, [c29,#DATA_OFFSET_DATA_CAP]//(Morello) store ca1 func arg

	//----------------------------------------
    //# Create stack
    //----------------------------------------
    //sub t2, t0, t1 # Stack size = data section length - static data length//(riscv)
    //CSetOffset csp, c31, t1 # Stack bottom after static data//(riscv)
    //CSetBoundsExact csp, csp, t2//(riscv)
    //CSetOffset csp, csp, t2 # Offset to top of stack//(riscv)
	SUB x15, x13, x14 //calc len of stack and put in x15//(Morello)
	GCVALUE x16, c29 // get current addr
	ADD x16,x16,x14 //get absolute value for stack start
	SCVALUE   csp, c29, x16 //set up cap for stack, based on full data section c29, start stack bottom after static data x14//(Morello)
    SCBNDSE csp,csp,x15 //reduce length of bounds to stack size only//(Morello)
 	ADD csp,csp,x15 //move the offset back to top of stack (Add the length)

    //# Store stack pointer
    //CIncOffsetImm ct1, c31, DATA_OFFSET_CSP//(riscv)
    //sc.cap csp, (ct1)//(riscv)
    MOV c10, csp // can't save csp directly//(Morello)
    STR c10, [c29,#DATA_OFFSET_CSP]//(Morello) store csp at start of data section

    //----------------------------------------
    // create enc/sign seal
    //----------------------------------------
    //# Create public enc seal in ca0 (c0) as a return ARG: seal=base seal, perms=only seal
    //enc/sign seal is in ct0 (c9)//(riscv)
    //CSetBoundsImm ca0, ct0, 1//(riscv)
    //li t0, (1 << PERM_PERMIT_SEAL)//(riscv)
    //CAndPerm ca0, ca0, t0//(riscv)
    MOV X13, #1 //(Immediate to reg first) //(Morello)
    SCBNDSE c0, c9, x13 //(no immediate, reg only)//(Morello)
    // we need to remove all permissions except seal so need to invert
    ORN x13, xzr, #(0x1 << PERM_PERMIT_SEAL)
    CLRPERM c0, c0, x13 //(reduce permissions)

    //# Create public sign seal in ca1 (c1) as a return ARG: seal=base seal+1, perms=only unseal
    //CIncOffsetImm ca1, ct0, 1//(riscv)
    //CSetBoundsImm ca1, ca1, 1//(riscv)
    //li t0, (1 << PERM_PERMIT_UNSEAL)//(riscv)
    //CAndPerm ca1, ca1, t0//(riscv)
    //inc offset
    GCOFF x13, c9 //(get current offset)
    ADD x13, x13, #1 //(add offset)
    SCOFF c1, c9, x13 //(set offset)
    //set bounds
    MOV X13, #1 //(Immediate to reg first) //(Morello)
    SCBNDSE c1, c1, x13 //(no immediate, reg only)//(Morello)
    // we need to remove all permissions except unseal so need to invert
    ORN x13, xzr, #(0x1 << PERM_PERMIT_UNSEAL)//(Morello)
    CLRPERM c1, c1, x13 //(reduce permissions)//(Morello)

//-----------------------------------------------------------------
// enclave_exit:
//-----------------------------------------------------------------
 enclave_exit:
	//# Clear full enc/sign seal
    //CClearTag ct0, ct0//(riscv)
    CLRTAG C9, C9//(Morello)

    //# Clear data capabilities
    //CClearTag ct1, ct1//(riscv)
    //CClearTag c31, c31//(riscv)
    CLRTAG C10, C10//(Morello) data of data section
    CLRTAG C29, C29//(Morello)

    // # TODO All registers should be cleared! We probably want to implement CClear
    //# Code capability will be cleared by return jump

    //CJALR cra//(riscv)
	RET
//-----------------------------------------------------------------

//-----------------------------------------------------------------
// enclave_invoke:
//This is called by user_enclave.S to invoke sensor enclave
    //# Invoke another enclave. Put arguments in caX, return address (offset
    //# in our code section) in ra, target code/data capabilities in ct2/ct3, and
    //# target entry point index in a7 before jumping here.
    //#
    //# When invoking another enclave, we put our own code/data capabilities in
    //# cra/cs0. When the callee wants to return, it can invoke those capabilities
    //# passing return values in caX as usual and setting a7=-1.
//-----------------------------------------------------------------
 enclave_invoke:
    //# Push cra on the stack -return addr (c30)
    //CIncOffsetImm csp, csp, -CAP_LEN//(riscv)
    //sc.cap cra, (csp)//(riscv)
    SUB csp, csp, #CAP_LEN//(Morello)
    STR c30, [csp]//(Morello)

	//THIS IS NOT CORRECT FOR MORELLO, BECAUSE ONLY ONE SET OF REGISTERS SO ONLY ONE RETURN ADDRESS
    //# Store return capability based on ra on the stack
    //CSpecialR ct1, pcc//(riscv)
    //CSetOffset ct1, ct1, ra//(riscv)
    //CIncOffsetImm csp, csp, -CAP_LEN//(riscv)
    //sc.cap ct1, (csp)//(riscv)

    //# Store csp in data section- c29 is data section cap
    //CIncOffsetImm ct1, c31, DATA_OFFSET_CSP
    //sc.cap csp, (ct1)
    MOV c10, csp // can't save csp directly//(Morello)
    STR c10, [c29,#DATA_OFFSET_CSP]//(Morello) store csp at start of data section

    //# Load our code/data capabilities
    //CIncOffsetImm ct1, c31, DATA_OFFSET_CODE_CAP //(riscv)
    //lc.cap cra, (ct1) //(riscv)
    LDR c30, [c29,#DATA_OFFSET_CODE_CAP]//(Morello)
    //CIncOffsetImm ct1, c31, DATA_OFFSET_DATA_CAP //(riscv)
    //lc.cap cs0, (ct1) //(riscv)
    LDR c19, [c29,#DATA_OFFSET_DATA_CAP]//(Morello)
    //# TODO Clear regs.

    //# Invoke callee
    //CInvoke ct2, ct3 //(riscv)
    BRS c29, c11, c12 //(must include C29)

//-----------------------------------------------------------------
// enclave_return_entry:
//-----------------------------------------------------------------
 enclave_return_entry:
 	//# Load return capability from the stack
 	//lc.cap ct2, (csp) //(riscv)
 	//CIncOffsetImm csp, csp, CAP_LEN //(riscv)
    LDR c11, [csp]//(Morello)
    ADD csp, csp, #CAP_LEN//(Morello)
    //THIS CAN NOT BE DONE HERE FOR MORELLO AS ONLY ONE SET OF REGISTERS
 	//# Load old cra from the stack
 	//lc.cap cra, (csp) //(riscv)
 	//CIncOffsetImm csp, csp, CAP_LEN //(riscv)

//-----------------------------------------------
//CAP-TEE moved from here because stack saved
//before finished being restored
//causes problems when trying to loop encalve func
//-----------------------------------------------
 	// # Store csp (this should probably be done when exiting)
 	//CIncOffsetImm ct3, c31, DATA_OFFSET_CSP //(riscv)
    //sc.cap csp, (ct3) //(riscv)
   // MOV c12, csp // can't save csp directly//(Morello)
  //  STR c12, [c29,#DATA_OFFSET_CSP]//(Morello)


    //CJALR c0, ct2 -> cjalr cnull, cs -jump to capability
    RET c11 //GO BACK TO USE SENSOR backu:


//-----------------------------------------------------------------
//enclave_return:
//-----------------------------------------------------------------
enclave_return:

    //li a7, -1 //(riscv)
    //CInvoke cra, cs0 //(riscv)
	MOV x7, #-1
	BRS c29, c30, c19 //(must include C29)



