/*
 ============================================================================
 Name        : capattest.h
 Description : Adapted to work on Morello by CAP-TEE 2021
 ============================================================================
 */
#ifndef CAPATTEST_H
#define CAPATTEST_H

#include <stdint.h>

//riscv
//#include "cheri.h"
/*struct enclave
{
    capability code_cap;
    capability data_cap;
    capability enc_seal;
    capability sign_seal;
};*/

struct enclave
{
    void* code_cap;
    void* data_cap;
    void* enc_seal;
    void* sign_seal;
};

#define ENCLAVE_ID_LEN 32

//struct __attribute__((aligned(4))) enclave_id //align 32 bit
struct __attribute__((aligned(8))) enclave_id //align 64 bit
{
   uint8_t hash[ENCLAVE_ID_LEN];
};

//riscv code
/*int enclave_init(capability* code_cap,
                 capability* data_cap,
                 struct enclave* enclave);*/

int enclave_init(void* code_cap,
        void* data_cap,
        struct enclave* enclave, unsigned long int* numcycles);

int enclave_store_id(const struct enclave* enclave, struct enclave_id* id,unsigned long int* numcyclesA);

//riscv code
/*void enclave_invoke(const struct enclave* enclave,
                    const capability* input,
                    unsigned entry_index,
                    capability* result);*/

unsigned long int enclave_invoke(const struct enclave* enclave,
                    const void* input,
                    unsigned entry_index,
                    void* result);


#endif
