/*
 ============================================================================
 Name        : EINIT_DATA.c
 Author      : CAP-TEE
 Version     :
 Copyright   : CAP-TEE 2022
 Description : EInitdata instruction top level
 	 	 	   This code uses the cheri API and needs to be compiled for purecap
 ============================================================================
 */

//*****************************************
// DEFINES AND INCLUDES
//*****************************************

//system/lib includes
#include <cheriintrin.h>
//#include <cheri.h>
//program includes
#include <common/capfuncs.h>
#include <EL2Code/instructions/enclaveid.h> //idType
#include <EL2Code/instructions/enclaveIDManager.h>
#include <EL2Code/instructions/enclaveIDManager.h>
#include <EL2Code/instructions/hash.h>
#include <EL2Code/instructions/identityStore.h>
#include <EL2Code/instructions/sealingCapability.h>

//EL1N memory space to check

//THIS IS CURRENTLY SET AS A GLOBAL FOR EL2
//CONSIDER CREATING LOCALLY DUE TO GLOBAL ACCESS
extern void* MEM_EL1N_AT_EL2N;

extern int sweep(void* code_cap, void* data_cap, void* cspReg, void* EL1mem_cap);

//********************************************
// FUNCTIONS
//********************************************
//--------------------------------------------
//EINIT_DATA
//EInitData instruction top level
//--------------------------------------------
//E_INIT_DATA steps:
//1. Get the o-type of sealed_code_cap
//2. Check if temporary entry exists with ID matching the ID derived from the o-type of sealed_code_cap
//3. If OK unseal sealed_code_cap
//4. Do memory and register sweep
//5. Verify code_cap does not contain any capabilities
//6. Calculate enclave identity as the hash of the contents of code_cap (enclave code section).
//7. Store hash in the temp entry and mark as permanent
//8. Store cap seals in the first address of data_cap 'signEncSeal'
//9. Seal data_cap with identSeal (o_entry) and return sealed_data_cap
//--------------------------------------------
//Inputs: sealed code_cap, unsealed data_cap, stack pointer address of saved EL1 registers
//Output: sealed data_cap
void* EINIT_DATA(void* sealed_code_cap, void* data_cap, void* cspReg)
{
	//1. get the o-type of code_cap_mod
	idType otypeVal = (idType)cheri_type_get(sealed_code_cap); //extend to idType 128 bits

	//2. check if temporary entry exists with id matching the otype of cap_code
	idType id = getUnfinishedEntryID(otypeVal);
    if (id == setInvalidEnclaveID()) //identity store
    	{ return (void*)-1;} //can't find match, so return invalid capability

    //3. If OK unseal code_cap - needed to be able to do the memory sweep
	//TO DO - remove this in EL2
	//needed for creating seals
    //need to get a vaild capability with tag first
	void* root_cap = (void *)cheri_ddc_get(); //get root cap
    //get ident seal (capability, but not a pointer)
    void* seal = identSeal(root_cap, id);
    //void* seal = identSeal(root_cap, 1);
    //unseal code_cap
    void* code_cap = cheri_unseal(sealed_code_cap, seal);

    //TO DO - not included here as EL1/EL2 not set up and need the registers saved on the stack
    //4. Do memory and register sweep
    //5. Verify cap_code does not contain any capabilities
    //if pass continue or fail
    //cspReg saved from vector table
    //TO DO - MAKE MEM_EL1N_AT_EL2N LOCAL ACCESS
    int result_sweep = sweep(code_cap, data_cap, cspReg, MEM_EL1N_AT_EL2N);
    if (result_sweep == -1) { return (void*)-1;} //failed memory sweep, so return invalid capability

    //6. Calculate enclave identity as the hash of the contents of code_cap (enclave code section).
    hashType hash;
    generateHash(&hash, code_cap);

    //7. store hash in the temp entry and mark as permanent
    int result = finishEntry(otypeVal, hash);//identity store
    if (result == -1) { return (void*)-1;} //can't find match, so return invalid capability

    //8. Store cap seals in the first address of data_cap 'signEncSeal'
    //Note: Only stores 1 capability, but the capability contains two seals
    //SEAL1 (sign) = BASE+OFFSET(#0), SEAL2 (enc) = BASE+OFFSET(#1)
    //get signEnc seal (capability, but not a pointer)
    void* signEnc = signEncSeal(root_cap, id);

    //For debug check contents first, read as an unsigned long long to check first seal value
    DG(printf("datacap contents before: %llu\n", *((unsigned long long*)data_cap));)

    //store at data_cap
	//memory contents will be a capability (but not a pointer), but still need to declare as pointer to a pointer
    void** mem_data_cap;
    //assign to data_cap pointer
    mem_data_cap =  (void*)data_cap;
    //write signEnc (capability) to data_cap memory
    *mem_data_cap = signEnc;

    //check can read seal back
   /* asm volatile(
    		"B .\n\t" //stop here and check
    		"MOV c2, %x[data_asm]\n\t"
    		"LDR c9, [%x[data_asm]] \n\t"
    		:
    		:[data_asm] "r" (data_cap)
			:
			);*/

    //For debug check contents after
    DG(printf("datacap contents after stored seal: %llu\n", *((unsigned long long*)data_cap));)

    //9. Seal data_cap with identSeal (o_entry) and return sealed_data_cap
    void* sealed_data_cap = cheri_seal(data_cap,seal);
    return sealed_data_cap;
}
//--------------------------------------------


