/*
 ============================================================================
 Name        : sealingCapability.h
 Author      : CAP-TEE
 Version     :
 Copyright   : CAP-TEE 2022
 Description :
 ============================================================================
 */
#ifndef __sealingCapability_h
#define __sealingCapability_h

//*****************************************
// DEFINES AND INCLUDES
//*****************************************

//standard includes
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h> //to use bool/true/false


//********************************************
// FUNCTIONS
//********************************************
//This function creates a capability where the seal is stored in the address field of the capability
//This capability will be used later to seal another capability where the seal (address field) of this
//capability is used to set the otype of the other capability
void* createSealingCapability(void* root_cap, size_t seal, size_t numSeals);


#endif
