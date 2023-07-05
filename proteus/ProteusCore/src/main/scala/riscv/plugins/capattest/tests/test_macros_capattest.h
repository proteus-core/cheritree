#ifndef TEST_MACROS_CAPATTEST_H
#define TEST_MACROS_CAPATTEST_H

#include "test_macros_cap.h"
#include "cheri.h"

// Make ddc overlap with MMIO regions so we can write to testdev but not
// overlap with any code sections.
// Make pcc/mtcc only overlap with non-enclave code.
// Clear mepcc
#define INIT_CAPATTEST \
    INIT_ROOT_CAP; \
    li t0, 0x80000000; \
    CSetBoundsExact c1, ROOT, t0; \
    CSpecialW ddc, c1; \
    CSpecialR c1, pcc; \
    CSetOffset c1, c1, zero; \
    la t0, end_non_enclave_text; \
    CSetBoundsExact c1, c1, t0; \
    la t0, 1f; \
    CSetAddr c1, c1, t0; \
    CJALR c0, c1; \
    1: \
    CSpecialR c2, mtcc; \
    CGetAddr t0, c2; \
    CSetAddr c1, c1, t0; \
    CSpecialW mtcc, c1; \
    CMove c1, cnull; \
    CSpecialW mepcc, c1; \
    CClearTag c1, c1; \
    CClearTag c2, c2;

#define E_INIT_CODE(cap, start, end) \
    la t0, start; \
    CSetAddr cap, ROOT, t0; \
    la t1, end; \
    sub t2, t1, t0; \
    CSetBoundsExact cap, cap, t2; \
    EInitCode cap, cap

#define E_INIT_DATA(code_cap, data_cap, start, end) \
    la t0, start; \
    CSetAddr data_cap, ROOT, t0; \
    la t1, end; \
    sub t2, t1, t0; \
    CSetBoundsExact data_cap, data_cap, t2; \
    li t3, ~(1 << PERM_PERMIT_EXECUTE); \
    CAndPerm data_cap, data_cap, t3; \
    EInitData data_cap, code_cap, data_cap;

#define CAP_OFFSET_TO_BASE(dst, src) \
    CGetLen t0, src; \
    CGetOffset t1, src; \
    sub t0, t0, t1; \
    CSetBoundsExact dst, src, t0

#define CAP_SET_BASE(dst, src, base) \
    CSetAddr dst, src, base; \
    CAP_OFFSET_TO_BASE(dst, dst)

#define CAP_SPLIT(dst_left, dst_right, src, offset) \
    CSetBoundsExact dst_left, src, offset; \
    CSetOffset dst_right, src, offset; \
    CAP_OFFSET_TO_BASE(dst_right, dst_right)

#endif
