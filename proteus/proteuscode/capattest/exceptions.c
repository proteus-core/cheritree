#include <stdio.h>
#include <stdint.h>

#include "cheri.h"

void exception(long cause)
{
    uint32_t epc;

    asm(
        // since mepc is relative to pcc we use mepcc to get the absolute
        // address
        "CSpecialR ct0, mepcc\n\t"
        "CGetAddr %0, ct0\n\t"
        : "=r"(epc)
    );

    if (cause == CHERI_EXCEPTION_CAUSE)
    {
        uint32_t mccsr;

        asm(
            "csrr %0, mccsr\n\t"
            : "=r"(mccsr)
        );

        uint32_t cheri_cause = (mccsr >> 5) & 0x1f;
        uint32_t cap_idx = (mccsr >> 10) & 0x3f;
        printf("CHERI exception at %08x: cause=%u, cap idx=%u\n",
               epc, cheri_cause, cap_idx);
    }
    else
    {
        uint32_t mtval;

        asm(
            "csrr %0, mtval\n\t"
            : "=r"(mtval)
        );

        printf("Exception at %08x: cause=%li mtval=%08x\n", epc, cause, mtval);
    }
}
