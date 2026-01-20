.section .data
value:
  .word 0x3349301
  .word 0x0ABCDEF

.section .text
.globl main
main:
  la x2, value
  lw x3, 0(x2)
  lw x4, 4(x2)

  li x5, 0
  li x6, 1000

loop:
  div x7, x3, x4
  addi x5, x5, 1
  bne x5, x6, loop
  ret
