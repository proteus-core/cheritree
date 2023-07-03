/*
 ============================================================================
 Name        : unique_alloc.h
 Description : Adapted to work on Morello by CAP-TEE 2021
 	 	 	 : unique allocation of enclave memory
 ============================================================================
 */

#ifndef __unique_alloc_h
#define __unique_alloc_h

#include <stdio.h>
#include <stdlib.h>
#include <cheriintrin.h>

int unique_alloc_init(void** heap); //same as proteus setup

int unique_alloc(void** dst, size_t size); //same as proteus setup

#endif
