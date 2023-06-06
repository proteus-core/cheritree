/*
 ============================================================================
 Name        : EL1debug.h
 Author      : CAP-TEE
 Version     :
 Copyright   : CAP-TEE 2021
 Description : supporting EL1 DEBUG functions for purecap mode header file
 ============================================================================
 */
#ifndef __EL1debug_h
#define __EL1debug_h

//to turn off printing debug for EL1 comment out the line below
//#define DEBUG_EL1 1

#ifdef DEBUG_EL1
#define DG1(x) x //include x
#define nDG1(x) //dont include
#else
#define DG1(x) //dont include x
#define nDG1(x) x //do include
#endif

//turn on and off printf to uart. turn off: comment out, turn on: leave in
#define PRINTF_TO_UART_EL1 1

#include <EL1Code/enclavecode/capattest.h> //defines enclave structure used below
//------------------------------------------
// supporting functions
//-------------------------------------------
void printcapabilityPar_EL1(void * cap, const char* cap_str);
void print_cap_debug_EL1(void * cap, const char* cap_str);
// enclave validity check
void print_enclave_debug_EL1(struct enclave* enclave);
// capability validity check
int capabilityValidCheck_EL1(void * cap, const char* cap_str);

#endif

