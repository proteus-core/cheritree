 /*
 ============================================================================
 Name        : exceptionHandlerFuncsEL1Nass.S
 Author      : CAP-TEE
 Version     :
 Copyright   : CAP-TEE 2021
 Description : exception handler assembly functions for EL1N
 ============================================================================
 */

 //****************************************************************************
 // SECTION AND DEFINES
 //****************************************************************************
  // need to put into same memory space as exception handler functions by linker script
  // otherwise too far away in memory when in capability mode and tries to branch to wrong address
  // FFFFFFFFFC0000419 instead of just C0000419
 .section .NONSECUREhandlerFuncSectionEL1_c_el2, "ax"

 .align 4 //128 bit/16 byte boundary

 // function to get the exception information for EL1N
 .global readESREL1N


//***********************************************************
 // FUNCTIONS
 //***********************************************************
  //----------------------------------------------------------------------------
 // readESREL1N
 // Description: Get the exception information for EL1
 //----------------------------------------------------------------------------
  .type readESREL1N, "function"
readESREL1N:
  // Holds syndrome information for an exception taken to EL1.
  // Read this to get exception information
  MRS       x0, ESR_EL1  //Exception Syndrome Register, EL1
  RET
  .size readESREL1N, . - readESREL1N
