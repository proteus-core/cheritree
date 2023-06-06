/*
 ============================================================================
 Name        : el2_stg1ForEL1nmmusetup.s
 Author      : CAP-TEE
 Version     :
 Copyright   : CAP-TEE 2021
 Description : translation table for stage 1 EL1N - controlled by hypervisor
 Limitations : When running on real hardware need to change this code to prefill
 			   table with faults
 ============================================================================
 */

//*****************************************
// SECTION
//*****************************************
// This section needs to go into normal memory region - see linker script
  .section  .NONSECURE_stg1ForEl1nmmusection_ass_el2,"ax"
  .align 3

//*****************************************
// DEFINES
//*****************************************
// There are three types of table entry: (1) fault, (2) block, (3) next table
// Define lower and upper table entry attributes to use
// Assuming MAIR register entries are:
// Attr0 = 1110 1110 = 0xEE = Normal, Inner/Outer write back non transient as per Morello Default DRAM0
// Attr1 = 0000 0000 = 0x00 = Device-nGnRnE
// Lower Block entries
.equ LOWBLK_FAULT,           0x0
.equ LOWBLK_NORMAL_NON_TRANS, 0x00000000000000401    // Index = 0 (Attr0), AF=1
.equ LOWBLK_DEVICE_nGnRnE,   0x00000000000000405    // Index = 1 (Attr1), AF=1,

// Index = 0 (Attr0), AF=1, AP=10, read only el1, no access el0
// |0100 1000 00 0 1|
.equ LOWBLK_NORMAL_NON_TRANS_RO, 0x00000000000000481
// Upper Block entries
// Upper bits set in the Morello default setup, so include here
.equ UPPBLK_HW60,			(1 << 60)	//Hardware Implementation defined bit 60
.equ UPPBLK_HW61,			(1 << 61)   //Hardware Implementation defined bit 61

.equ MMU_TABLE_SIZE, 4096 //4096 bytes - 4k table

// function to set up mmu for EL1N
.global el2_stg1ForEl1n_mmu

//********************************************
// FUNCTIONS
//*******************************************
//-------------------------------------------
// el1nmmu
// Set up the mmu for EL1N
//-------------------------------------------
  .type el2_stg1ForEl1n_mmu, "function"
el2_stg1ForEl1n_mmu:

  // Set up the MAIR memory attributes for the block entries
  // Attr0 = 1110 1110 = 0xEE = Normal, Inner/Outer write back non transient as per Morello Default DRAM0
  // Attr1 = 0000 0000 = 0x00 = Device-nGnRnE
  MOV      x0, #0x00000000000000EE
  MSR      MAIR_EL1, x0

  // EL1S translation table for Morello
  // Get address of level 1 table for TTBR0_EL1
  LDR      x1, =TABLE_ADDR_EL1N_STG1

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

  // CAP-TEE Morello - peripheral and expansion regions - device memory
  // (0): input VA 0x0000,0000 - 0x3FFF,FFFF to output IPA 0x1,0000,0000 - 1,3FFF,FFFF
  // Lower Block
  //LDR      x0, =LOWBLK_DEVICE_nGnRnE
  MOV      x0, #LOWBLK_DEVICE_nGnRnE
  // OR with start address of region
  //ORR      x0, x0, #0x100000000 //***MODIFIED
  //addr 0x0
  // put in the table
  #ifdef __CHERI_PURE_CAPABILITY__
    STR      x0, [c1]
  #else
    STR      x0, [x1]
  #endif
  // Upper Block is 0 - 0x0

  // CAP-TEE Morello - peripheral and expansion regions - device memory
  // (1): input VA 0x4000,0000 - 0x7FFF,FFFF to output IPA 0000,0000 - 4000,000
  // Lower Block
  //LDR      x0, =LOWBLK_DEVICE_nGnRnE
  MOV      x0, #LOWBLK_DEVICE_nGnRnE
  // address is 0 - 0x0
  ORR      x0, x0, #0x40000000 //***MODIFIED
  // put in the table
  #ifdef __CHERI_PURE_CAPABILITY__
  	STR      x0, [c1, #8]
  #else
    STR      x0, [x1, #8]
  #endif
  // Upper Block - 0x0

  // This block is in secure memory, so don't include here in the MMU translation
  // CAP-TEE Morello - lower DRAM0 region - ignore memory
  // (2): input VA 0x8000,0000 - 0xBFFF,FFFF to output IPA 0x8000,0000 - 0xBFFF,FFFF
  // Lower Block
  // fault means ignore
  //LDR      x0, =LOWBLK_FAULT
  //LDR      x0, =LOWBLK_NORMAL_NON_TRANS
//****  MOV      x0, #LOWBLK_NORMAL_NON_TRANS
  MOV x0, #LOWBLK_NORMAL_NON_TRANS_RO //el1 read only section
  //LDR      x0, =LOWBLK_NORMAL_NON_TRANS_RO //el1 read only section
  // OR with start address of region
  ORR      x0, x0, #0x80000000
  // Upper block
  //These need to be included for Morello-purecap otherwise you get a
  //page table permission violation fault on STR when in EL1N, but
  //has no effect in just Morello mode
  // OR Hardware Implementation defined bit 60
  ORR      x0, x0, #UPPBLK_HW60
  // 'OR' Hardware Implementation defined bit 61
  ORR      x0, x0, #UPPBLK_HW61
  #ifdef __CHERI_PURE_CAPABILITY__
  	STR      x0, [c1, #16]
  #else
    STR      x0, [x1, #16]
  #endif

  // CAP-TEE Morello - upper DRAM0 region - normal memory
  // (3): Input VA 0xC000,0000 - 0xFFFF,FFFF to output IPA 0xC000,0000 - 0xFFFF,FFFF
  // Lower Block
  //LDR      x0, =LOWBLK_NORMAL_NON_TRANS
  MOV      x0, #LOWBLK_NORMAL_NON_TRANS
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
  #ifdef __CHERI_PURE_CAPABILITY__
  	STR      x0, [c1, #24]
  #else
  	STR      x0, [x1, #24]
  #endif

  DSB      SY

  // Set up TCR_EL1
  // morello default setup for mmu EL1
  // The TCR_EL1 is the control register for stage 1 of the translation.
  MOV      x0, #28					//T0SZ[5:0] - size offset of memory region, (64-28=36) limit to 36 bits
  									//Res[6]
  									//TTBR0--
  									//EPD0[7] TTBR0 turned on
  ORR      x0, x0, #(0x1 << 8)		//IRGN0[9:8] 0b11 Normal memory, Inner Write-Back Read-Allocate No Write-Allocate Cacheable.
  ORR      x0, x0, #(0x1 << 9)
  ORR      x0, x0, #(0x1 << 10)		//ORGN0[11:10] 0b11 Normal memory, Outer Write-Back Read-Allocate No Write-Allocate Cacheable.
  ORR      x0, x0, #(0x1 << 11)
  //-----------------------------------
  									// SH0[13:12] 0b00, Non-shareable.
  									// TG0[15:14] 0b00  4KB granule for TTBR0
  									//TTBR1--
//---ADDED TO REMOVE DEBUGGER MMU WARNINGS---
//   ORR      x0, x0, #(0x1 << 16) 			//T1SZ[21:16] #0X19
 //  ORR      x0, x0, #(0x1 << 19)
 //  ORR      x0, x0, #(0x1 << 20)
//---------------------------------------
  									//A1[22]
  ORR      x0, x0, #(0x1 << 23)		//EPD1[23] disable TTBR1
  									//IRGN1[25:24]
  									//ORGN1[27:26]
  									//SH1[29:28]
//---ADDED TO REMOVE DEBUGGER MMU WARNINGS---
  //ORR      x0, x0, #(0x1 << 31)     //TGI[31:30]  //TTBR1 - granule size 4kB as gives warning in MMU debugger map --- BBB
//------------------------------------------//--
 ORR      x0, x0, #(0x1 << 32)              // IPS[34:32]=0         32-bit IPA space, =001 36 bits 64GB
  									//RES[35]
  									//AS[36]
  									//TB10[37]
  									//TB11[38]
  									//HA[39]
  									//HD[40]
  ORR      x0, x0, #(0x1 << 41)		//HPD0[41]Hierarchical permissions are disabled, bits 25 to 28 are not ignored (i.e bit 59 to 62 of block can be used by hardware).
  									//HPD1[42]
  ORR      x0, x0, #(0x1 << 43) 	//HWU059[43]Bit[59] of each stage 1 translation table Block/Page entry can be used by hardware
  ORR      x0, x0, #(0x1 << 44)		//HWU060[44]Bit[60] of each stage 1 translation table Block/Page entry can be used by hardware
  ORR      x0, x0, #(0x1 << 45)		//HWU061[45]Bit[61] of each stage 1 translation table Block/Page entry can be used by hardware
  ORR      x0, x0, #(0x1 << 46)		//HWU062[46]Bit[62] of each stage 1 translation table Block/Page entry can be used by hardware
  									//HWU159[47]
  									//HWU160[48]
  									//HWU161[49]
  									//HWU162[50]
  									//TB1D0[51]
  									//TB1D1[52]
  									//NFD0[53]
  //---ADDED TO REMOVE DEBUGGER MMU WARNINGS---
  //ORR      x0, x0, #(0x1 << 54)     //NFD1[54]    //Disable table walks from TTBR1
  //------------------------
  									//EOPD0[55]
  									//EOPD1[56]
  									//TCMA0[57]
  									//TCMA1[58]
  									//DS[59] ???????
  									//RES0[63:60]

  MSR      TCR_EL1, x0
  ISB

  // Invalidate TLBs
  // https://developer.arm.com/documentation/101811/0101/Translation-Lookaside-Buffer-maintenance
  // https://developer.arm.com/documentation/den0024/a/The-Memory-Management-Unit/The-Translation-Lookaside-Buffer
  // To change a translation table entry from a previous setup you need to invalidate
  // the Translation Lookaside Buffers (TLBs) otherwise the cache might reuse recently
  // used translations.
  // Don't strictly need this for first set up, but should include if the tables are modified
  // so have left this in for reference
  // ----------------
  TLBI     VMALLE1 //TLB invalidate by VMID, All at stage 1, EL1.
  DSB      SY
  ISB

  // Get base address of level 1 table for TTBR0_EL1
  LDR      x0, =TABLE_ADDR_EL1N_STG1
  MSR      TTBR0_EL1, x0


  // Enable MMU - set the System Control Register for EL1
  MOV      x0, #(1 << 0)                     // bit[0]  M=1    Enable MMU
  ORR      x0, x0, #(1 << 2)                 // bit[2]  C=1    Enable data and caches
  ORR      x0, x0, #(1 << 3)                 // bit[3]  SA 	   Alignment check enabled
  ORR      x0, x0, #(1 << 12)                // bit[12] I=1    Enable instruction fetches for caches
                                             // bit[19] WXN=0
                                             // bit[21] IESB=0
                                             // bit[25] EE=0   little endian
  MSR      SCTLR_EL1, x0
  ISB

  RET

  //*****************************************
  // SECTION
  //*****************************************
  // ------------------------------------------------------------
  // Translation table for stage 1 EL1N
  // This is where the EL1N stage 1 table is stored in memory
  // ------------------------------------------------------------
  // This section goes into non secure memory region by the linker script
  .section  .NONSECUREttstg1ForEl1nsection_ass_el2,"ax"
  .align 12
 //DONT MAKE THIS GLOBAL!
  .global TABLE_ADDR_EL1N_STG1
TABLE_ADDR_EL1N_STG1:
  .fill MMU_TABLE_SIZE , 1 , 0

