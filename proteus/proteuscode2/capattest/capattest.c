#include "capattest.h"
#include "cheri.h"
#include "unique_alloc.h"

#include "stdint.h"
#include "stdlib.h"
#include <stdio.h>

int enclave_init(capability* code_cap,
                 capability* data_cap,
                 struct enclave* enclave)
{
    capability c31;
    cheri_move_from_reg(&c31, "c31");

    cheri_clear_all_gpcr();

    asm volatile(
        "LC ca0, (%[code_cap_in])\n\t"
        // Clear the given code capability
        "SC cnull, (%[code_cap_in])\n\t"
        "EInitCode ca0, ca0\n\t"
        // Set ca1 to the enclave's data section
        "LC ca1, (%[data_cap_in])\n\t"
        // Clear the data capability on the stack
        "SC cnull, (%[data_cap_in])\n\t"
        // The data capability shouldn't be executable or CInvoke will fail
        "CAndPerm ca1, ca1, %[data_perms]\n\t"
        "EInitData ca1, ca0, ca1\n\t"
        // Store the results of EInitCode/EInitData
        "SC ca0, (%[code_cap])\n\t"
        "SC ca1, (%[data_cap])\n\t"
        // Set the return address for the enclave invocation
        "CSpecialR ct0, ddc\n\t"
        "la t0, 1f\n\t"
        "CSetAddr cra, ct0, t0\n\t"
        // Invoke to get the seals. This also passes the sealed entry
        // capabilities in ca0/ca1.
        "mv a7, zero\n\t"
        "CInvoke ca0, ca1\n\t"
        "1:\n\t"
        // Store the seals
        "SC ca0, (%[enc_seal])\n\t"
        "SC ca1, (%[sign_seal])\n\t"
        :
        : [code_cap_in] "r"(code_cap),
          [data_cap_in] "r"(data_cap),
          [data_perms]  "r"(~(1 << PERM_PERMIT_EXECUTE)),
          [code_cap]    "r"(&enclave->code_cap),
          [data_cap]    "r"(&enclave->data_cap),
          [enc_seal]    "r"(&enclave->enc_seal),
          [sign_seal]   "r"(&enclave->sign_seal)
        : "t0", "a7", "memory"
    );

    cheri_move_to_reg("c31", &c31);

    return 1;
}

int enclave_store_id(const struct enclave* enclave, struct enclave_id* id)
{
    int result;

    asm volatile(
        // FIXME Get root capability from DDC
        "CSpecialR ct0, ddc\n\t"
        // Set ct1 to the hash
        "CSetAddr ct1, ct0, %[hash]\n\t"
        // Load the code capability to get its type
        "LC ct2, (%[code_cap])\n\t"
        "CGetType t0, ct2\n\t"
        "EStoreId %[result], t0, ct1\n\t"
        : [result]   "=r"(result)
        : [hash]     "r"(&id->hash),
          [code_cap] "r"(&enclave->code_cap)
        : "t0", "memory"
    );

    return result;
}

void enclave_invoke(const struct enclave* enclave,
                    const capability* input,
                    unsigned entry_index,
                    capability* result)
{
    capability c31;
    cheri_move_from_reg(&c31, "c31");

    asm volatile(
        // load code/data capabilities in ct0/ct1
        "LC ct0, (%[code_cap])\n\t"
        "LC ct1, (%[data_cap])\n\t"
        // load arguments capability in ca0
        "LC ca0, (%[args_cap])\n\t"
        // entry index is passed in a7
        "mv a7, %[entry]\n\t"
        // Set the return address for the enclave invocation
        "la t0, 1f\n\t"
        "CSpecialR cra, ddc\n\t" // FIXME root capability
        "CSetAddr cra, cra, t0\n\t"
        // invoke enclave
        "CInvoke ct0, ct1\n\t"
        "1:\n\t"
        // store return value
        "SC ca0, (%[result])\n\t"
        :
        : [code_cap] "r"(&enclave->code_cap),
          [data_cap] "r"(&enclave->data_cap),
          [args_cap] "r"(input),
          [entry]    "r"(entry_index),
          [result]   "r"(result)
        : "t0", "a7", "ra", "memory"
    );

    cheri_move_to_reg("c31", &c31);
}
