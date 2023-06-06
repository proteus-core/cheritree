/*
 ============================================================================
 Name        : identityStore.c
 Author      : CAP-TEE
 Version     :
 Copyright   : CAP-TEE 2022
 Description :
 ============================================================================
 */

//*****************************************
// DEFINES AND INCLUDES
//*****************************************

//system/lib includes
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h> //to use bool/true/false
//program includes
#include <EL2Code/instructions/enclaveid.h>
#include <EL2Code/instructions/enclaveIDManager.h> // enclave ID counter for temp IDs
#include <EL2Code/instructions/hash.h>
#include <EL2Code/instructions/identityStore.h>


//ToDo CANT PUT THESE IN HEADER - SAYS  no Entry type
extern void setZeroHashVal(Entry* entry1);
extern void copyHashValHash(hashType* destination, Entry* source);
extern void copyHashValTable(Entry* destination, hashType* source);


//---------------------------------------------------------
//Define TCB table
//---------------------------------------------------------
//define table - 32 entries of struct type Entry
Entry identityStore[MAX_ENTRIES];

//********************************************
// FUNCTIONS
//********************************************
//--------------------------------------------
//initTable
//initialise the table
//--------------------------------------------
void initTable()
{
	int entryIdx; //entry index
	 for (entryIdx = 0; entryIdx < MAX_ENTRIES; entryIdx++)
	 {
		 identityStore[entryIdx].index = entryIdx;
		 identityStore[entryIdx].used = false;
		 identityStore[entryIdx].ready = false;
		 identityStore[entryIdx].id = setInvalidEnclaveID(); //128bits all set to 1
		 //for (int i=0; i<hashByteWidth; i++) {identityStore[entryIdx].hash[i] = 0;} //all zeros
		 setZeroHashVal(&identityStore[entryIdx]);
	 }
}

//--------------------------------------------
//initEntry
//initialise an entry
//--------------------------------------------
idType initEntry()
{
	int entryIdx = 0; //entry index
	//search through table to check next available space
	while (identityStore[entryIdx].used == true)
	{
		entryIdx++;
		//check doesn't exceed max number of entries, or fail
		if (entryIdx > MAX_ENTRIES-1) {return setInvalidEnclaveID();}//{return -1;}
	}
	//available space, so set used, and generate a temporary id value from the enclave id counter
	identityStore[entryIdx].used = true;
	//store in table
	identityStore[entryIdx].id = (idType)generateEnclaveID(); //from enclave id counter, and then extend to 128 bits (idType)
	//return 0;
	return identityStore[entryIdx].id; //and return id
}

//--------------------------------------------
//getUnfinishedEntryID
//Output:
//return the enclave ID in the unfinished entry
//--------------------------------------------
//get unfinished entry id
idType getUnfinishedEntryID(idType otypeVal)
// check if a temporary entry exists
{
	int entryIdx = 0; //entry index
	//search through table to check unfinished entry
	while(!(identityStore[entryIdx].used == true //check entry used
			&& identityStore[entryIdx].ready == false //but not yet complete
			//and check the id matches the id derived from the otype of cap_code
			&& identityStore[entryIdx].id == assignIDFromOtype(otypeVal))) //128bits
	{
		entryIdx++;
		//check doesn't exceed max number of entries, or fail
		if (entryIdx > MAX_ENTRIES-1) {return setInvalidEnclaveID();}//{return -1;}
	}
	//return the enclave ID in the unfinished entry
	return identityStore[entryIdx].id;
}

//--------------------------------------------
//finishEntry
//finish an entry - store hash in table
//Input:
//o-type
//hash to store in the table
//Output:
//0 if successful, -1 if fail
//--------------------------------------------
int finishEntry(idType otypeVal, hashType hash)
{
	int entryIdx = 0; //entry index
	//search through table to check unfinished entry
	while(!(identityStore[entryIdx].used == true //check entry used
			&& identityStore[entryIdx].ready == false //but not yet complete
			//and check the id matches the id derived from the otype of cap_code
			&& identityStore[entryIdx].id == assignIDFromOtype(otypeVal))) //128bits
	{
		entryIdx++;
		//check doesn't exceed max number of entries, or fail
		if (entryIdx > MAX_ENTRIES-1) {return -1;}
	}
	//write hash to table
	//identityStore[entryIdx].hash = hash.hash;
	copyHashValTable(&identityStore[entryIdx], &hash);
	//set ready to true as now complete entry
	identityStore[entryIdx].ready = true;
	//completed ok
	return 0;
}


//--------------------------------------------
//getHashEntry
//get hash entry from table
//Input:
//o-type
//Output:
//hash structure
//--------------------------------------------
hashType getHashEntry(idType otypeVal)
{
	int entryIdx = 0; //entry index
	//return hash from table
	hashType hash;
	//search through table to check unfinished entry
	while(!(identityStore[entryIdx].used == true //check entry used
			&& identityStore[entryIdx].ready == true //and is complete
			//and check the id matches the id derived from the otype of cap_code
			&& identityStore[entryIdx].id == assignIDFromOtype(otypeVal))) //128bits
	{
		entryIdx++;
		//check doesn't exceed max number of entries, or fail
		if (entryIdx > MAX_ENTRIES-1)
		{
			//return invalid hash
			//setZeroHashVal(&hash.hash);
			hash.valid = false; //can't guarantee an invalid hash number so need a valid with it
			return hash;
		}
	}
	copyHashValHash(&hash, &identityStore[entryIdx]);
	return hash;
}

