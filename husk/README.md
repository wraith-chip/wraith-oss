# Husk

These artifacts encompass the testing platform used to bring up our chip on a VCU118
FPGA! The block design included leverages URAM to act as memory for the RVTU cores in
the chip. These can be replaced with smaller BRAM blocks on non-Ultrascale FPGAs.

As configured, these artifacts will run WRAITH as 125MHz using a skewed copy of the FPGA
fabric clock.

## Operating Assumptions

> [!WARNING]
> Microblaze should never be reset/reprogrammed alone!

We assume that the `cpu_reset` button will be pressed before any Microblaze transaction
to the WRAITH MMIO space.  This resets the bridge to a state where the bridge is locked
off, and that WRAITH is held in reset, and also helps make sure CDC components are in a
coherent state.

## MicroBlaze Memory Map

- 0x10000 to 0x10FFF: SPM BRAM. The SPM is a 2K block, but mirrored in the address map.
- 0x4A00000 to 0x4A0FFFF: Husk's CSR interface. Only 16 indices are supported for now.
  - First 7 registers are proxies to the CSR regfile. They may not all be valid.
  - 8th register is a proxy to initiate read/write of SPM
  - 9th register is a "busy" tracker for outstanding transactions (initiated by AXI)
  - 10th register is a holding buffer for CSR read data
  - 11th register is a "meta" husk CSR to configure resets/dbus enable
    - This is a typical R/W register
    - Bit 0: Bridge/Chip Enable
    - Bit 1: RVTU0 enable
    - Bit 2: RVTU1 enable

- 0x6000_0000 to 0x603F_FFFF: RVTU0 program space
- 0x6040_0000 to 0x607F_FFFF: RVTU1 program space
