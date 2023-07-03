/*
 ============================================================================
 Name        : regForEL2N.s
 Author      : CAP-TEE
 Version     :
 Copyright   : CAP-TEE 2021
 Description : setting up the registers to go to EL2 non-secure hypervisor
 			   performing an ERET
 			   In addition, functions to manipulate EL2 registers
 			   The first half is in secure memory, the second half is in non
 			   secure memory
 ============================================================================
 */

 //****************************************************************************
 // SECTION AND DEFINES
 //****************************************************************************
   // the first half of this file goes into secure memory region by default
 .section .SECURERegEL2Nsection_ass_el3, "ax"
 .align 3                   // Align to 2^3 byte boundary

 // Program state
 //.equ PS0_EL2, 	0x08    // EL2t  this doesn't load stack into SP reg in this state
 .equ PS2_EL2,	0x09    // EL2h  use this state as it loads the stack pointer addr into SP reg

 // function to set up registers and ERET to EL2N hypervisor
 .global ERETtoEL2N

 //***********************************************************
 // FUNCTIONS
 //***********************************************************
 //-----------------------------------------------------------
 // ERETtoEL2N
 //-----------------------------------------------------------
 .type ERETtoEL2N, "function"
ERETtoEL2N:

  // Disable trapping
  //MSR      CPTR_EL3, xzr // Clear all trap bits
  //MSR      CPTR_EL2, xzr // Clear all trap bits
    // Disable trapping CPTR_EL3
  // after start up CPTR_EL3 = 0x200, EC[9]
  // TCPAC[31] (0)=no trap some EL2/EL1 reg
  // TAM[30] (0)=no trap activity monitor
  // TTA[20] (0)= no trap trace reg
  // TFP[10] (0)= no trap SIMD/FP
  //--opposite traps
  // EC[9] (1)=no trap of morello instructions
  // EZ[8] (0)=trap of SVE
  #ifdef __CHERI_PURE_CAPABILITY__
  	// CPTR_EL3.EC [9] traps morello instructions at all EL (0)trap (1)no trap
  	// already set to no trap (1) in start up code, so do nothing
  #else
  	// Trapping at CPTR_EL3
    // Enable trapping of morello instructions - does not work otherwise
  	MSR      CPTR_EL3, xzr
  	ISB
  #endif

  //#ifdef __CHERI_PURE_CAPABILITY__
  //	MSR       DDC, c15
  //#endif

  // Disable trapping CPTR_EL2
  // Clearing all trap bits stops capability from working - so don't do this
  // disable trapping of floating point reg q0 - needed for long strings
  // disable trapping of morello specific instructions (uses a reserved armv8 bit) - needed for printf function
  // TFP, bit [10] when set to 1 Traps execution of EL2 instructions which access the Advanced SIMD and floating-point functionality,
  // TC, bit [9] when set to 1 traps morello instructions at EL2/EL1/EL0 like using capability registers which printf function uses
  MRS      x0, CPTR_EL2  // Read
  // create mask 1111 1001 1111 1111
  MOV x2, #0xF9FF
  MOVK x2, #0xFFFF,LSL #16
  // and mask with contents of register to set bit[10] and bit[9] to zero
  AND      x0, x0, x2 // disable
  MSR      CPTR_EL2, x0 // Write
  ISB

  // SET NORMAL WORLD HERE
  // Set SCR_EL3 - secure configuration register to determine what happens at lower exception levels
  MOV      w1, #1              //  NS (#0-is Secure state, #1 is non secure  - hypervisor)
  ORR      w1, w1, #(1 << 8)    // HCE=1         HVC Hypervisor call instructions are enabled
  ORR 	   w1, w1, #(1 << 11)  // set ST bit (disable trapping of timer control registers)
  ORR	   w1, w1, #(1 << 10)  // set RW bit (next lower EL in aarch64 mode)
  							   // [7] = 0 SMC instructions are enabled at EL3, EL2 and EL1.
  //we do not want exceptions to be routed to EL3
  //we would like the timer interrupt to be routed to EL1N vector table
  //so do not set these exception bits:
  ORR      w1, w1, #(1 << 3)   // Set EA bit (SError routed to EL3)
  ORR      w1, w1, #(1 << 2)   // Set FIQ bit (FIQs routed to EL3)
  ORR      w1, w1, #(1 << 1)   // Set IRQ bit (IRQs routed to EL3)
  MSR      SCR_EL3, x1
  ISB

  // Set SCTLRs for EL1/2 to safe values before set up of EL2 and EL1
  // ------------------------------------
  MSR     SCTLR_EL2, xzr //reg turns on/off MMU EL2
  MSR     SCTLR_EL1, xzr //reg turns on/off MMU EL1


    // set DDC to maximum bounds
  //#ifdef __CHERI_PURE_CAPABILITY__
  //	MSR       DDC, c15
  //#endif

  LDR      x0, =EL2N_hypervisor_entry // where to branch to when exception completes
  #ifdef __CHERI_PURE_CAPABILITY__
    //get default data capability permissions
  	MRS       c15, DDC
  	//put x0 value into c0 with default permissions
  	SCVALUE   c0, c15, x0
  	MSR 	   CELR_EL3, c0 // where to branch to when exception completes
  #else
  	MSR 	  ELR_EL3, x0 			      // where to branch to when exception completes
  #endif

  LDR	  x1, =PS2_EL2 		          //the program state
  #ifdef __CHERI_PURE_CAPABILITY__
  	// Need to manually set c64 mode on an ERET, otherwise will be set to a64
  	ORR x1,x1, #(1 << 26)
  #endif
  MSR      SPSR_EL3, x1 			  // set the program state for this point to a known value
  ISB
  ERET  //This is ERET - LEAVES EL3





 //****************************************************************************
 // SECTION AND DEFINES
 //****************************************************************************
 // need to put into non secure memory region by linker script
 .section .NONSECUREel2entrysection_ass_el2, "ax"

   //define uart location in memory
  //0xE0000000 (DRAM0 mem)//0x1C090000 (uart base) //0x2A400000 (uart base)
  .equ UART_ADDR, 0x2A400000 //0xE0000000 //0x1C090000 //0x2A400000
  .equ UART_LENGTH, 0x52 //length of uart space in memory



  .align 4 //128 bit/16 byte boundary

  // global capabilities
  //.global HeapCap_EL1N
  .global GLOBAL_UART_CAP_EL2N
  .global GLOBAL_UART_CAP_EL1N
  .global MEM_EL1N_AT_EL2N




 // function to initialise entry to EL2N, sets up stack and registers and branches
 // to main EL2N c code
 .global EL2N_hypervisor_entry
 //install vector table for EL2
 .global installVectorsEL2N
  //install vector table for EL1N
 .global installVectorsEL1N
 // function to stop EL1 from changing the mmu/memory settings
 .global disableEL1N_mmuChange
  // function to stop EL1 from changing the vector table register
 .global disableEL1N_vectorChange
  // function to stop EL1 from changing the page table / vector table entries
 .global disableEL1N_memRO
 // function to get the exception information for EL2
 .global readESREL2

 //***********************************************************
 // FUNCTIONS
 //***********************************************************

 //----------------------------------------------------------------------------
 // readESREL2
 // Description: Get the exception information for EL2
 //----------------------------------------------------------------------------
  .type readESREL2, "function"
readESREL2:
  // Holds syndrome information for an exception taken to EL2.
  // Read this to get exception information
  MRS       x0, ESR_EL2  //Exception Syndrome Register, EL2
  RET
  .size readESREL2, . - readESREL2

 // ------------------------------------------------------------
 // installVectorsEL2N  - install vector table for EL2N hypervisor
 // ------------------------------------------------------------
 .type installVectorsEL2N, "function"
installVectorsEL2N:

  // Install EL2N vector table here for exceptions and interrupts
  // VBAR_EL2 points to the vector table vectorsEL2N
  .global vectorsEL2N

  #ifdef __CHERI_PURE_CAPABILITY__
  	//set bounds , vector table is fixed format:
  	//4sets * 4entries *128bytes = 2,048 bytes (dec) = 800hex
  	//but on an exception the CVBAR capability bounds is transferred
  	// to the PCC so needs to cover the whole of EL2 memory
  	//so we need to set the base to 0x800000000, limit to 0xc00000000, value/offset to vectorsEL2N
  	//MOV x3, #0x0900
  	//SCBNDSE c0,c0,x3
  	//get start of el3/2 memory address (lower point in memory) from linker script
    LDR	   x0, =_start_el3_2
    //get start of el1 memory address (upper point in memory) from linker script
    LDR	   x1, =_start_el1
    //get offset address
    LDR    x2, =vectorsEL2N
    //calc length of bounds
    SUB x3, x1, x0 //x1-x0
    //calc offset from base
    SUB x4, x2, x0 //x2-x0
    // get default bounds/permissions
    MRS       c15, DDC
    //set base address of bounds to start of el3/2 memory address
    // put x0 value into c0 with default permissions
  	SCVALUE   c0, c15, x0
  	//set upper bounds limit
 	SCBNDSE c0,c0,x3
 	// move the capability so it now points to the vector table
 	// where the PCC needs to start from on an exception
 	ADD c0,c0,x4
  	MSR  CVBAR_EL2, c0
  #else
    LDR  x0, =vectorsEL2N
    MSR  VBAR_EL2, x0
  #endif
 ISB
 RET
  .size installVectorsEL2N, . - installVectorsEL2N

  // ------------------------------------------------------------
 // installVectorsEL1N  - install vectore table for EL1N
 // ------------------------------------------------------------
 .type installVectorsEL1N, "function"
installVectorsEL1N:

  // Install EL1N vector table here for exceptions and interrupts
  // VBAR_EL1 points to the vector table vectorsEL1N
  .global vectorsEL1N
    #ifdef __CHERI_PURE_CAPABILITY__
  	//set bounds , vector table is fixed format:
  	//4sets * 4entries *128bytes = 2,048 bytes (dec) = 800hex
  	//but on an exception the CVBAR capability bounds is transferred
  	// to the PCC so needs to cover the whole of EL2 memory
  	//so we need to set the base to 0x800000000, limit to 0xc00000000, value/offset to vectorsEL2N
  	//get start of el3/2 memory address (lower point in memory) from linker script
    LDR	   x0, =_start_el3_2
    //get start of el1 memory address (upper point in memory) from linker script
    LDR	   x1, =_start_el1
    //get offset address
    LDR    x2, =vectorsEL1N
    //calc length of bounds
    SUB x3, x1, x0 //x1-x0
    //calc offset from base
    SUB x4, x2, x0 //x2-x0
    // get default bounds/permissions
    MRS       c15, DDC
    //set base address of bounds to start of el3/2 memory address
    // put x0 value into c0 with default permissions
  	SCVALUE   c0, c15, x0
  	//set upper bounds limit
 	SCBNDSE c0,c0,x3
 	// move the capability so it now points to the vector table
 	// where the PCC needs to start from on an exception
 	ADD c0,c0,x4
  	MSR  CVBAR_EL1, c0
  #else
    LDR  x0, =vectorsEL1N
    MSR  VBAR_EL1, x0
  #endif
  ISB
  RET
  .size installVectorsEL1N, . - installVectorsEL1N

 //-------------------------------------------
 // disableEL1N_mmuChange
 // function to stop EL1 from changing the mmu/memory settings
 //-------------------------------------------
  .type disableEL1N_mmuChange, "function"
disableEL1N_mmuChange:

  MRS X0, HCR_EL2  //get current register value

  // trap EL1 memory operations to EL2 - so EL1 can't mess with memory
  // check this setting, check if other traps needed
  // bit[26]  TVM - the following registers are trapped to EL2 and reported using EC syndrome value 0x18:
  // SCTLR_EL1, TTBR0_EL1, TTBR1_EL1, TCR_EL1, ESR_EL1, FAR_EL1, AFSR0_EL1, AFSR1_EL1, MAIR_EL1, AMAIR_EL1, CONTEXTIDR_EL1.
  ORR      x0, x0, #(1 << 26)                 // bit[26]  TVM traps writes
  ORR      x0, x0, #(1 << 30)				  // TRVM, bit [30] traps reads
  ORR      x0, x0, #(1 << 25)				  // TTLB, bit [25] traps TLB maintenance instructions for the mmu

  MSR      HCR_EL2, x0
  ISB

  RET
  .size disableEL1N_mmuChange, . - disableEL1N_mmuChange

 //-------------------------------------------
 // disableEL1N_vectorChange
 // function to stop EL1N from changing the EL1N vector table register
 //-------------------------------------------
  .type disableEL1N_vectorChange, "function"
disableEL1N_vectorChange:

  MRS X0, HCR_EL2  //get current register value

  // can't route all general sync exceptions to EL2, but can route
  // FIQ [3],IRQ [4], SError [5] async exceptions, and can
  // stop EL1 from changing the vector exception table at EL1
  // if nested virtualisation feature is present
  // Data aborts due to write access gets routed to EL1 current sync
  // THIS DOESN'T SEEM TO SET THE BIT NV1 - THIS IMPLIES THE NESTED
  // VIRTUALISATION FEATURE IS NOT PRESENT.
  ORR      x0, x0, #(1 << 43)					// NV1, bit [43] traps VBAR_EL1

  MSR      HCR_EL2, x0
  ISB

  RET
  .size disableEL1N_vectorChange, . - disableEL1N_vectorChange


 //-------------------------------------------
 // disableEL1N_memRO
 // function to stop EL1N from changing the page table / vector table entries
 // by making the memory region read only in the mmu
 //-------------------------------------------
  .type disableEL1N_memRO, "function"
disableEL1N_memRO:
B .
  //STAGE1 TRANSLATION - change memory region to read only
  .equ LOWBLK_NORMAL_NON_TRANS_RO, 0x00000000000000481
  //first, get memory address of translation table
  MRS      x1, TTBR0_EL1
  LDR      x0, =LOWBLK_NORMAL_NON_TRANS_RO //el1 read only section
  // OR with start address of region
  ORR      x0, x0, #0x80000000
  // save to memory
    //THIS WILL ONLY WORK IF DDC NOT NULL
  //if read only, will cause exception to EL1
  // put in the table
  #ifdef __CHERI_PURE_CAPABILITY__
    //get default data capability permissions
  	MRS       c15, DDC
    //put x1 value into c1 with default permissions
  	SCVALUE   c1, c15, x1
  	STR      x0, [c1, #16]
  #else
    STR      x0, [x1, #16]
  #endif
  DSB      SY
  //invalidate TLB
  TLBI     VMALLE1 //TLB invalidate by VMID, All at stage 1, EL1.
  DSB      SY
  ISB

 //STAGE2 TRANSLATION - change memory region to read only
 .equ LOWBLK_NORMAL_WRT_BCK_RO, 0x0000000000000047D //read only
  //first, get memory address of translation table
  MRS      x1, VTTBR_EL2
  LDR      x0, =LOWBLK_NORMAL_WRT_BCK_RO //read only section
  // OR with start address of region
  ORR      x0, x0, #0x80000000
  // put in the table
   //THIS WILL ONLY WORK IF DDC NOT NULL
    #ifdef __CHERI_PURE_CAPABILITY__
    //get default data capability permissions
  	MRS       c15, DDC
    //put x1 value into c1 with default permissions
  	SCVALUE   c1, c15, x1
  	STR      x0, [c1, #16]
  #else
    STR      x0, [x1, #16]
  #endif
  DSB      SY
  //invalidate TLB
  TLBI     VMALLS12E1 //	TLB invalidate by IPA, Stage 2, EL1.
  DSB      SY
  ISB

  RET
  .size disableEL1N_memRO, . - disableEL1N_memRO

 // ------------------------------------------------------------
 // EL2 hypervisor (non secure) AArch64
 // ------------------------------------------------------------
   // don't declare  as a function because in
  // Morello-purecap causes the program counter to become missaligned by 1 byte
  // when retrieving the function label and causes an exception
// .type EL2N_hypervisor_entry, "function"
EL2N_hypervisor_entry:
  // ENTERS EL2N HERE
  // Get stack address defined in linker script
  // Needs this because it looses the stack on entry to EL2, and doesn't work without it
  //ADRP x0, _stack_el2n_limit
  //MOV  sp, x0

//MODIFIED*** - COPIED HERE SO CAN START FROM EL2
  // Disable trapping CPTR_EL2
  // Clearing all trap bits stops capability from working - so don't do this
  // disable trapping of floating point reg q0 - needed for long strings
  // disable trapping of morello specific instructions (uses a reserved armv8 bit) - needed for printf function
  // TFP, bit [10] when set to 1 Traps execution of EL2 instructions which access the Advanced SIMD and floating-point functionality,
  // TC, bit [9] when set to 1 traps morello instructions at EL2/EL1/EL0 like using capability registers which printf function uses
  MRS      x0, CPTR_EL2  // Read
  // create mask 1111 1001 1111 1111
  MOV x2, #0xF9FF
  MOVK x2, #0xFFFF,LSL #16
  // and mask with contents of register to set bit[10] and bit[9] to zero
  AND      x0, x0, x2 // disable
  MSR      CPTR_EL2, x0 // Write
  ISB

  //--------------------------------------------------------------
  // Set up EL2 normal exception entry (not ERET) to c64 mode
  // (ensures still in capability mode on an exception)
  //--------------------------------------------------------------
  #ifdef __CHERI_PURE_CAPABILITY__
    MRS	  x1, CCTLR_EL2 //read
  	// Need to manually set c64 mode on an exception, otherwise will be set to a64
  	ORR  x1,x1, #(1 << 5) //set CCTLR_ELx.C64E
  	MSR  CCTLR_EL2, x1 //write
  	ISB
  #endif


  //--------------------------------------------------------------
  // Set up EL2 stack
  //--------------------------------------------------------------
  // Get stack address defined in linker script
  // Needs this because it looses the stack on entry to EL2, and doesn't work without it
  // STACK_SIZE = 0x20000;
  #ifdef __CHERI_PURE_CAPABILITY__
    // must use c0 for ADRP, stack not defined without linker
    // ADRP c0, _stack_el1n_base // if use this, sign extends to FFFFFFFF C0020000 and points to wrong place

    // Stack starts at base (upper memory) and grows down (lower memory)
    // However we have to set up the capability the other way around to
    // set the correct bounds (cannot set a negative bounds),
    // and then change the value to start at the base
    LDR	   x0, =_stack_el2n_limit //get unsigned stack limit address (lower point in memory)
    LDR	   x1, =_stack_el2n_base //get unsigned stack base address (upper point in memory)
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
 	//CLRPERM c0, c0, x2 //reduce permissions and clear execute
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
    //ADRP x0, _stack_el2n_base
    LDR	   x0, =_stack_el2n_base //get unsigned stack base address (upper point in memory)
    // ensure sp aligned to 16B boundary
    AND  x0, x0, ~15
    // mov to stack pointer
    MOV  sp, x0
  #endif

   //--------------------------------------------------------------
  // Set up EL2 global uart capability
  //--------------------------------------------------------------
  #ifdef __CHERI_PURE_CAPABILITY__
    // pointer to start of CAPABILITY memory location
  	// Get address of memory location
  	LDR      x2, =GLOBAL_UART_CAP_EL2N
  	// get default data capability permissions
  	MRS       c15, DDC
  	// c2 is now capability pointer to GLOBAL_UART_CAP
  	SCVALUE   c2, c15, x2

  	// set up bounds for UART in c3
  	MOV x3, #UART_ADDR //base addr of UART
  	// first set base address
  	SCVALUE   c3, c15, x3
  	// then set bounds
  	MOV x4, #UART_LENGTH //length of uart space - inc all uart registers
  	SCBNDSE c3,c3,x4
  	//store UART capability information at GLOBAL_UART_CAP
  	STR      c3, [c2]
  	// restrict permissions to go here ...

  	// data synchronisation - make sure all data written
  	DSB      SY
  #endif

  //--------------------------------------------------------------
  // Set up EL1 normal exception entry (not ERET) to c64 mode
  // (ensures still in capability mode on an exception)
  //--------------------------------------------------------------
  #ifdef __CHERI_PURE_CAPABILITY__
    MRS	 x1, CCTLR_EL1 //read
  	// Need to manually set c64 mode on an exception, otherwise will be set to a64
  	ORR  x1,x1, #(1 << 5) //set CCTLR_ELx.C64E
  	MSR  CCTLR_EL1, x1 //write
  	ISB
  #endif

  //--------------------------------------------------------------
  // Set up EL1 global uart capability
  //--------------------------------------------------------------
  #ifdef __CHERI_PURE_CAPABILITY__
    // pointer to start of CAPABILITY memory location
  	// Get address of memory location
  	LDR      x2, =GLOBAL_UART_CAP_EL1N
  	// get default data capability permissions
  	MRS       c15, DDC
  	// c2 is now capability pointer to GLOBAL_UART_CAP
  	SCVALUE   c2, c15, x2
  	// set up bounds for UART in c3
  	MOV x3, #UART_ADDR //base addr of UART
  	// first set base address
  	SCVALUE   c3, c15, x3
  	// then set bounds
  	MOV x4, #UART_LENGTH //length of uart space - inc all uart registers
  	SCBNDSE c3,c3,x4
  	//store UART capability information at GLOBAL_UART_CAP
  	STR      c3, [c2]
  	// restrict permissions to go here ...

  	// data synchronisation - make sure all data written
  	DSB      SY
  #endif

  //--------------------------------------------------------------
  // Set up EL1 global memory for memory sweep test
  //--------------------------------------------------------------
  #ifdef __CHERI_PURE_CAPABILITY__
    // pointer to start of CAPABILITY memory location
  	// Get address of memory location
  	LDR      x2, =MEM_EL1N_AT_EL2N
  	// get default data capability permissions
  	MRS       c15, DDC
  	// c2 is now capability pointer to MEM_EL1N
  	SCVALUE   c2, c15, x2

  	// set up bounds for MEM_EL1N
  	//MOV x3, #0xC0000000 //base addr
  	//MOV x3, #0xC002ea20//base addr
  	//MOV x3, #0xea20 //lower
	//MOVK x3, #0xc002,LSL #16 //upper
	MOV x3, #0x0000 //lower
	MOVK x3, #0xC000,LSL #16 //upper
  	// first set base address
  	SCVALUE   c3, c15, x3
  	// then set bounds
  	//MOV x4, #0x40000000 //
  	MOV x4, #0x0000 //lower
	MOVK x4, #0x4000,LSL #16 //upper, stack 0020 0000, 0X4000 to cover all
  	SCBNDSE c3,c3,x4
  	//store UART capability information at MEM_EL1N
  	STR      c3, [c2]
  	// restrict permissions to go here ...

  	// data synchronisation - make sure all data written
  	DSB      SY
  #endif

  //--------------------------------------------------------------
  // Set up EL1 registers????
  //--------------------------------------------------------------

  //--------------------------------------------------------------
  // Set up EL2 MMU ???
  //--------------------------------------------------------------
  //set up the mmu in the boot code here
  //before the DDC_EL2 is nulled in purecap
  // BL el2nmmu

	//--------------------
	//Tighten EL2N PCC bounds
	//-------------------
	//get PCC

	ADR c1, #0
	//get EL2 PCC limit address, which will be the end of EL2 code section defined in linker script
	LDR x2, =__NONSECUREsection_el2_end__

	//get EL2 PCC base address, which will be defined in linker script, move/change in linker if need to change it
	LDR x3, =START_EL2_PCC //currently set to start of DRAM
	//set new base value
	SCVALUE c1, c1, x3

	//get EL2 offset label of where to go to after limits set, this sets the offset
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

    //checks
    GCBASE x2, c1
    GCLIM x2, c1
    GCOFF x2, c1

    //branch to cap, bounds get transfered to PCC, and jumps to offset
    br c1
cont:
	BX#4 //force flip to capability mode after branch
	NOP

//--------------------------------------------------------------
  // clear capability registers before branching
  //only include this here if mmu is set up already
  //--------------------------------------------------------------
 /* #ifdef __CHERI_PURE_CAPABILITY__
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

  // Ensures that all instructions complete before branching
    ISB

  //--------------------------------------------------------------
  // Branch to the main EL2 normal code
  //--------------------------------------------------------------
  // Branch to the main EL2 hypervisor code
  B        el2nmain

//--------------------------------------------------------------
// Global Capabilities
//--------------------------------------------------------------
.section .bss //force capability to go in .bss section otherwise doesn't work
//.align 4 //ensure align to 16 byte boundary (2^4 = 16), gets passed str ESR mem alignment issue
//HeapCap_EL1N:
//.dword 0
//.dword 0
//.size HeapCap_EL1N, 16

.align 4 //ensure align to 16 byte boundary (2^4 = 16), gets passed str ESR mem alignment issue
GLOBAL_UART_CAP_EL2N:
.dword 0 //needs to be zero if in .bss section
.dword 0
.size GLOBAL_UART_CAP_EL2N, 16 //need this otherwise generates linker warning over size

.align 4 //ensure align to 16 byte boundary (2^4 = 16), gets passed str ESR mem alignment issue
MEM_EL1N_AT_EL2N:
.dword 0 //needs to be zero if in .bss section
.dword 0
.size MEM_EL1N_AT_EL2N, 16 //need this otherwise generates linker warning over size

.align 4 //ensure align to 16 byte boundary (2^4 = 16), gets passed str ESR mem alignment issue
GLOBAL_UART_CAP_EL1N:
.dword 0 //needs to be zero if in .bss section
.dword 0
.size GLOBAL_UART_CAP_EL1N, 16 //need this otherwise generates linker warning over size


