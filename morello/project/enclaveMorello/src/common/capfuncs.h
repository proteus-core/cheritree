/*
 ============================================================================
 Name        : capfuncs.h
 Author      : CAP-TEE
 Version     :
 Copyright   : CAP-TEE 2021
 Description : supporting DEBUG functions for purecap mode in trusted EL2/EL3 header file
 ============================================================================
 */
#ifndef __capfuncs_h
#define __capfuncs_h

//turn on and off debug mode turn off: comment out, turn on: leave in
//#define DEBUG 1

#ifdef DEBUG
#define DG(x) x //include x
#define nDG(x) //dont include
#else
#define DG(x) //dont include x
#define nDG(x) x //do include
#endif

//turn on and off printf to uart. turn off: comment out, turn on: leave in
#define PRINTF_TO_UART 1

//------------------------------------------
// supporting functions
//-------------------------------------------

//print capability details
void printcapabilityPar(void * cap, const char* cap_str);

// capability validity check
int capabilityValidCheck(void * cap, const char* cap_str);


#endif
