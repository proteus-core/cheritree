/*
 ============================================================================
 Name        : exceptionHandlerFuncsEL2N.h
 Author      : CAP-TEE
 Version     :
 Copyright   : CAP-TEE 2021
 Description : EL2N exception handler functions header file
 ============================================================================
 */
#ifndef __exceptionHandlerFuncsEL2N_h
#define __exceptionHandlerFuncsEL2N_h

// FUNCTIONS
// sync exception handler to process EL1N register access exceptions
void* syncHandlerEL2N(void* code_cap, void* data_cap, void* cspReg);

#endif
