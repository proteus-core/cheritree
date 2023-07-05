#ifndef CHERI_H
#define CHERI_H

#define CAP_LEN 16

#define CHERI_EXCEPTION_CAUSE 10

#define CAUSE_NONE 0x0
#define CAUSE_LENGTH_VIOLATION 0x1
#define CAUSE_TAG_VIOLATION 0x2
#define CAUSE_SEAL_VIOLATION 0x3
#define CAUSE_TYPE_VIOLATION 0x4
#define CAUSE_CALL_TRAP 0x5
#define CAUSE_RETURN_TRAP 0x6
#define CAUSE_TRUSTED_SYSTEM_STACK_OVERFLOW 0x7
#define CAUSE_SOFTWARE_DEFINED_PERMISSION_VIOLATION 0x8
#define CAUSE_MMU_PROHIBITS_STORE_CAPABILITY 0x9
#define CAUSE_BOUNDS_CANNOT_BE_REPRESENTED_EXACTLY 0xa
#define CAUSE_GLOBAL_VIOLATION 0x10
#define CAUSE_PERMIT_EXECUTE_VIOLATION 0x11
#define CAUSE_PERMIT_LOAD_VIOLATION 0x12
#define CAUSE_PERMIT_STORE_VIOLATION 0x13
#define CAUSE_PERMIT_LOAD_CAPABILITY_VIOLATION 0x14
#define CAUSE_PERMIT_STORE_CAPABILITY_VIOLATION 0x15
#define CAUSE_PERMIT_STORE_LOCAL_CAPABILITY_VIOLATION 0x16
#define CAUSE_PERMIT_SEAL_VIOLATION 0x17
#define CAUSE_ACCESS_SYSTEM_REGISTERS_VIOLATION 0x18
#define CAUSE_PERMIT_CCALL_VIOLATION 0x19
#define CAUSE_ACCESS_CCALL_IDC_VIOLATION 0x1a
#define CAUSE_PERMIT_UNSEAL_VIOLATION 0x1b
#define CAUSE_PERMIT_SET_CID_VIOLATION 0x1c

#define CAP_IDX_PCC 0x20
#define CAP_IDX_DDC 0x21
#define CAP_IDX_MTDC 0x3d

#define PERM_GLOBAL 0
#define PERM_PERMIT_EXECUTE 1
#define PERM_PERMIT_LOAD 2
#define PERM_PERMIT_STORE 3
#define PERM_PERMIT_LOAD_CAPABILITY 4
#define PERM_PERMIT_STORE_CAPABILITY 5
#define PERM_PERMIT_STORE_LOCAL_CAPABILITY 6
#define PERM_PERMIT_SEAL 7
#define PERM_PERMIT_CCALL 8
#define PERM_PERMIT_UNSEAL 9
#define PERM_ACCESS_SYSTEM_REGISTERS 10
#define PERM_PERMIT_SET_CID 11

#ifndef __ASSEMBLER__

#include "stdint.h"
#include "stddef.h"
#include "assert.h"

typedef struct __attribute__((aligned(16))) {
    char pad[16];
} capability;

#define CHERI_GETTER(name, insn) \
    inline uintptr_t name(const capability* cap) { \
        uintptr_t value; \
        asm volatile( \
            "LC ct0, (%1)\n\t" \
            #insn " %0, ct0\n\t" \
            : "=r"(value) : "r"(cap) \
        ); \
        return value; \
    }

CHERI_GETTER(cheri_get_tag, CGetTag)
CHERI_GETTER(cheri_get_base, CGetBase)
CHERI_GETTER(cheri_get_offset, CGetOffset)
CHERI_GETTER(cheri_get_len, CGetLen)
CHERI_GETTER(cheri_get_perm, CGetPerm)
CHERI_GETTER(cheri_get_type, CGetType)
CHERI_GETTER(cheri_get_addr, CGetAddr)

#define CHERI_SETTER(name, insn) \
    inline void name(capability* cap, uintptr_t val) { \
        asm volatile( \
            "LC ct0, (%0)\n\t" \
            #insn " ct0, ct0, %1\n\t" \
            "SC ct0, (%0)\n\t" \
            :: "r"(cap), "r"(val) \
        ); \
    }

CHERI_SETTER(cheri_set_addr, CSetAddr)
CHERI_SETTER(cheri_set_bounds_exact, CSetBoundsExact)
CHERI_SETTER(cheri_and_perm, CAndPerm)
CHERI_SETTER(cheri_inc_offset, CIncOffset)
CHERI_SETTER(cheri_set_offset, CSetOffset)

#define CHERI_3CAP(name, insn) \
    inline void name(capability* cap1, const capability* cap2) { \
        asm volatile( \
            "LC ct0, (%0)\n\t" \
            "LC ct1, (%1)\n\t" \
            #insn " ct2, ct0, ct1\n\t" \
            "SC ct2, (%0)\n\t" \
            :: "r"(cap1), "r"(cap2) : "memory" \
        ); \
    }

CHERI_3CAP(cheri_seal, CSeal)
CHERI_3CAP(cheri_unseal, CUnseal)

#define CHERI_SCR_READ(scr) \
    inline void cheri_read_##scr(capability* cap) { \
        asm volatile( \
            "CSpecialR ct0, " #scr "\n\t" \
            "SC ct0, (%0)\n\t" \
            : : "r"(cap) \
        ); \
    }

#define CHERI_SCR_ACCESS(scr) \
    CHERI_SCR_READ(scr) \
    inline void cheri_write_##scr(const capability* cap) { \
        asm volatile( \
            "LC ct0, (%0)\n\t" \
            "CSpecialW " #scr ", ct0\n\t" \
            : : "r"(cap) \
        ); \
    }

CHERI_SCR_ACCESS(ddc)
CHERI_SCR_ACCESS(mtcc)
CHERI_SCR_ACCESS(mtdc)
CHERI_SCR_ACCESS(mepcc)
CHERI_SCR_ACCESS(mscratchc)
CHERI_SCR_READ(pcc)

inline void cheri_write_pcc_bounds(const capability* bounds)
{
    asm volatile(
        "LC ct0, (%0)\n\t"
        "la t0, 1f\n\t"
        "CSetAddr ct0, ct0, t0\n\t"
        "CJALR ct0\n\t"
        "1:"
        :: "r"(bounds) : "t0"
    );
}

inline uint32_t cheri_lw(const capability* cap)
{
    uint32_t word;

    asm volatile(
        "LC ct0, (%1)\n\t"
        "lw.cap %0, (ct0)\n\t"
        : "=r"(word)
        : "r"(cap)
    );

    return word;
}

inline void cheri_sc(const capability* dst, const capability* cap)
{
    asm volatile(
        "LC ct0, (%0)\n\t"
        "LC ct1, (%1)\n\t"
        "SC.cap ct1, (ct0)\n\t"
        :: "r"(dst), "r"(cap)
    );
}

inline void cheri_move(capability* dst, const capability* src)
{
    asm volatile(
        "LC ct0, (%0)\n\t"
        "SC ct0, (%1)\n\t"
        :: "r"(src), "r"(dst)
    );
}

#define cheri_move_to_reg(dst_reg, src) \
    asm volatile(                       \
        "LC " dst_reg ", (%0)"          \
        :: "r"(src) : dst_reg           \
    );

#define cheri_move_from_reg(dst, src_reg) \
    asm volatile(                         \
        "SC " src_reg ", (%0)"            \
        :: "r"(dst)                       \
    );

inline void cheri_get_null(capability* cap)
{
    asm volatile(
        "SC cnull, (%0)\n\t"
        :: "r"(cap)
    );
}

inline void cheri_clear_tag(capability* cap)
{
    asm volatile(
        "LC ct0, (%0)\n\t"
        "CClearTag ct0, ct0\n\t"
        "SC ct0, (%0)\n\t"
        :: "r"(cap)
    );
}

inline void cheri_clear_all_gpcr()
{
    #define CLEAR_GPCR(gpcr) asm volatile("CClearTag " #gpcr ", " #gpcr)

    CLEAR_GPCR(c1);
    CLEAR_GPCR(c2);
    CLEAR_GPCR(c3);
    CLEAR_GPCR(c4);
    CLEAR_GPCR(c5);
    CLEAR_GPCR(c6);
    CLEAR_GPCR(c7);
    CLEAR_GPCR(c8);
    CLEAR_GPCR(c9);
    CLEAR_GPCR(c10);
    CLEAR_GPCR(c11);
    CLEAR_GPCR(c12);
    CLEAR_GPCR(c13);
    CLEAR_GPCR(c14);
    CLEAR_GPCR(c15);
    CLEAR_GPCR(c16);
    CLEAR_GPCR(c17);
    CLEAR_GPCR(c18);
    CLEAR_GPCR(c19);
    CLEAR_GPCR(c20);
    CLEAR_GPCR(c21);
    CLEAR_GPCR(c22);
    CLEAR_GPCR(c23);
    CLEAR_GPCR(c24);
    CLEAR_GPCR(c25);
    CLEAR_GPCR(c26);
    CLEAR_GPCR(c27);
    CLEAR_GPCR(c28);
    CLEAR_GPCR(c29);
    CLEAR_GPCR(c30);
    CLEAR_GPCR(c31);

    #undef CLEAR_GPCR
}

inline void cheri_memcpy(const capability* dst,
                         const capability* src,
                         size_t len)
{
    // Check that we can copy the full buffer using lw/sw.
    assert(len % 4 == 0);
    assert(cheri_get_addr(src) % 4 == 0);
    assert(cheri_get_addr(dst) % 4 == 0);

    asm volatile(
        "mv t0, %[len]\n\t" // Copy because we modify it
        "LC ct0, (%[dst])\n\t"
        "LC ct1, (%[src])\n\t"
        "1:\n\t"
        "beqz t0, 2f\n\t"
        // NOTE we use lw/sw instead of lc/sc because of
        // https://gitlab.com/ProteusCore/ProteusCore/-/issues/5
        "lw.cap t1, (ct1)\n\t"
        "sw.cap t1, (ct0)\n\t"
        "CIncOffsetImm ct0, ct0, 4\n\t"
        "CIncOffsetImm ct1, ct1, 4\n\t"
        "addi t0, t0, -4\n\t"
        "j 1b\n\t"
        "2:"
        :
        : [dst] "r"(dst),
          [src] "r"(src),
          [len] "r"(len)
        : "ct0", "ct1", "t0", "t1"
    );
}

#undef CHERI_GETTER
#undef CHERI_SETTER
#undef CHERI_3CAP
#undef CHERI_SCR_READ
#undef CHERI_SCR_ACCESS

#endif

#endif
