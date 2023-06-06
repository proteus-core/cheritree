/*
 ============================================================================
 Name        : enclaveid.h
 Author      : CAP-TEE
 Version     :
 Copyright   : CAP-TEE 2022
 Description : header file for ID and o-type manipulation, and generation of seals
 ============================================================================
 */
#ifndef __enclaveid_h
#define __enclaveid_h

//*****************************************
// DEFINES AND INCLUDES
//*****************************************
//define type for enclave id
//TO DO - CHECK IF 128 BITS IS CORRECT
//On 64 bit processor unsigned long long is only 8 bytes (64 bits), same as unsigned long
//core.scala specifies IdentityStore as idSize 128bits, but can't see where idSize is actually used in code?
typedef unsigned long long idType; //128bits specified in proteus, but only 10 bits used in Proteus?


//********************************************
// FUNCTIONS
//********************************************
//set an invalid id value, used for initialising the table
idType setInvalidEnclaveID();
//convert o-type to id value
idType assignIDFromOtype(idType otype);
//convert id to o-type
idType getOtype(idType id);

//create an ident seal capability
void* identSeal(void* root_cap, idType id);
//create a sign seal capability
void* signSeal(void* root_cap, idType id);
//create an enc seal capability
void* encSeal(void* root_cap, idType id);
//create a sign&Enc seal capability
void* signEncSeal(void* root_cap, idType id);

#endif
