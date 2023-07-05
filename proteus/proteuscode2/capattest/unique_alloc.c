#include "unique_alloc.h"

#include "cheri.h"

static capability heap_cap;

void unique_alloc_init(const capability* heap)
{
    cheri_move(&heap_cap, heap);
    uintptr_t address = cheri_get_addr(&heap_cap);
    uintptr_t aligned_address = (address + CAP_LEN - 1) & ~(CAP_LEN - 1);

    if (aligned_address != address)
    {
        cheri_set_addr(&heap_cap, aligned_address);
        uintptr_t diff = aligned_address - address;
        cheri_set_bounds_exact(&heap_cap, cheri_get_len(&heap_cap) - diff);
    }
}

void unique_alloc(capability* dst, size_t size)
{
    // Round-up size to a multiple of CAP_LEN. This ensures that all allocations
    // stay CAP_LEN aligned.
    size = (size + CAP_LEN - 1) & ~(CAP_LEN - 1);

    // Allocate from the beginning of heap_cap.
    cheri_move(dst, &heap_cap);
    cheri_set_bounds_exact(dst, size);

    // Shrink heap_cap.
    cheri_set_offset(&heap_cap, size);
    cheri_set_bounds_exact(&heap_cap, cheri_get_len(&heap_cap) - size);
}
