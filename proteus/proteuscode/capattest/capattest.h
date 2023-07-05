#ifndef CAPATTEST_H
#define CAPATTEST_H

#include <stddef.h>
#include <stdint.h>

#include "cheri.h"

struct enclave
{
    capability code_cap;
    capability data_cap;
    capability enc_seal;
    capability sign_seal;
};

#define ENCLAVE_ID_LEN 32

struct __attribute__((aligned(4))) enclave_id
{
    uint8_t hash[ENCLAVE_ID_LEN];
};

int enclave_init(capability* code_cap,
                 capability* data_cap,
                 struct enclave* enclave);

int enclave_store_id(const struct enclave* enclave, struct enclave_id* id);

void enclave_invoke(const struct enclave* enclave,
                    const capability* input,
                    unsigned entry_index,
                    capability* result);

#endif
