OUTPUT_ARCH( "riscv" )
ENTRY(_start)

_text_start = 0x80000000;
_stack_top  = 0xbffffffc;

MEMORY
{
  BRAM (rwx) : ORIGIN = 0x80000000, LENGTH = 1024M
}

SECTIONS
{

  . = _text_start;

  .init :
  {
    . = ALIGN(4096);
    *(.init)
    . = ALIGN(4096);
  }

  . = .;

  .text :
  {
    . = ALIGN(4096);
    _text_vma_start = .;

    *(.text)
    *(.text*)

    _text_vma_end = .;
    . = ALIGN(4096);
  }

  . = .;

  .data :
  {
    . = ALIGN(4096);
    _data_vma_start = .;

    *(.*data*)

    _data_vma_end = .;
    . = ALIGN(4096);
  }

  . = .;

  .bss :
  {
    . = ALIGN(4096);
    _bss_vma_start = .;

    *(.*bss*)

    _bss_vma_end = .;
    . = ALIGN(4096);
  }

  _end = .;

  /DISCARD/ :
  {
    *(.eh_frame)
    *(.riscv.attributes)
    *(.comment)
    *(.debug*)
  }
}
