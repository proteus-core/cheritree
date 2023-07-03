/*
 ============================================================================
 Name        : regForEL1N.s
 Author      : CAP-TEE
 Version     :
 Copyright   : CAP-TEE 2021
 Description : setting up the registers to go to EL1 normal and performing an ERET
 ============================================================================
 */

 //****************************************************************************
 // SECTION AND DEFINES
 //****************************************************************************
   // this file goes into NON secure memory region
 .section .NONSECUREeretEL1Nsection_ass_el2, "ax"
 .align 3                   // Align to 2^3 byte boundary

 // Program state
 //.equ PS0_EL1N, 0x04 // EL1N program state 0
 .equ PS0_EL1N, 0x05 // EL1N program state 1 - interrupts only work in this state, loses stack otherwise

 // function to set up registers and ERET to EL1N
 .global ERETtoEL1N

 //***********************************************************
 // FUNCTIONS
 //***********************************************************

 //-----------------------------------------------------------
 // ERETtoEL1N
 //-----------------------------------------------------------
 .type ERETtoEL1N, "function"
ERETtoEL1N:

  //--------------------------------------------------------------
  // Set up EL1 registers
  //--------------------------------------------------------------
  // We must ensure that floating point register accesses are not trapped
  // since the c library for AArch64-v8A uses them
  // make sure do not change any other bits
  MRS      x0, CPACR_EL1  // Read
  ORR      x0, x0, #(0x3 << 20)
  MSR      CPACR_EL1, x0 // Write
  //set c64 manually for exceptions in capability mode
  #ifdef __CHERI_PURE_CAPABILITY__
    MRS      x1, SPSR_EL1 //read
    // Need to manually set c64 mode on an ERET, otherwise will be set to a64
    ORR x1,x1, #(1 << 26)
    MSR      SPSR_EL1, x1 //write
  #endif



 //--------------------------------------------------------------
 // where to branch to when exception completes
 //--------------------------------------------------------------
 LDR      x0, =EL1N_normal_entry
 #ifdef __CHERI_PURE_CAPABILITY__
   //get default data capability permissions
   MRS       c15, DDC
   //put x0 value into c0 with default permissions
   SCVALUE   c0, c15, x0
   MSR 	   CELR_EL2, c0 // where to branch to when exception completes
 #else
   MSR 	   ELR_EL2, x0 // where to branch to when exception completes
 #endif

 //--------------------------------------------------------------
 // set the program state when the exception completes
 //--------------------------------------------------------------
 LDR	  x1, =PS0_EL1N 		//the program state
 #ifdef __CHERI_PURE_CAPABILITY__
 // Need to manually set c64 mode on an ERET, otherwise will be set to a64
  ORR x1,x1, #(1 << 26)
 #endif
 MSR      SPSR_EL2, x1 			// set the program state for this point to a known value

 /*//clear EL2 registers
   #ifdef __CHERI_PURE_CAPABILITY__
	MSR	ddc, czr //NULL DDC
	MOV	x1, xzr
	MOV	x2, xzr
	MOV	x3, xzr
	MOV	x4, xzr
	MOV	x5, xzr
	MOV	x6, xzr
	MOV	x7, xzr
	MOV	x8, xzr
	MOV	x9, xzr
	MOV	x10, xzr
	MOV	x11, xzr
	MOV	x12, xzr
	MOV	x13, xzr
	MOV	x14, xzr
	MOV	x15, xzr
	MOV	x16, xzr
	MOV	x17, xzr
	MOV	x18, xzr
	MOV	x19, xzr
	MOV	x20, xzr
	MOV	x21, xzr
	MOV	x22, xzr
	MOV	x23, xzr
	MOV	x24, xzr
	MOV	x25, xzr
	MOV	x26, xzr
	MOV	x27, xzr
	MOV	x28, xzr
	MOV	x29, xzr
	MOV	x30, xzr
  #endif*/



 ISB
 ERET  //This is ERET - LEAVES EL2



 //****************************************************************************
 // SECTION AND DEFINES
 //****************************************************************************
 // need to put into non secure memory region by linker script
 .section .NONSECUREel1entrysection_ass_el1, "ax"

 //define uart location in memory
 //0xE0000000 (DRAM0 mem)//0x1C090000 (uart base) //0x2A400000 (uart base)
 .equ UART_ADDR, 0x1C090000 //0xE0000000 //0x1C090000 //0x2A400000
 .equ UART_LENGTH, 0x52 //length of uart space in memory

 .align 4 //128 bit/16 byte boundary

 // function to get the exception information for EL1N
 //.global readESREL1N
 // function to initialise entry to EL1N, sets up stack and registers and branches to main
 // EL1N c code
 .global EL1N_normal_entry

 // global capabilities
 .global CODE_SECTION_CAP

 //***********************************************************
 // FUNCTIONS
 //***********************************************************
 // ------------------------------------------------------------
 // EL1 normal (non secure) AArch64
 // ------------------------------------------------------------
 // don't declare EL1N_normal_entry as a function because in
 // Morello-purecap causes the program counter to become missaligned by 1 byte
 // when retrieving the function label and causes an exception
 // .type EL1N_normal_entry, "function"
EL1N_normal_entry:

  // ENTERS EL1N HERE
 //--------------------------------------------------------------
  // Set up EL1 stack
  //--------------------------------------------------------------
  // Get stack address defined in linker script
  // Needs this because it looses the stack on entry to EL1, and doesn't work without it
  // STACK_SIZE = 0x20000;
  #ifdef __CHERI_PURE_CAPABILITY__
    // must use c0 for ADRP, stack not defined without linker
    // ADRP c0, _stack_el1n_base // if use this, sign extends to FFFFFFFF C0020000 and points to wrong place

    // Stack starts at base (upper memory) and grows down (lower memory)
    // However we have to set up the capability the other way around to
    // set the correct bounds (cannot set a negative bounds),
    // and then change the value to start at the base
    LDR	   x0, =_stack_el1n_limit //get unsigned stack limit address (lower point in memory)
    LDR	   x1, =_stack_el1n_base //get unsigned stack base address (upper point in memory)
    // ensure sp aligned to 16B boundary
    AND  x0, x0, ~15
    AND  x1, x1, ~15
    //Work out size of stack: base - limit to get a positive length
  	SUB     x3, x1, x0
    // get default bounds/permissions
    MRS       c15, DDC //get default bounds/permissions
    // Set capability to point to limit first
    // put x0 value into c0 with default permissions
  	SCVALUE   c0, c15, x0
  	// set bounds to stack size - `EXACT`
  	// for non-exact, use SCBNDS
  	// see linker script for additional bounds notes
 	SCBNDSE c0,c0,x3
 	// move the capability so it now points to the base
 	// where the stack needs to start from
 	// (Add the length to the limit)
 	ADD c0,c0,x3
 	// Clear the execute permission bit as we don't want anything
 	// executing in the stack space
 	// change permissions
 	// [17] load
 	// [16] store
 	// [15] execute
 	// [14] load cap
 	// [13] store cap
 	// [12] store local cap
 	// [11] seal
 	// [10] unseal
 	// [9] system
 	// [8] branch sealed pair
 	// [7] compartment ID
 	// [6] mutable load
 	// [5:2] User[4]
 	MOV    x2, #0 //only set the bit to clear
    ORR    x2, x2, #(1 << 15) // execute
 	CLRPERM c0, c0, x2 //reduce permissions and clear execute
  	// mov to capability stack pointer
  	MOV  csp, c0
  	//--check stack pointer bounds and permissions
  	    // get value of capability and put into x4
  		GCVALUE x4, csp
       	// get base of capability and put into x4
  		GCBASE x4, csp
  		// get limit of capability and put into x4
  		GCLIM x4, csp
  		// get length of capability and put into x4
  		GCLEN x4, csp
  		// get permissions of capability and put into x4
  		GCPERM x4, csp
  	//--
  #else
    // get stack address from linker script
    // starts at base and grows down to limit
    ADRP x0, _stack_el1n_base
    // ensure sp aligned to 16B boundary
    AND  x0, x0, ~15
    // mov to stack pointer
    MOV  sp, x0
  #endif

  //--------------------------------------------------------------
  // Set up capability for enclave code section for the copy_code function
  // the capability covers both enclave code sections
  //--------------------------------------------------------------
  #ifdef __CHERI_PURE_CAPABILITY__
    // pointer to start of CAPABILITY memory location
  	// Get address of memory location
  	LDR      x2, =CODE_SECTION_CAP
  	// get default data capability permissions
  	MRS       c15, DDC
  	// c2 is now capability pointer to CODE_SECTION_CAP
  	SCVALUE   c2, c15, x2

  	// set up bounds in c3
  	LDR      x3, =enclave_code_start //base addr from linker
  	// first set base address
  	SCVALUE   c3, c15, x3
  	// then set bounds
  	LDR      x4, =enclave_code_end //length of code space
  	SUB x4,x4,x3 //enclave_code_end-enclave_code_start
  	SCBNDSE c3,c3,x4
  	//store capability information at CODE_SECTION_CAP
  	STR      c3, [c2]
  	// restrict permissions to go here ...

  	// data synchronisation - make sure all data written
  	DSB      SY
  #endif

	//--------------------
	//Tighten EL1N PCC bounds
	//-------------------
	//get PCC
	ADR c1, #0
	//get EL1 PCC limit address, which will be the end of EL1 code section defined in linker script
	LDR x2, =__NONSECUREsection_el1n_end__
	//get EL1 PCC base address, which will be defined in linker script, move/change in linker if need to change it
	LDR x3, =START_EL1_PCC //currently set to start of DRAM
	//set new base value
	SCVALUE c1, c1, x3

	//get EL1 offset label of where to go to after limits set, this sets the offset
	LDR x4, =cont
	SUB x4, x4, x3 //save for later
	//add 1 to it so lsb of capability later will be 1 to remain
	// in capability mode after branch
	//ADD x4, x4, #1

	//calc bounds length
	SUB x2, x2, x3 //x2-x3 to get bounds length
	// set capability bounds
	SCBNDSE c1,c1,x2

    //set the offset to the correct place to branch to
    SCOFF c1, c1, x4

    //branch to cap, bounds get transfered to PCC, and jumps to offset
    br c1
cont:
	BX#4 //force flip to capability mode after branch
	NOP

  //--------------------------------------------------------------
  // clear capability registers before branching
  //--------------------------------------------------------------
  #ifdef __CHERI_PURE_CAPABILITY__
//	MSR	ddc, czr //NULL DDC, now nulled at start of c code, after enclave memory defined
	MOV	x1, xzr
	MOV	x2, xzr
	MOV	x3, xzr
	MOV	x4, xzr
	MOV	x5, xzr
	MOV	x6, xzr
	MOV	x7, xzr
	MOV	x8, xzr
	MOV	x9, xzr
	MOV	x10, xzr
	MOV	x11, xzr
	MOV	x12, xzr
	MOV	x13, xzr
	MOV	x14, xzr
	MOV	x15, xzr
	MOV	x16, xzr
	MOV	x17, xzr
	MOV	x18, xzr
	MOV	x19, xzr
	MOV	x20, xzr
	MOV	x21, xzr
	MOV	x22, xzr
	MOV	x23, xzr
	MOV	x24, xzr
	MOV	x25, xzr
	MOV	x26, xzr
	MOV	x27, xzr
	MOV	x28, xzr
	MOV	x29, xzr
	MOV	x30, xzr
  #endif

  // Ensures that all instructions complete before branching
  ISB

 //--------------------------------------------------------------
  // Branch to the main EL1 normal code
  //--------------------------------------------------------------
  B        el1nmain

  endreg:
  NOP //doesn't get here

//.section .bss //force capability to go in .bss section otherwise doesn't work
.section .el1_bss, "aw", @nobits

.align 4 //ensure align to 16 byte boundary (2^4 = 16), gets passed str ESR mem alignment issue
CODE_SECTION_CAP:
.dword 0
.dword 0
.size CODE_SECTION_CAP, 16

