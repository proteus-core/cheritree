/*
 ============================================================================
 Name        : cheri_extra.h
 Author      : CAP-TEE
 Version     :
 Copyright   : CAP-TEE 2021
 Description : supporting defines for cheri - Morello enclave design, header file
 ============================================================================
 */
#ifndef __cheri_extra_h
#define __cheri_extra_h

#define CAP_LEN 16 //16 bytes
#define __morello_xlen 8 //64 bit integer register length needs to be in bytes(8)

//Note:can't include cheriintrin.h in assembly files as will error on the syntax
//so can't include the CHERI_PERMS for the assembly, include this file: cheri_extra.h instead
// change permissions
// [17] load
// [16] store
// [15] execute
// [14] load cap
// [13] store cap
// [12] store local cap
// [11] seal
// [10] unseal
// [9] system
// [8] branch sealed pair
// [7] compartment ID
// [6] mutable load
// [5:2] User[4]
//Note: Morello different to riscv
#define PERM_PERMIT_LOAD 17
#define PERM_PERMIT_STORE 16
#define PERM_PERMIT_EXECUTE 15
#define PERM_PERMIT_LOAD_CAPABILITY 14
#define PERM_PERMIT_STORE_CAPABILITY 13
#define PERM_PERMIT_STORE_LOCAL_CAPABILITY 12
#define PERM_PERMIT_SEAL 11
#define PERM_PERMIT_UNSEAL 10
#define PERM_PERMIT_SYSTEM 9
#define PERM_PERMIT_BRANCH_SEALED_PAIR 8
#define PERM_PERMIT_CID 7
#define PERM_PERMIT_MUTABLE_LOAD 6

//HVC Calls:
//New instruction defines for HVC calls
#define HVC_EINITCODE 1
#define HVC_EINITDATA 2
#define HVC_ESTOREID 3
//part instructions for testing
#define HVC_REGSWEEP 5 //sweep registers only
#define HVC_MEMSWEEP 6 //sweep memory only
#define HVC_SWEEP 7 //sweep both memory and registers

#endif
