/*
 ============================================================================
 Name        : enclaveid.c
 Author      : CAP-TEE
 Version     :
 Copyright   : CAP-TEE 2022
 Description : ID and o-type manipulation, and generation of seals
 ============================================================================
 */

//*****************************************
// DEFINES AND INCLUDES
//*****************************************

//system/lib includes
#include <EL2Code/instructions/enclaveid.h> //idType
#include <EL2Code/instructions/sealingCapability.h> //creating sealing capability
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h> //to use bool/true/false
//program includes

//********************************************
// FUNCTIONS
//********************************************
//--------------------------------------------
//setInvalidEnclaveID
//--------------------------------------------
//Output:
//id value set to all '1's - same as proteus
//--------------------------------------------
idType setInvalidEnclaveID()
{
	idType id;
	id = ~(0); //set to zero and then invert all bits, so all bits set to 1, i.e -1, same as proteus
	return id;
}

//--------------------------------------------
//assignIDFromOtype
// convert any o-type to id value
//--------------------------------------------
//Input:
//o-type
//Output:
//id value set to all '1's - same as proteus
//--------------------------------------------
idType assignIDFromOtype(idType otype)
{
	idType id;
	id = otype >> 2; //right shift by 2
	return id;
}

//--------------------------------------------
//getOtype
// convert id to o-type
//--------------------------------------------
//Input:
// id value
//Output:
// o-type
//--------------------------------------------
idType getOtype(idType id)
{
	idType otype;
	otype = id << 2;
	return otype;
}

//--------------------------------------------
// Create Seals functions
//--------------------------------------------
//from paper
//o_sign -> signSeal   -> id | 0 0
//o_enc -> encSeal     -> id | 0 1
//o_entry -> identSeal -> id | 1 0
//spare -> ?           -> id | 1 1

//--------------------------------------------
//signSeal (o_sign)
//create signSeal sealing capability
//this is not a pointer!
//--------------------------------------------
//Input:
// root_cap - a valid capability with which to derive a sealing capability
// id - ID value
//Output:
// seal capability
//--------------------------------------------
void* signSeal(void* root_cap, idType id)
{
	return createSealingCapability(root_cap, getOtype(id), 1);
}

//--------------------------------------------
//encSeal (o_enc)
//create encSeal sealing capability
//this is not a pointer!
//--------------------------------------------
//Input:
// root_cap - a valid capability with which to derive a sealing capability
// id - ID value
//Output:
// seal capability
//--------------------------------------------
void* encSeal(void* root_cap, idType id)
{
	return createSealingCapability(root_cap, getOtype(id) + 1, 1);
}

//--------------------------------------------
//identSeal (o_entry)
//create identSeal sealing capability
//this is not a pointer!
//--------------------------------------------
//Input:
// root_cap - a valid capability with which to derive a sealing capability
// id - ID value
//Output:
// seal capability
//--------------------------------------------
void* identSeal(void* root_cap, idType id)
{
	return createSealingCapability(root_cap, getOtype(id) + 2, 1);
}

//--------------------------------------------
//signEncSeal
//create signEncSeal sealing capability
//this is not a pointer!
//for both sign and enc seal, only stores 1 value in the base, the other is derived from offset
//seal 1 - signSeal at base addr (#0 offset)
//seal 2 - encSeal base addr + #1 offset
//--------------------------------------------
//Input:
// root_cap - a valid capability with which to derive a sealing capability
// id - ID value
//Output:
// seal capability
//--------------------------------------------
void* signEncSeal(void* root_cap, idType id)
{
	return createSealingCapability(root_cap, getOtype(id), 2);
}

