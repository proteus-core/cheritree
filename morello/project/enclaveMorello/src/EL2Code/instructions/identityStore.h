/*
 ============================================================================
 Name        : identityStore.h
 Author      : CAP-TEE
 Version     :
 Copyright   : CAP-TEE 2022
 Description :
 ============================================================================
 */
#ifndef __identityStore_h
#define __identityStore_h

//*****************************************
// DEFINES AND INCLUDES
//*****************************************

//program includes
#include <EL2Code/instructions/enclaveid.h> //idType
#include <EL2Code/instructions/hash.h> //hashType

//define maximum number of table entries
//---------------------------------------------------------------
//BENCHMARK -need greater number of entries for an internal benchmark loop
//include in preprocessor settings for assembler and compiler with -D
//BENCHMARK1 - measures from el1 only t4,t5,t6,t7,t10,t11
//BENCHMARK2 - measures operations for el2 that causes conflicts above in
//             starting and stopping the timer t1,t2,t3,t8,t9
#if defined(BENCHMARK1) || defined(BENCHMARK2)
 #define MAX_ENTRIES 1024 //set bigger table size
#else
 #define MAX_ENTRIES 32 //set in proteus as 32
#endif
//---------------------------------------------------------------
//define a table entry structure
typedef struct EntryStruct {
    int index; 			   	//entry index number
    bool used;			   	//indicates if the entry is being used or not
    bool ready;			    //indicates the entry is complete and ready to use
    idType id; //128bits	//id is eid
    hashValType hash;	    //hash is the Identity
} Entry;

//********************************************
// FUNCTIONS
//********************************************
//initialise the table
void initTable();
//initialise an entry
idType initEntry();
//get an unfinished id entry
idType getUnfinishedEntryID(idType otypeVal);
//finish an entry - store hash in table
int finishEntry(idType otypeVal, hashType hash);
//get the hash of the corresponding otypeVal;
hashType getHashEntry(idType otypeVal);

#endif
