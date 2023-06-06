/*
 ============================================================================
 Name        : sealingCapability.c
 Author      : CAP-TEE
 Version     :
 Copyright   : CAP-TEE 2022
 Description :
 ============================================================================
 */

//*****************************************
// DEFINES AND INCLUDES
//*****************************************

//standard includes
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h> //to use bool/true/false
#include <cheriintrin.h>
//#include <cheri.h>

//program includes
#include <common/cheri_extra.h> //XREG_LEN

//********************************************
// FUNCTIONS
//********************************************
//--------------------------------------------
//createSealingCapability
//--------------------------------------------
//This function creates a capability where the seal is stored in the address field of the capability
//This capability will be used later to seal another capability where the seal (address field) of this
//capability is used to set the otype of the other capability
//Note: In this instance a seal is not a pointer because the base is not an address, but a seal value.
//This is not a sealed capability
//Inputs:
//root_cap - valid capability with tag used to derive new sealing capability
//seal - seal value that gets put in the base address
//numSeals - number of seals, used to determine length of capability
void* createSealingCapability(void* root_cap, size_t seal, size_t numSeals)
{
	void* seal_cap;

    //Note:
	//when numseals =1 the length is 1, so there is only 1 seal, where seal = base+offset = base + 0
	//when numseals =2 the length is 2, so there are 2 seals available to use (but only 1 value written
	//to the base), where seal1 = base+offset = base + 0, seal2 = base + offset = base + 1

	//use a root capability to get a capability with a valid tag
	seal_cap = cheri_address_set(root_cap, seal);
	//set the bound length to the number of seals
	seal_cap = cheri_bounds_set_exact(seal_cap, numSeals);
	//do a bitwise OR to only keep the seal and unseal permissions
	seal_cap = cheri_perms_and(seal_cap, (CHERI_PERM_SEAL | CHERI_PERM_UNSEAL));
	//set default otype to unseal - don't need to do this as unsealed by default

	return seal_cap;

}


