#ifndef TRUSTED_TRAPS_H
#define TRUSTED_TRAPS_H

#include "cheri.h"

#ifndef __ASSEMBLER__

struct trap_data {
    capability enclave_seal;
    // capability return_code;
    // capability return_data;
    capability epcc;
    capability cap_regs[31];
    uintptr_t regs[31];
};

#endif // __ASSEMBLER__

// #define TRAP_DATA_OFFSET_RETURN_CODE (1 * CAP_LEN)
// #define TRAP_DATA_OFFSET_RETURN_DATA (2 * CAP_LEN)
#define TRAP_DATA_OFFSET_EPCC (1 * CAP_LEN)
#define TRAP_DATA_OFFSET_CAPS (2 * CAP_LEN)
#define TRAP_DATA_OFFSET_REGS ((2 * CAP_LEN) + (31 * CAP_LEN))

#define TRAP_DATA_LEN (2 * CAP_LEN + 31 * CAP_LEN + 31 * WORD_SIZE)

#endif
