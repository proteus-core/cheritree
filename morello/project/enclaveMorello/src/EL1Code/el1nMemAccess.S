/*
 ============================================================================
 Name        : el1nMemAccess.s
 Author      : CAP-TEE
 Version     :
 Copyright   : CAP-TEE 2021
 Description : Functions to try to change the mmu memory settings at EL1
 			 : For testing to make sure EL2 has full control over EL1 and it's memory
 			 : used by test_EL1Nentry.c
 ============================================================================
 */

//*****************************************
// SECTION
//*****************************************
// This section needs to go into normal memory region - see linker script
  .section  .NONSECUREel1ntestsection_ass_el1,"ax"
  .align 3

//*****************************************
// DEFINES
//*****************************************


// function to change MAIR reg
.global el1MAIRmod
// function to modify the translation table in memory using register
.global el1TTmod
// function to modify the translation table in memory by knowing the address
.global el1TTMemMod
// function to modify the EL1N vector table in memory using register
.global el1VTmod
// function to modify the EL1N vector table in memory by knowing the address
.global el1VTMemMod
// function to change TCR reg
.global el1TCRmod
// function to change SCTLR reg
.global el1SCTLRmod
// function to invalidate TLB
.global el1TLBmod

//********************************************
// FUNCTIONS
//*******************************************

//-------------------------------------------
// el1MAIRmod
// function to change MAIR reg
//-------------------------------------------
  .type el1MAIRmod, "function"
el1MAIRmod:
  // Set up the MAIR memory attributes for the block entries
  // Attr0 = 1110 1110 = 0xEE = Normal, Inner/Outer write back non transient as per Morello Default DRAM0
  // Attr1 = 0000 0000 = 0x00 = Device-nGnRnE
  MOV      x0, #0x00000000000000EE
  MSR      MAIR_EL1, x0
  RET
//removes warning: could not determine size of cap reloc against function (in GOT)
//place after RET to get size of function
.size el1MAIRmod, . - el1MAIRmod
//-------------------------------------------
// el1TTMemMod
// function to modify the translation table in memory
// by having a guess / knowing where the tables are stored
//-------------------------------------------
  .type el1TTMemMod, "function"
el1TTMemMod:
  //first take an accurate guess / or know address of where
  //tables stored in memory
  LDR      x1, =0xA00f0000 //read only address set by mmu
  // write over contents at that address
  LDR      x0, =0x00000000000000444
  // OR with start address of region
  ORR      x0, x0, #0x100000000
  //THIS WILL ONLY WORK IF DDC NOT NULL
  //if read only, will cause exception to EL1
  // put in the table
  #ifdef __CHERI_PURE_CAPABILITY__
    //get default data capability permissions
  	MRS       c15, DDC
    //put x1 value into c1 with default permissions
  	SCVALUE   c1, c15, x1
  	STR      x0, [c1]
  #else
    STR      x0, [x1]
  #endif
  RET
//removes warning: could not determine size of cap reloc against function (in GOT)
//place after RET to get size of function
.size el1TTMemMod, . - el1TTMemMod

//-------------------------------------------
// el1TTMemMod
// function to modify the vector table in memory
// by having a guess / knowing where the tables are stored
//-------------------------------------------
  .type el1VTMemMod, "function"
el1VTMemMod:
  //first take an accurate guess / or know address of where
  //tables stored in memory
  LDR      x1, =0xA00f2000 //read only address set by mmu
  // write over contents at that address
  LDR      x0, =0x00000000000044444
  //THIS WILL ONLY WORK IF DDC NOT NULL
  //dissassembly is transformed x1 to c1 automatically if DDC not null, or can write in full here
  // put in the table
  #ifdef __CHERI_PURE_CAPABILITY__
    //get default data capability permissions
  	MRS       c15, DDC
    //put x1 value into c1 with default permissions
  	SCVALUE   c1, c15, x1
  	STR      x0, [c1]
  #else
    STR      x0, [x1]
  #endif
  RET
//removes warning: could not determine size of cap reloc against function (in GOT)
//place after RET to get size of function
.size el1VTMemMod, . - el1VTMemMod

//-------------------------------------------
// el1TTmod
// function to modify the translation table in memory
// using the TTBR0 register
//-------------------------------------------
  .type el1TTmod, "function"
el1TTmod:
  //first, get memory address of translation table
  MRS      x1, TTBR0_EL1
//  // write over contents at that address
  LDR      x0, =0x00000000000044444
  // put in the table
  //THIS WILL ONLY WORK IF DDC NOT NULL
  //dissassembly is transformed x1 to c1 automatically if DDC not null, or can write in full here
    //#ifdef __CHERI_PURE_CAPABILITY__
    //get default data capability permissions
    //  MRS       c15, DDC
    //put x1 value into c1 with default permissions
    //  SCVALUE   c1, c15, x1
  	//  STR      x0, [c1]
    //#else
    //  STR      x0, [x1]
    //#endif
  //This will fail on a memory write because read only
  //STR      x0, [x1]
  RET
//removes warning: could not determine size of cap reloc against function (in GOT)
//place after RET to get size of function
.size el1TTmod, . - el1TTmod

//-------------------------------------------
// el1VTmod
// function to modify the translation table in memory
// using the VBAR_EL1 register
//-------------------------------------------
  .type el1VTmod, "function"
el1VTmod:
  //first, get memory address of vector table
  MRS      x0, VBAR_EL1
  //change where point to
  LDR 	   x0, =0x80000000
  //resave
  MSR      VBAR_EL1, x0
  RET
//removes warning: could not determine size of cap reloc against function (in GOT)
//place after RET to get size of function
.size el1VTmod, . - el1VTmod


//-------------------------------------------
// el1MAIRmod
// function to change TCR reg
//-------------------------------------------
  .type el1TCRmod, "function"
el1TCRmod:
  MRS 	   x0, TCR_EL1
  ORR      x0, x0, #(0x1 << 7)		//EPD0[7] TTBR0 turn off
  MSR      TCR_EL1, x0
  ISB
  RET
//removes warning: could not determine size of cap reloc against function (in GOT)
//place after RET to get size of function
.size el1TCRmod, . - el1TCRmod

//-------------------------------------------
// el1SCTLRmod
// function to change SCTLR reg
//-------------------------------------------
  .type el1SCTLRmod, "function"
el1SCTLRmod:
  MRS 	   x0, SCTLR_EL1
  MOV      x0, #(1 << 0) //try to turn on/off mmu 1 is on, 0 is off
  MSR      SCTLR_EL1, x0
  ISB
  RET
//removes warning: could not determine size of cap reloc against function (in GOT)
//place after RET to get size of function
.size el1SCTLRmod, . - el1SCTLRmod

//-------------------------------------------
// el1SCTLRmod
// function to invalidate TLB
//-------------------------------------------
  .type el1TLBmod, "function"
el1TLBmod:
  TLBI     VMALLE1 //TLB invalidate by VMID, All at stage 1, EL1.
  DSB      SY
  ISB
  RET
//removes warning: could not determine size of cap reloc against function (in GOT)
//place after RET to get size of function
.size el1TLBmod, . - el1TLBmod
