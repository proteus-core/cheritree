/*
 ============================================================================
 Name        : el2_stg2ForEl1nmmusetup.s
 Author      : CAP-TEE
 Version     :
 Copyright   : CAP-TEE 2021
 Description : Stage 2 translation table for EL1N - controlled by hypervisor
 Limitations : When running on real hardware need to change this code to prefill
 			   table with faults
 ============================================================================
 */

//*****************************************
// SECTION
//*****************************************
// This section needs to go into normal memory region - see linker script
  .section  .NONSECURE_stg2ForEl1nmmusection_ass_el2,"ax"
  .align 3

//*****************************************
// DEFINES
//*****************************************
// There are three types of table entry: (1) fault, (2) block, (3) next table
// Define lower and upper table entry attributes to use
// There is no MAIR register for stage 2 translation as the attributes are
// coded directly in the table
// Attr0 = 1111 = 0xF = Normal, Inner/Outer write back cacheable
// Attr1 = 0000 = 0x0 = Device-nGnRnE

// Lower Block entries
//0x0
.equ LOWBLK_FAULT, 0x0
//Normal memory
//bit[0] - valid entry 1
//bit[1] - block entry 0
//bit[5:2] - memory attribute, Normal, Inner/Outer write back cacheable 1111
//bit[7:6] - S2AP 11 stage 2 read/write access permissions, 01 read only
//bit[9:8] - SH 00
//bit[10] - AF - 1
//bit[11] - 0
// 0100 1111 1101 -> 0x4FD
// 0100 0111 1101 -> 0x47D
.equ LOWBLK_NORMAL_WRT_BCK, 0x000000000000004FD
.equ LOWBLK_NORMAL_WRT_BCK_RO, 0x0000000000000047D //read only
//Device memory
//bit[0] - valid entry 1
//bit[1] - block entry 0
//bit[5:2] - memory attribute, DEVICE_nGnRnE 0000
//bit[7:6] - S2AP 11 read/write access - note opposite to stage 1 which is set to 00 for EL1 read/write access
//bit[9:8] - SH 00
//bit[10] - AF - 1
//bit[11] - 0
// 0100 1100 0001 -> 0x4C1
.equ LOWBLK_DEVICE_nGnRnE,   0x000000000000004C1

// Upper Block entries
// Upper bits set in the Morello default setup, so include here
.equ UPPBLK_HW60,			(1 << 60)	//Hardware Implementation defined bit 60
.equ UPPBLK_HW61,			(1 << 61)   //Hardware Implementation defined bit 61

.equ MMU_TABLE_SIZE, 4096 //4096 bytes - 4k table

// function to set up stage 2 translation for EL1N
.global el2_stg2ForEl1n_mmu


//********************************************
// FUNCTIONS
//*******************************************
//-------------------------------------------
// el2_stg2ForEl1n_mmu
// Set up the mmu for EL1N stage 2 translation
//-------------------------------------------
  .type el2_stg2ForEl1n_mmu, "function"
el2_stg2ForEl1n_mmu:

  // Get base address of stage 2 level 1 table for TTBR0_EL1
  LDR      x0, =TABLE_ADDR_EL1N_STG2
  MSR      VTTBR_EL2, x0

  // Set up VTCR_EL2
  // The VTCR_EL2 is the control register for stage 2 of the translation.
  MOV      x0, #28					//T0SZ[5:0] IPA size The region size is 2(64-T0SZ) bytes. (64-28=36 bits) #28 is dec #0x1C is hex THIS IS SET TO 40BITS 1 TERA BYTE AT EL2

  ORR      x0, x0, #(0x1 << 6)		//SLO[7:6] 0b01 start at level 1 translation, if DS=1, SL2=0

  ORR      x0, x0, #(0x1 << 8)		//IRGN0[9:8] 0b11 Normal memory, Inner Write-Back Read-Allocate No Write-Allocate Cacheable.
  ORR      x0, x0, #(0x1 << 9)
  ORR      x0, x0, #(0x1 << 10)		//ORGN0[11:10] 0b11 Normal memory, Outer Write-Back Read-Allocate No Write-Allocate Cacheable.
  ORR      x0, x0, #(0x1 << 11)
  //-----------------------------------
   ORR      x0, x0, #(0x3 << 12)   // SH0[13:12] 0b00, Non-shareable. ***UPDATED
  									// TG0[15:14] 0b00  4KB granule for VTTBR
   ORR      x0, x0, #(0x1 << 16)	// PS[18:16]PA Physical Address Size.0b001	36 bits, 64GB. THIS IS SET TO 40BITS 1 TERA BYTE AT EL2
  									// VS[19] 0b00 - 8-bit VMID (virtual machine identifier)
  									// RESO[20]
  									// HA[21] 0b0 - Access flag disabled
  									// HD[22] 0b0 - hardware management disabled
  									// RESO[24:23]
  ORR      x0, x0, #(0x1 << 25) 	// HWU059[25]Bit[59] of each stage 2 translation table Block/Page entry can be used by hardware
  ORR      x0, x0, #(0x1 << 26) 	// HWU060[26]Bit[60] of each stage 2 translation table Block/Page entry can be used by hardware
  ORR      x0, x0, #(0x1 << 27)		// HWU061[27]Bit[61] of each stage 2 translation table Block/Page entry can be used by hardware
  ORR      x0, x0, #(0x1 << 28)		// HWU062[28]Bit[62] of each stage 2 translation table Block/Page entry can be used by hardware
  ORR      x0, x0, #(0x1 << 29)		// NSW[29] 0b1 All stage 2 translation table walks for the Non-secure IPA space of the Secure EL1&0 translation regime are to the Non-secure PA space.
  ORR      x0, x0, #(0x1 << 30)		// NSA[30] 0b1 All stage 2 translations for the Non-secure IPA space of the Secure EL1&0 translation regime access the Non-secure PA space.
									// RES1[31]
  ORR      x0, x0, #(0x1 << 32)     //DS[32] 0b1 start at level 1 translation ***UPDATED
         //ORR      x0, x0, #(0x1 << 33)		//SL2[33] 0b0 start at level 1 translation
  									//RESO[63]


  MSR      VTCR_EL2, x0
  ISB

//-----------------------------------------------------------------------------------
  // This table has 5 entries as we are translating back to physical memory

  // EL1N stage 2 translation table for Morello
  // Get address of level 1 table for VTTBR_EL2 (stage 2 translation)
  LDR      x1, =TABLE_ADDR_EL1N_STG2

  #ifdef __CHERI_PURE_CAPABILITY__
    //get default data capability permissions
  	MRS       c15, DDC
    //put x1 value into c1 with default permissions
  	SCVALUE   c1, c15, x1
 	//change bounds
 	// size of table allocated in memory is 4096 bytes
 	MOV x3, #MMU_TABLE_SIZE //set length
 	SCBNDSE c1,c1,x3 //set capability bounds
  #endif

   // CAP-TEE Morello - DEVICE
  // (0):  Input IPA 0xC000,0000 - 0xFFFF,FFFF to output PA 0x4000,0000 - 0x7FFF,FFFF
  // Lower Block
  //LDR      x0, =LOWBLK_DEVICE_nGnRnE
  MOV      x0, #LOWBLK_DEVICE_nGnRnE
  // OR with start address of region
  //ORR      x0, x0, #0x40000000 //***MODIFIED
  //0x0 addr
  // put in the table
  #ifdef __CHERI_PURE_CAPABILITY__
    STR      x0, [c1]
  #else
    STR      x0, [x1]
  #endif
  // Upper Block is 0 - 0x0

  // CAP-TEE Morello - FAULT
  // (1):   Input IPA 0x4000,0000 - 0xFFFF,FFFF to output PA FAULT
  // Lower Block
  //LDR      x0, =LOWBLK_FAULT
  //MOV      x0, #LOWBLK_FAULT //***MODIFIED
  MOV      x0, #LOWBLK_DEVICE_nGnRnE //***MODIFIED
  // OR with start address of region
  ORR      x0, x0, #0x40000000 //***MODIFIED
  // put in the table
  #ifdef __CHERI_PURE_CAPABILITY__
  	STR      x0, [c1, #8]
  #else
    STR      x0, [x1, #8]
  #endif
  // Upper Block - 0x0

  // CAP-TEE Morello NORMAL
  // (2):  Input IPA 0x8000,0000 - 0xBFFF,FFFF to output PA 0x8000,0000 - 0xBFFF,FFFF
  // Lower Block
  // fault means ignore
  //LDR      x0, =LOWBLK_NORMAL_WRT_BCK
//****  MOV      x0, #LOWBLK_NORMAL_WRT_BCK
  MOV x0, #LOWBLK_NORMAL_WRT_BCK_RO //read only section
  // LDR      x0, =LOWBLK_NORMAL_WRT_BCK_RO //read only section
  //LDR      x0, =LOWBLK_FAULT
  // OR with start address of region
  ORR      x0, x0, #0x80000000
  // Upper block
  //These need to be included for Morello-purecap otherwise you get a
  //page table permission violation fault on STR when in EL1N, but
  //has no effect in just Morello mode
  // OR Hardware Implementation defined bit 60
  ORR      x0, x0, #UPPBLK_HW60 //***MODIFIED
  // 'OR' Hardware Implementation defined bit 61
  ORR      x0, x0, #UPPBLK_HW61 //***MODIFIED
  // put in the table
  #ifdef __CHERI_PURE_CAPABILITY__
  	STR      x0, [c1, #16]
  #else
    STR      x0, [x1, #16]
  #endif

  // CAP-TEE Morello - NORMAL
  // (3):  Input IPA 0xC000,0000 - 0xFFFF,FFFF to output PA 0xC000,0000 - 0xFFFF,FFFF
  // Lower Block
  //LDR      x0, =LOWBLK_NORMAL_WRT_BCK
  MOV      x0, #LOWBLK_NORMAL_WRT_BCK
  // OR with start address of region
  ORR      x0, x0, #0xC0000000
  // Upper block
  //These need to be included for Morello-purecap otherwise you get a
  //page table permission violation fault on STR when in EL1N, but
  //has no effect in just Morello mode
  // OR Hardware Implementation defined bit 60
  ORR      x0, x0, #UPPBLK_HW60
  // 'OR' Hardware Implementation defined bit 61
  ORR      x0, x0, #UPPBLK_HW61
  // put in the table
  #ifdef __CHERI_PURE_CAPABILITY__
  	STR      x0, [c1, #24]
  #else
  	STR      x0, [x1, #24]
  #endif

  // CAP-TEE Morello DEVICE
  // (4):  Input IPA 0x1,0000,0000 - 0x1,3FFF,FFFF to output PA 0x0000,0000 - 0x3FFF,FFFF
  // Lower Block
  //LDR      x0, =LOWBLK_DEVICE_nGnRnE
  MOV      x0, #LOWBLK_DEVICE_nGnRnE
  // address is 0 - 0x0
  // put in the table
  #ifdef __CHERI_PURE_CAPABILITY__
  	STR      x0, [c1, #32]
  #else
    STR      x0, [x1, #32]
  #endif
  // Upper Block is 0 - 0x0


  // data synchronisation - make sure all data written
  DSB      SY
//--------------------------------------------------------------------------------------------

  // Invalidate TLBs
  // https://developer.arm.com/documentation/101811/0101/Translation-Lookaside-Buffer-maintenance
  // https://developer.arm.com/documentation/den0024/a/The-Memory-Management-Unit/The-Translation-Lookaside-Buffer
  // To change a translation table entry from a previous setup you need to invalidate
  // the Translation Lookaside Buffers (TLBs) otherwise the cache might reuse recently
  // used translations.
  // Don't strictly need this for first set up, but should include if the tables are modified
  // so have left this in for reference
  // ----------------
  TLBI     VMALLS12E1 //	TLB invalidate by IPA, Stage 2, EL1.
  DSB      SY
  ISB

  // Enable MMU - set the System Control Register for EL2 Hypervisor
  MOV      x0, #1                     		 // bit[0]  M=1    Enable MMU stage 2
  ORR      x0, x0, #(1 << 3)                 // bit[3]  FMO - FIQ goes to EL2
  ORR      x0, x0, #(1 << 4)                 // bit[4]  IMO - IRQ goes to EL2
  ORR      x0, x0, #(1 << 5)                 // bit[5]  AMO - SError goes to EL2
												//HCD, bit [29] 0b0 - HVC instruction execution is enabled at EL2 and EL1.
  ORR      x0, x0, #(1 << 31)               // RW=1          lower EL is AArch64
  MSR      HCR_EL2, x0
  ISB
  RET




  //*****************************************
  // SECTION
  //*****************************************
  // ------------------------------------------------------------
  // Stage 2 translation table for EL1N
  // This is where the EL1N stage 2 table is stored in memory
  // ------------------------------------------------------------
  // This section goes into non secure memory region by the linker script
 .section  .NONSECUREttstg2ForEl1nsection_ass_el2,"ax"
  .align 12 //align to 4kbytes boundary 2^12

  .global TABLE_ADDR_EL1N_STG2
TABLE_ADDR_EL1N_STG2:
  .fill MMU_TABLE_SIZE , 1 , 0

