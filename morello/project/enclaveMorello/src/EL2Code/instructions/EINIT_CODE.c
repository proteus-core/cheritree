/*
 ============================================================================
 Name        : EINIT_CODE.c
 Author      : CAP-TEE
 Version     :
 Copyright   : CAP-TEE 2022
 Description : EInitCode instruction top level
 	 	 	   This code uses the cheri API and needs to be compiled for purecap
 ============================================================================
 */

//*****************************************
// DEFINES AND INCLUDES
//*****************************************

//system/lib includes
#include <cheriintrin.h>
//program includes
#include <common/capfuncs.h>
#include <EL2Code/instructions/enclaveid.h> //idType
#include <EL2Code/instructions/enclaveIDManager.h>
#include <EL2Code/instructions/enclaveIDManager.h>
#include <EL2Code/instructions/identityStore.h>
#include <EL2Code/instructions/sealingCapability.h> //identStore

//********************************************
// FUNCTIONS
//********************************************
//--------------------------------------------
//EINIT_CODE
//EInitCode instruction top level
//--------------------------------------------
//E_INIT_CODE steps:
//1. Get available slot in table
//2. Generate enclave ID from counter
//3. Put ID in table
//4. Generate identSeal from ID
//5. Seal with identSeal and return sealed cap_code
//--------------------------------------------
//Input: unsealed code_cap (capability pointer to an enclave code section)
//Output: sealed code_cap (sealed capability pointer to an enclave code section)
void* EINIT_CODE(void* code_cap)
{

    //need to get a vaild capability with tag first
	void* root_cap = (void *)cheri_ddc_get(); //get root cap

	//1. Get available slot in table
	//2. Generate enclave ID from counter
	//3. Put ID in table and return ID
	//initialise an entry
	idType id = initEntry();//identity store
	if (id == setInvalidEnclaveID()) //identity store
	{ return (void*)-1;} // if ran out of slots/or error return an invalid capability

	//4. Generate identSeal from ID
	//get identSeal (capability, but not a pointer)
	void* seal = identSeal(root_cap, id);
	//printcapabilityPar(seal, "EINIT_CODE.c - identSeal");

	//5. Seal and return sealed_code_cap
	void* sealed_code_cap = cheri_seal(code_cap,seal);
	//printcapabilityPar(sealed_code_cap, "EINIT_CODE.c - sealed_code_cap");

	return sealed_code_cap;
}
//--------------------------------------------



