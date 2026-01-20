.section .data
value:
    .word 0

.section .text
.globl main
main:
    addi x2, x0, 4
    nop             # nops in between to prevent hazard
    nop
    nop
    nop
    nop
    addi x3, x1, 8
    nop
    nop
    nop
    nop
    nop

    li   x4, 0x12345678   # load immediate test value into t0
    la   x2, value        # load address of 'value' into t1
    lw   x3, 0(x2)        # load word back into t2

    li   x3, 0x1234ABCD

    lb   x4, 0(x2)
    lbu  x4, 0(x2)
    lh   x4, 0(x2)
    lhu  x4, 0(x2)

    li   x3, 0x56
    lbu  x4, 1(x2)

    li   x3, 0x789A
    lhu  x4, 2(x2)

    mul   x5, x4, x3
    mulh  x5, x4, x3
    mulhu x5, x4, x3
    mulhsu x5, x4, x3

    li   x3, 0x33
    la   x2, value
    lw   x4, 0(x2)
    div  x5, x2, x4
    divu x5, x2, x4
    rem  x5, x3, x4
    remu x5, x3, x4

    ret
