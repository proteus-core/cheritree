#include "cheri.h"
#include "unique_alloc.h"
#include "trusted_traps.h"

#include <stdint.h>
#include <stdio.h>
#include <string.h>

static struct trap_data non_enclave_trap_data;

void init_capabilities()
{
    // heap_end is the end of regular memory, all the rest will be used for
    // unique_alloc and the trusted trap handler. We'll limit all SCRs to
    // [0, heap_end).
    extern uintptr_t heap_end;

    // Get root capability from DDC
    capability root;
    cheri_read_ddc(&root);

    // Limit regular_mem to [0, heap_end).
    capability regular_mem;
    cheri_move(&regular_mem, &root);
    cheri_set_bounds_exact(&regular_mem, heap_end);
    cheri_and_perm(&regular_mem, ~(1 << PERM_ACCESS_SYSTEM_REGISTERS));

    // Relocate trusted interrupt handler to after the heap. This is needed to
    // be able to have one capability for [0, heap_end). Without it, running
    // capability-unaware C-code is difficult.
    extern char trusted_traps_start, trusted_traps_end;
    size_t trusted_traps_len = &trusted_traps_end - &trusted_traps_start;
    memcpy((void*)heap_end, &trusted_traps_start, trusted_traps_len);

    // Create seal for trusted handler in MTDC
    capability trusted_traps_seal;
    cheri_move(&trusted_traps_seal, &root);

    // FIXME HACK: We just use the maximum available otype. This currently seems
    // secure because the default Proteus build only uses 1024 otypes for
    // enclaves.
    cheri_set_addr(&trusted_traps_seal, (1 << 12) - 17);
    cheri_set_bounds_exact(&trusted_traps_seal, 1);
    cheri_and_perm(&trusted_traps_seal,
                   (1 << PERM_PERMIT_SEAL) | (1 << PERM_PERMIT_UNSEAL));
    cheri_write_mtdc(&trusted_traps_seal);
    cheri_clear_tag(&trusted_traps_seal);

    // Create a capability to the non-enclave trap data and keep it in c31
    // where the trap handler expects it.
    capability trap_data_cap;
    cheri_move(&trap_data_cap, &regular_mem);
    cheri_set_addr(&trap_data_cap, (uintptr_t)&non_enclave_trap_data);
    cheri_set_bounds_exact(&trap_data_cap, sizeof(struct trap_data));
    cheri_move_to_reg("c31", &trap_data_cap);

    // Create capability for the trusted trap handler and store it in MTCC.
    capability trap_handler;
    cheri_move(&trap_handler, &root);
    cheri_set_addr(&trap_handler, heap_end);
    cheri_set_bounds_exact(&trap_handler, trusted_traps_len);
    cheri_write_mtcc(&trap_handler);
    cheri_clear_tag(&trap_handler);

    // Store a null capability in mepcc.
    capability mepcc;
    cheri_get_null(&mepcc);
    cheri_write_mepcc(&mepcc);

    // Set the bounds of pcc
    cheri_write_pcc_bounds(&regular_mem);

    // Create capability for unique_alloc with bounds [trap handler end, ...)
    capability unique_mem;
    cheri_move(&unique_mem, &root);
    uintptr_t root_len = cheri_get_len(&root);
    uintptr_t unique_mem_start = heap_end + trusted_traps_len;
    cheri_set_addr(&unique_mem, unique_mem_start);
    cheri_set_bounds_exact(&unique_mem, root_len - unique_mem_start);
    cheri_and_perm(&unique_mem, ~(1 << PERM_ACCESS_SYSTEM_REGISTERS));
    unique_alloc_init(&unique_mem);

    cheri_write_ddc(&regular_mem);

    // Make sure there no more traces of the root capability
    cheri_clear_tag(&root);
    cheri_clear_tag(&unique_mem);

    printf("Relocated trusted trap handler from %p to %p\n",
           &trusted_traps_start, (void*)heap_end);
    printf("Unique mem starts from %p\n", (void*)unique_mem_start);
}

void trusted_init()
{
    init_capabilities();
}
