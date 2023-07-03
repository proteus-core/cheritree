#ifndef TEST_MACROS_CAP_H
#define TEST_MACROS_CAP_H

#include "test_macros.h"

//Removed state restore
#define CHECK_GETTER(getter, cr, correct_result) \
    getter x30, cr; \
    li  x29, MASK_XLEN(correct_result); \
    beq x29, x30, 1f; \
    j fail; \
1:

#define CHECK_TAG(cr, tag) \
    CHECK_GETTER(CGetTag, cr, tag);

#define CHECK_LEN(cr, len) \
    CHECK_GETTER(CGetLen, cr, len);

#define CHECK_BOUNDS(cr, base, len) \
    CHECK_GETTER(CGetBase, cr, base); \
    CHECK_GETTER(CGetLen, cr, len);

#define CHECK_OFFSET(cr, offset) \
    CHECK_GETTER(CGetOffset, cr, offset);

#define CHECK_PERMS(cr, perms) \
    CHECK_GETTER(CGetPerm, cr, perms);

#define CHECK_TYPE(cr, type) \
    CHECK_GETTER(CGetType, cr, type);

#define CHECK_ADDR(cr, addr) \
    CHECK_GETTER(CGetAddr, cr, addr);

#define CHECK_CAP_NO_OFFSET(cr, tag, base, len, perms, type) \
    CHECK_TAG(cr, tag) \
    CHECK_BOUNDS(cr, base, len) \
    CHECK_PERMS(cr, perms) \
    CHECK_TYPE(cr, type)

#define CHECK_CAP(cr, tag, base, len, offset, perms, type) \
    CHECK_CAP_NO_OFFSET(cr, tag, base, len, perms, type) \
    CHECK_OFFSET(cr, offset)

#define CHECK_GETTER_EQ(getter, cd, cs) \
    getter x29, cs; \
    getter x30, cd; \
    beq x29, x30, 1f; \
    RESTORE_SAFE_STATE; \
    j fail; \
1:

#define CHECK_TAG_EQ(cd, cs) \
    CHECK_GETTER_EQ(CGetTag, cd, cs);

#define CHECK_BOUNDS_EQ(cd, cs) \
    CHECK_GETTER_EQ(CGetBase, cd, cs); \
    CHECK_GETTER_EQ(CGetLen, cd, cs);

#define CHECK_OFFSET_EQ(cd, cs) \
    CHECK_GETTER_EQ(CGetOffset, cd, cs);

#define CHECK_PERMS_EQ(cd, cs) \
    CHECK_GETTER_EQ(CGetPerm, cd, cs);

#define CHECK_TYPE_EQ(cd, cs) \
    CHECK_GETTER_EQ(CGetType, cd, cs);

#define CHECK_CAP_NEW_BOUNDS_OFFSET(cd, cs, base, len, offset) \
    CHECK_BOUNDS(cd, base, len); \
    CHECK_OFFSET(cd, offset); \
    CHECK_TAG_EQ(cd, cs); \
    CHECK_PERMS_EQ(cd, cs); \
    CHECK_TYPE_EQ(cd, cs);

#define CHECK_CAP_NEW_TYPE(cd, cs, type) \
    CHECK_TAG_EQ(cd, cs); \
    CHECK_BOUNDS_EQ(cd, cs); \
    CHECK_OFFSET_EQ(cd, cs); \
    CHECK_PERMS_EQ(cd, cs); \
    CHECK_TYPE(cd, type);

#define CHECK_CAP_EQ(cd, cs) \
    CHECK_TAG_EQ(cd, cs); \
    CHECK_BOUNDS_EQ(cd, cs); \
    CHECK_OFFSET_EQ(cd, cs); \
    CHECK_PERMS_EQ(cd, cs); \
    CHECK_TYPE_EQ(cd, cs);

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

#define TEST_CASE_START(testnum) \
test_ ## testnum: \
    li TESTNUM, testnum; \

#endif

#ifndef CHERI_H
#define CHERI_H

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

#endif
