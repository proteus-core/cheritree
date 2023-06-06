/*
 ============================================================================
 Name        : enclaveIDManager.h
 Author      : CAP-TEE
 Version     :
 Copyright   : CAP-TEE 2022
 Description : header file for Enclave ID counter
 ============================================================================
 */
#ifndef __enclaveIDManager_h
#define __enclaveIDManager_h

//*****************************************
// DEFINES AND INCLUDES
//*****************************************
//------------------------------------------
//Define parameters for enclave ID counter
//------------------------------------------
//As per proteus values
#define OTYPE_RANGE_START 0
#define OTYPE_RANGE_END 1024

//********************************************
// FUNCTIONS
//********************************************
//initialise the counter
int initIDCounter();
//generate a temporary enclave ID to go in the table
int generateEnclaveID();

#endif
