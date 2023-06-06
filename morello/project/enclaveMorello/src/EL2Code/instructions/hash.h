/*
 ============================================================================
 Name        : hash.h
 Author      : CAP-TEE
 Version     :
 Copyright   : CAP-TEE 2022
 Description :
 ============================================================================
 */
#ifndef __hash_h
#define __hash_h

//*****************************************
// DEFINES AND INCLUDES
//*****************************************

//system/lib includes
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h> //to use bool/true/false

//#include <EL2Code/instructions/identityStore.h> //Entry

#define hashByteWidth 32 //256bits, 32 bytes

typedef unsigned char hashValType[hashByteWidth]; //hash value stored as character array

//define structure type for hash
typedef struct hashStruct {
	bool valid;
	hashValType hash;
} hashType;


//********************************************
// FUNCTIONS
//********************************************
//FUNCTIONS EXTERNED AS COMPILER NOT RECOGNISE ENTRY? - see identityStore.c
//REASON - CIRCULAR INCLUSION OF HEADER FILE - NEEDS FIXING
//sets hash val to zeros
//void setZeroHashVal(Entry* entry1);
//void copyHashValHash(hashType* destination, Entry* source)
//void copyHashValTable(Entry* destination, hashType* source)


void setRandomHashVal(hashValType hashVal);
void generateHash(hashType* hashStruct, void* code_cap);

#endif
