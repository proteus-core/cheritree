#include "microbench.h"

#include "cheri.h"
#include "unique_alloc.h"

#include <stdint.h>
#include <stdio.h>

#define COUNT_CYCLES(instructions) ({ \
    uint32_t _start, _end; \
    asm volatile( \
        "rdcycle %[start]\n\t" \
        instructions "\n\t" \
        "rdcycle %[end]\n\t" \
        : [start] "=r"(_start), [end] "=r"(_end) \
    ); \
    _end - _start; \
})

static void __attribute__((unused)) einitcode()
{

    uint32_t cycles1 = COUNT_CYCLES("EInitCode cnull, cnull");
    uint32_t cycles2 = COUNT_CYCLES("EInitCode cnull, cnull");

    printf("1st EInitCode: %u cycles\n", cycles1);
    printf("2nd EInitCode: %u cycles\n", cycles2);
}

static void einidata(size_t code_size, size_t num_caps_in_mem)
{
    if (num_caps_in_mem != 0)
    {
        // Stoe dummy caps in memory (use unique_alloc for alignment).
        capability dummy_cap, dummy_mem;
        cheri_read_ddc(&dummy_cap);
        unique_alloc(&dummy_mem, num_caps_in_mem * CAP_LEN);

        for (size_t i = 0; i < num_caps_in_mem; ++i)
        {
            cheri_sc(&dummy_mem, &dummy_cap);
            cheri_inc_offset(&dummy_mem, CAP_LEN);
        }
    }

    capability code, data;
    unique_alloc(&code, code_size);
    unique_alloc(&data, 128);

    cheri_clear_all_gpcr();

    uint32_t start, end, success;

    asm volatile(
        "LC c1, (%[code])\n\t"
        "LC c2, (%[data])\n\t"
        "SC cnull, (%[code])\n\t"
        "SC cnull, (%[data])\n\t"
        "CAndPerm c2, c2, %[data_perms]\n\t"
        "EInitCode c1, c1\n\t"
        "rdcycle %[start]\n\t"
        "EInitData c2, c1, c2\n\t"
        "rdcycle %[end]\n\t"
        "CGetTag %[success], c2\n\t"
        : [start] "=r"(start), [end] "=r"(end), [success] "=r"(success)
        : [code] "r"(&code), [data] "r"(&data),
          [data_perms] "r"(~(1 << PERM_PERMIT_EXECUTE))
    );

    if (!success)
    {
        puts("EInitData failed");
        return;
    }

    printf("EInitData(code=%u): %u cycles\n", code_size, end - start);
}

static void estoreid()
{
    einidata(64, 64);

    char hash[32];
    capability hash_cap;
    cheri_read_ddc(&hash_cap);
    cheri_set_addr(&hash_cap, (uintptr_t)hash);
    cheri_set_bounds_exact(&hash_cap, sizeof(hash));

    asm volatile("LC ct0, (%0)" :: "r"(&hash_cap));

    // HACK we assume this was the first enclave so its eid is 0
    uint32_t cycles = COUNT_CYCLES("EStoreId zero, zero, ct0");

    printf("EStoreId: %u cycles\n", cycles);
}

void microbench_start()
{
    estoreid();
    einitcode();
    einidata(256, 0);
}
