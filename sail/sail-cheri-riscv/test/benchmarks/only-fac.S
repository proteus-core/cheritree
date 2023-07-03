#include "test_macros_2.h"

RVTEST_RV64U
RVTEST_CODE_BEGIN

li x11, 5
li x10, 1

fac_loop:
    beqz x11, end_fac
    mul x10, x10, x11
    addi x11, x11, -1
    j fac_loop
end_fac:

RVTEST_PASS
RVTEST_CODE_END


.align 6; .global tohost; tohost: .dword 0;
