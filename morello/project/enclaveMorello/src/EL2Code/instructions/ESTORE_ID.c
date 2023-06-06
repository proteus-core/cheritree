/*
 ============================================================================
 Name        : ESTORE_ID.c
 Author      : CAP-TEE
 Version     :
 Copyright   : CAP-TEE 2022
 Description : EStoreID instruction top level
 	 	 	   This code uses the cheri API and needs to be compiled for purecap
 ============================================================================
 */

//*****************************************
// DEFINES AND INCLUDES
//*****************************************

//system/lib includes
#include <cheriintrin.h>
//program includes
#include <common/capfuncs.h> //turns debug on and off
#include <common/cheri_extra.h>
#include <EL2Code/instructions/enclaveid.h> //idType
#include <EL2Code/instructions/enclaveIDManager.h>
#include <EL2Code/instructions/enclaveIDManager.h>
#include <EL2Code/instructions/identityStore.h>
#include <EL2Code/instructions/sealingCapability.h>

//********************************************
// FUNCTIONS
//********************************************
//--------------------------------------------
//ESTORE_ID
//EStoreID instruction top level
//--------------------------------------------
//ESTORE_ID steps
//1. Do some checks on the memHash_cap capability to ensure there is enough room
// to store the hash.
//2. Use the input o-type (via normal integer register) to get corresponding hash (enclave identity) from table.
//3. Write hash to a structure in memory via the memHash_cap capability that points to it.
//4. Write boolean success or failure to result via normal integer register.
//--------------------------------------------
//Inputs: any o-type, capability pointing to a hash memory structure
//Output: boolean success or failure
bool ESTORE_ID(size_t any_otype, hashValType* memHash_cap)
{
	//1. Do some checks on the memHash_cap capability to ensure there is enough room
	// to store the hash.
	//check cap is not sealed
	 bool sealedCheck = cheri_is_sealed(memHash_cap);
	 bool tagCheck = cheri_tag_get(memHash_cap);
	//check perms.store is available
	 size_t mask = (1 << PERM_PERMIT_STORE);
	 size_t permsCheck = cheri_perms_get(memHash_cap);
	//check length-offset (in bytes)  >= hashwidth/8bits (to give bytes)
	 size_t lengthCheck = cheri_length_get(memHash_cap) - cheri_offset_get(memHash_cap);
	 int hashwidthBytes = sizeof(hashValType); //should be 32 bytes for sha256

	 //DEBUG printing
	 DG(printf("checking hash cap...\n");)
	 DG(printf("sealedCheck: %u\n",(int)sealedCheck);)
	 DG(printf("tagCheck: %u\n",(int)tagCheck);)
	 DG(printf("permsCheck: 0x%lx\n",permsCheck);)
	 DG(printf("lengthCheck: 0x%lx\n",lengthCheck);)
	 DG(printf("hashwidthBytes: %u\n",hashwidthBytes);)



	 if (!(sealedCheck==false && (permsCheck & mask) && lengthCheck >= hashwidthBytes))
	// {return false;}
	{
		 DG(printf("failed memHash check\n");)

		 return false;
	}
	 //otherwise continue
	 DG(printf("passed memHash check\n");)


	 DG(if (tagCheck == false) {printf("invalid memHash tag\n");}) //debug mode


	//2. Use the input o-type (via normal integer register) to get corresponding hash (enclave identity) from table.
	hashType hash;
	idType otypeVal = (idType)any_otype;
	hash =  getHashEntry(otypeVal);
	//check if hash is valid, if not return false to result
	if (hash.valid == false) {return false;} //return false to result

	//3. Write hash to a structure in memory via the memHash_cap capability that points to it.
	//save in hash memory space 1 byte at a time
	for (int i=0; i<32; i++)
	{
	*((unsigned char *)memHash_cap+i) = hash.hash[i];
	}

	//debug print hash
	#ifdef DEBUG
		printf("id: ");
		for (int i=0; i<32; i++)
			{
			printf(" %02x", hash.hash[i]);
			}
		printf("\n\n");
    #endif

	//4. Write boolean success or failure to result via normal integer register.
	{return true;}
}
//--------------------------------------------



