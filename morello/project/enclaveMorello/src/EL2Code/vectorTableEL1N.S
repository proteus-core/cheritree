/*
 ============================================================================
 Name        : vectorTableEL1N.s
 Author      : CAP-TEE
 Version     :
 Copyright   : CAP-TEE 2021
 Description : The vector table here is for EL1N
 			   All exceptions routed to EL1N come here. The exception type, and where it
 			   has come from determines which entry in the table it is routed to.
 			   This follows the standard vector table format for the AArch64 setup
 			   see https://developer.arm.com/documentation/100933/0100/AArch64-exception-vector-table
 			   Each exception level (EL3, EL1N, EL1S) has its own vector table.
			   The base address for the EL1 table is given by VBAR_EL1, which in this project is defined in regForEL1N.s
			   Each entry has a defined offset from this base address of 128 bytes.
			   Additionally, each table has a defined number of entries in a defined format of 4 sets of 4 entries to
			   cover the different types, and where the exception is being taken from.
			   The table contains branch instructions to an exception handler function, but it is possible to write
               up to 32 instructions here for each entry.
               In the specific table defined here, entries not used are branch to self (B .)

 ============================================================================
 */

 //****************************************************************************
 // SECTION AND DEFINES
 //****************************************************************************
 // Define a non secure memory region for the vector table
 // This section goes into the non secure memory region by the linker script
  .section  .NONSECUREvectortableel1N_ass_el2,"ax"
  .align 12

 // Vector Table function for EL1N - used outside this file
  .global vectorsEL1N
 // Exception handler function for EL1N - located in exceptionHandlerFuncsEL1N.c
  .global syncHandlerEL1N
 
 //****************************************************************************
 // FUNCTIONS
 //****************************************************************************

 //****************************************************************************
 // vectorsEL1N
 // Description: Vector table entries
 //****************************************************************************
  .type vectorsEL1N, "function"
vectorsEL1N:

// ------------------------------------------------------------
// Current EL with SP0 - program state 0  - 0X04 EL1N
// This block of four entries are associated with exceptions
// that have been triggered from EL1N whilst in program state 0
// ------------------------------------------------------------

  .balign 128
sp0_currentEL_SYNC:
  B        .                    //        Synchronous

  .balign 128
sp0_currentEL_IRQ:
  B        .                    //        IRQ

  .balign 128
sp0_currentEL_FIQ:
  B        . 					//        FIQ

  .balign 128
sp0_currentEL_SError:
  B        .                    //        SError

// ------------------------------------------------------------
// Current EL with SPx - program state 1  - 0x05 EL1N
// This block of four entries are associated with exceptions
// that have been triggered from EL1N whilst in program state 1
// The current example code uses program state 1.
// The non secure timer interrupt is set up to generate an irq exception.
// ------------------------------------------------------------

  .balign 128
spx_currentEL_SYNC:
  B        syncVectorHandler                    //        Synchronous

  .balign 128
spx_currentEL_IRQ:
  B        .     				//        IRQ

  .balign 128
spx_currentEL_FIQ:
  B        . 					//        FIQ

  .balign 128
spx_currentEL_SError:
  B        .                    //        SError

// ------------------------------------------------------------
// Lower EL using AArch64
// This block of four entries are associated with exceptions
// that have been triggered from a lower EL, which would be EL0
// using AArch64.
// The current example code does not use EL0.
// ------------------------------------------------------------

  .balign 128
aarch64_lowerEL_SYNC:
  B        .                    //		  Synchronous

  .balign 128
aarch64_lowerEL_IRQ:
  B        .                    //        IRQ

  .balign 128
aarch64_lowerEL_FIQ:
  B        . 					//        FIQ

  .balign 128
aarch64_lowerEL_SError:
  B        .                    //        SError

// ------------------------------------------------------------
// Lower EL using AArch32
// This block of four entries are associated with exceptions
// that have been triggered from a lower EL, which would be EL0
// using AArch32.
// The current example code does not use EL0.
// ------------------------------------------------------------

  .balign 128
aarch32_lowerEL_SYNC:
  B        .					//		Synchronous

  .balign 128
aarch32_lowerEL_IRQ:
  B        .                    //        IRQ

  .balign 128
aarch32_lowerEL_FIQ:
  B        .				    //        FIQ

  .balign 128
aarch32_lowerEL_SError:
  B        .                    //        SError

//add this on the end to ensure has 128bytes available in table at
//the end before the next bit of code, since it should be
// 4sets * 4 entries * 128bytes = 2,048 bytes = 800hex
// i.e should be available to go from A00F2000 to A00F2800
//without this table only goes up to A00F2780 (128 bytes less)
.balign 128
//removes warning: could not determine size of cap reloc against function (in GOT)
//place after RET to get size of function
.size vectorsEL1N, . - vectorsEL1N

//*****************************************************************************

//****************************************************************************
// syncVectorHandler
// Description: Saves the stack before jumping off to process the
// actual exception. On return, restores the stack
//****************************************************************************
syncVectorHandler:
  //save the stack
  #ifdef __CHERI_PURE_CAPABILITY__
   STP      c29, c30, [csp, #-32]!
   STP      c18, c19, [csp, #-32]!
   STP      c16, c17, [csp, #-32]!
   STP      c14, c15, [csp, #-32]!
   STP      c12, c13, [csp, #-32]!
   STP      c10, c11, [csp, #-32]!
   STP      c8, c9, [csp, #-32]!
   STP      c6, c7, [csp, #-32]!
   STP      c4, c5, [csp, #-32]!
   STP      c2, c3, [csp, #-32]!
   STP      c0, c1, [csp, #-32]!
  #else
   STP      x29, x30, [sp, #-16]!
   STP      x18, x19, [sp, #-16]!
   STP      x16, x17, [sp, #-16]!
   STP      x14, x15, [sp, #-16]!
   STP      x12, x13, [sp, #-16]!
   STP      x10, x11, [sp, #-16]!
   STP      x8, x9, [sp, #-16]!
   STP      x6, x7, [sp, #-16]!
   STP      x4, x5, [sp, #-16]!
   STP      x2, x3, [sp, #-16]!
   STP      x0, x1, [sp, #-16]!
  #endif

  // go to the exceptionHandlerFuncsEL1N functions to process the exception
  BL       syncHandlerEL1N

  #ifdef __CHERI_PURE_CAPABILITY__
    LDP      c0, c1, [csp], #32
    LDP      c2, c3, [csp], #32
    LDP      c4, c5, [csp], #32
    LDP      c6, c7, [csp], #32
    LDP      c8, c9, [csp], #32
    LDP      c10, c11, [csp], #32
    LDP      c12, c13, [csp], #32
    LDP      c14, c15, [csp], #32
    LDP      c16, c17, [csp], #32
    LDP      c18, c19, [csp], #32
    LDP      c29, c30, [csp], #32
  #else
    //restore the stack
    LDP      x0, x1, [sp], #16
    LDP      x2, x3, [sp], #16
    LDP      x4, x5, [sp], #16
    LDP      x6, x7, [sp], #16
    LDP      x8, x9, [sp], #16
    LDP      x10, x11, [sp], #16
    LDP      x12, x13, [sp], #16
    LDP      x14, x15, [sp], #16
    LDP      x16, x17, [sp], #16
    LDP      x18, x19, [sp], #16
    LDP      x29, x30, [sp], #16
  #endif

  ERET
  //removes warning: could not determine size of cap reloc against function (in GOT)
  //place after RET to get size of function
  .size syncVectorHandler, . - syncVectorHandler
//*****************************************************************************
