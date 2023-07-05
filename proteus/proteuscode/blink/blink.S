    .globl _start
_start:
    li t0, 0x20000000
    mv t1, zero

1:
    sb t1, (t0)
    addi t1, t1, 1

    li t2, 10

2:
    addi t2, t2, -1
    bnez t2, 2b

    j 1b

