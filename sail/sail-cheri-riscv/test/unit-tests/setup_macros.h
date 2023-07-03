#ifndef RISCV_SETUP_H
#define RISCV_SETUP_H
#include "proteus_macros.h"

/////////////////////////////////////////////
// Setup
/////////////////////////////////////////////

//Different versions of `la` that are capability-aware

#define LA_PCC(dst,label)                       \
  cspecialr dst, pcc;                           \
  la x10, label;                                \
  csetoffset dst, dst, x10

#define LA_DDC(cdst,label)                                              \
  la x11, label ;                                                       \
  cspecialr cdst, pcc ;                                                 \
  cgetbase x10, cdst ;                                                  \
  add x11, x10, x11 /* x14 contains the absolute address of `label` */ ; \
  cspecialr cdst, ddc ;                                                 \
  csetaddr cdst, cdst, x11

#define LA_OTHER(cdst,label,cother)                                     \
  la x11, label ;                                                       \
  cspecialr cdst, pcc ;                                                 \
  cgetbase x10, cdst ;                                                  \
  add x11, x10, x11 /* x11 contains the absolute address of `label` */ ; \
  csetaddr cdst, cother, x11

//Different macros to set up parts of enclaves and jump to them

#define ENCLAVE_CODE_SECTION(cres, start, end) \
	cspecialr cres, pcc           ;\
  la x10, start                 ;\
  la x11, end                   ;\
	sub x11, x11, x10             ;\
	csetoffset cres, cres, x10    ;\
	csetboundsexact cres, cres, x11

#define ENCLAVE_DATA_SECTION(cres, start, end) \
	ENCLAVE_CODE_SECTION(cres, start, end) ;\
	li x10, 0b1111111111111101 /* If permit execute is set ccall will raise an exception */ ;\
	candperm cres, cres, x10

// Shrink pcc and ddc to cover the range [start,end), to
// 1. avoid overlap
// 2. so we can write to tohost in case of a trap (tohost is assumed to be mapped in this range)
// At the end, a jump to `jmptgt` is made. In other words, jmptgt \in [start, end) is assumed

/* Shrink ddc */
#define RESTRICT_DDC(cdst, start, end) \
  ENCLAVE_DATA_SECTION(cdst, start, end);\
  cspecialw ddc, cdst /*overwrite omnipotent ddc*/

/* Shrink pcc by jumping to cap */
#define RESTRICT_PCC_JUMP(cdst, start, end, jmptgt) \
  ENCLAVE_CODE_SECTION(cdst, start, end); \
  la x10, jmptgt ; \
  /* setaddress, because offset of `cdst` changed and current PCC has base 0 */  \
  csetaddr cdst, cdst, x10 ; \
	cjr cdst /* PCC is read only, so we jump to a capability to overwrite it */

#define RESTRICT_DDC_PCC_JUMP(cdst, start, end, jmptgt) \
  RESTRICT_DDC(cdst,start,end);\
  RESTRICT_PCC_JUMP(cdst,start,end,jmptgt)

#define SHOULD_FAIL_RAW(cscrap1, xscrap2, instr...) \
  cspecialr cscrap1, pcc                ;\
  la xscrap2, 999f                      ;\
  csetoffset cscrap1, cscrap1, xscrap2 	/* point to end of macro */ ;\
  cspecialrw cscrap1, mtcc, cscrap1     ;\
  instr                                 ;\
  cspecialw mtcc, cscrap1               ;\
  j fail                                ;\
999:  cspecialw mtcc, cscrap1

#define SHOULD_FAIL(instr...) SHOULD_FAIL_RAW(c29, x30, instr)

#endif
