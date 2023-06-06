/*
 ============================================================================
 Name        : capboot.S
 Author      : CAP-TEE
 Version     :
 Copyright   : CAP-TEE 2001
 Description : code that would go in the boot code to set up
 				a global capability for the uart space before DDC
 				is NULLED
 ============================================================================
 */

 //this would go in the boot code


// purecap global

//define uart location in memory
//0xE0000000 (DRAM0 mem)//0x1C090000 (uart base) //0x2A400000 (uart base)
.equ UART_ADDR, 0x1C090000 //0xE0000000 //0x1C090000 //0x2A400000
.equ UART_LENGTH, 0x52 //length of uart space in memory

// extern from global defined in c
// must be extern here - do not do the other way around (extern in c)
// otherwise c can not determine size - get warning at compile time
//.extern GLOBAL_UART_CAP
.global GLOBAL_UART_CAP // error in GLOBAL_UART_CAP size setup before

// function to set up the uart space
.global setGLOBAL_UART_CAP
// function to set DDC
.global el3DDCset


//********************************************
// FUNCTIONS
//*******************************************
//capability global
//-------------------------------------------
// setGLOBAL_UART_CAP
// store capability in memory
// ***this needs to go in boot code before DDC is NULL***
//-------------------------------------------
  .type setGLOBAL_UART_CAP, "function"
setGLOBAL_UART_CAP:

  // pointer to start of CAPABILITY memory location
  // Get address of memory location
  LDR      x2, =GLOBAL_UART_CAP
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
  RET

//-------------------------------------------
// el3DDCset
// Set up the default data capability register
// wouldn't need to do this if in boot code
//-------------------------------------------
  .type el3DDCset, "function"
el3DDCset:
 // #ifdef must be lowercase
 #ifdef __CHERI_PURE_CAPABILITY__
    // set default data capability permissions from c17
    // set to maximum bounds
  	MSR       DDC, c17
 #endif
RET

//normal global test
//*********************************
// function
.global Test
// global variable
.global GLOBAL_x2_SAVED
//-------------------------------------------
// Test
// put 32 in x2 register and save
//-------------------------------------------
Test:
    mov x2, #32
    ldr x0, =GLOBAL_x2_SAVED   //Load address for the global variable
    str x2, [x0]   // save x2 to global variable

    RET

// For ARM, a word is 32-bits (4 bytes).
// A dword is 64-bits (8 bytes)
// GLOBAL_x2_SAVED:          .word
GLOBAL_x2_SAVED:
.fill 4 , 1 , 0

//dont need this if define global in c as automatically gets put in .bss
//if define global in assembly need this as need to specify location in memory
.section .bss //force capability to go in .bss section otherwise doesn't work
.align 4 //ensure align to 16 byte boundary (2^4 = 16), gets passed str ESR mem alignment issue
GLOBAL_UART_CAP:
//.fill 16 , 1 , 0 // don't use this as generates ld.lld: warning: could not determine size of cap reloc against <unknown kind> (in GOT) GLOBAL_UART_CAP
.dword 0 //needs to be zero if in .bss section
.dword 0
.size GLOBAL_UART_CAP, 16 //need this otherwise generates linker warning over size

