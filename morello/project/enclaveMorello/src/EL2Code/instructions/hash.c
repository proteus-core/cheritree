/*
 ============================================================================
 Name        : hash.c
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
#include <tomcrypt.h> //hashing library
#include <cheriintrin.h>
//program includes
#include <common/capfuncs.h> //turns debug on/off
#include <EL2Code/instructions/enclaveid.h> //idType
#include <EL2Code/instructions/enclaveIDManager.h>
#include <EL2Code/instructions/hash.h>
#include <EL2Code/instructions/identityStore.h>
#include <EL2Code/instructions/sealingCapability.h>
//#include <cheri.h>

//program includes

//********************************************
// FUNCTIONS
//********************************************
//--------------------------------------------
//setZeroHashVal
//set a table entry with zero hash
//--------------------------------------------
//Output:
//table entry with hash written to
//--------------------------------------------
void setZeroHashVal(Entry* entry1)
{
	for (int i=0; i<hashByteWidth; i++) {entry1->hash[i] = 0;} //all zeros
}

//--------------------------------------------
//setRandomHashVal
//set a hash value with 1 -> 32
//--------------------------------------------
//Output:
//hash value
//--------------------------------------------
void setRandomHashVal(hashValType hashVal)
{
for (int i=0; i<hashByteWidth; i++) {hashVal[i] = i+1;} //set 1 -> 32
}

//--------------------------------------------
//copyHashValHash
//copy hash value from table entry
//--------------------------------------------
//Input:
//table entry
//Output:
//hash structure
//--------------------------------------------
void copyHashValHash(hashType* destination, Entry* source)
{
	for (int i=0; i<hashByteWidth; i++) {destination->hash[i] = source->hash[i];} //copy contents
	destination->valid = true; //can't guarantee an invalid hash number so need a valid with it
}

//--------------------------------------------
//copyHashValTable
//copy hash to table entry
//--------------------------------------------
//Input:
//hash structure
//Output:
//table entry
//--------------------------------------------
void copyHashValTable(Entry* destination, hashType* source)
{
	//if (source->valid == true)
	//{
	for (int i=0; i<hashByteWidth; i++) {destination->hash[i] = source->hash[i];} //copy contents
	//}
}

//--------------------------------------------
//generateHash
//generate a hash of the code section using library functions
//--------------------------------------------
//PLACE INTERFACE TO HASHING FUNCTION HERE
void generateHash(hashType* hashStruct, void* code_cap)
{
	//-------------------------------------------
	//MAKE A PROPER HASH
	//get input data to hash
	//32bit instructions(4 bytes) so read 4 bytes at a time
	//should always be in multiples of 4 bytes then
	const int numBytes = 4; //read 4 bytes at a time
	//get the length of the code section
	size_t lengthCode = cheri_length_get(code_cap);
	size_t lengthhash = cheri_length_get(hashStruct->hash)-1; //returns 33, length of struct so need to sub 1(valid)
	//check lengthCode/4 is exactly divisible and hash is 256bits
	size_t lenCheck = lengthCode/numBytes;
	if (!((lengthCode % numBytes == 0) && (lengthhash == hashByteWidth))) {hashStruct->valid = false; return;}

	DG(printf("getting hash....");)
	//----------------------------------------------
	//Hashing library
	hash_state md;
	hashValType newHashVal;

	//setup the hash
	sha256_init(&md);
	//feed in the data 4 bytes at a time (one instruction at a time)
	for (int i=0; i<((lengthCode-numBytes)+1); i=i+numBytes)
	{
	sha256_process(&md, (unsigned char*)(code_cap+i), (unsigned long)numBytes);
	}
	//get the hash out
	sha256_done(&md, newHashVal);
	//----------------------------------------------
	DG(printf("done hash\n");)
	//----------------------------------------------

	//SAVE INTO STRUCTURE
	for (int i=0; i<32; i++)
	{
	*((unsigned char *)hashStruct->hash+i) = newHashVal[i];
	}
	hashStruct->valid = true;

}
//---------------------------------------------------------------------

