//! Define esssential types for the MMMU.

// The MMMU handles all memory and memory-mapped
// interactions between WRAITH and off-chip.

package mmmu_types;

  // All sizes are in words (32 bits)
  // Bus width is 32
  localparam integer unsigned CYCLES_PER_WORD = 1;
  // A control register is a 32-bit register
  localparam integer unsigned RVTU_CTRL_REG_SIZE = 1;
  // The SPM is configured using 2 KiB of size
  localparam integer unsigned SPM_CFG_SIZE = 512;
  // A cacheline is 4 words (128 bits)
  localparam integer unsigned CACHELINE_SIZE = 4;

  localparam integer unsigned MAX_TRANSACTION_SIZE = 512;
  localparam integer unsigned DATA_CTR_WIDTH = $clog2(MAX_TRANSACTION_SIZE);

  // I will let the Tools decide the actual coding
  typedef enum logic [2:0] {
    poll,
    // This state is needed since after we just wrote or read data,
    // we need to know to not parse it as a request
    poll_wait_bus_clr,
    driver_addr0,
    driver_data,
    passenger_addr0,
    passenger_data
  } bus_trans_fsm_t;

  typedef enum logic [3:0] {
    // OFFCHIP -> ONCHIP
    // CSR defines the number of spm packets to configure
    SPMLEN_spm_write  = 4'h2,
    csr_write         = 4'h5,  // Provide write value of WRAITH/RVTU CSR
    csr_rd_req        = 4'h3,  // Request read of WRAITH/RVTU CSR
    cacheline_rd_resp = 4'h7,  // Provide response to RVTU's cache miss

    // ONCHIP -> OFFCHIP
    SPMLEN_spm_wb    = 4'h1,  // Request write of CGRA full kernel output to off-chip
    cacheline_rd_req = 4'h8,  // Request read due to RVTU cache miss
    cacheline_wb     = 4'h6,  // Request write of CGRA dirty cacheline
    csr_rd_resp      = 4'h4,

    // IDLE for xprop
    no_meta          = '0
  } dbus_meta_t;

  typedef struct packed {
    logic        off_chip_req;   // 31
    dbus_meta_t  off_chip_meta;  // 30-26
    logic [10:0] __reserved0;    // 25-16

    logic        on_chip_req;   // 15
    dbus_meta_t  on_chip_meta;  // 14-10
    logic [10:0] __reserved1;   // 9-0
  } dbus_pkt_cyc0_t;

  typedef enum logic [2:0] {
    POLL, SCLR,  SADDR, SDATA,
    MCLR, MADDR, MDATA, FCLR
  } bridge_state_t;
endpackage
