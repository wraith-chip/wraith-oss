//  SPDX-License-Identifier: MIT
//  bridge_types.sv — Datatypes for Husk Bridge
//  Copyright (c) 2026 Pradyun Narkadamilli

// Note: largely copied from WRAITH's types file.

package bridge_types;
  typedef enum logic [2:0] {
    POLL, SCLR,  SADDR, SDATA,
    MCLR, MADDR, MDATA, FCLR
  } dbus_fsm_t;

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

  // names slightly changed from WRAITH's for clarity
  typedef struct packed {
    logic        husk_req;   // 31
    dbus_meta_t  husk_meta;  // 30-26
    logic [10:0] __reserved0;    // 25-16

    logic        wraith_req;   // 15
    dbus_meta_t  wraith_meta;  // 14-10
    logic [10:0] __reserved1;   // 9-0
  } dbus_handshake_t;

  typedef struct packed {
    logic rd;
    logic wr;
    logic [2:0] csr_idx;
    logic [31:0] wdata;

    logic spm; // ignore csr_idx/wdata if set
  } dbus_axi_req_t;

  typedef enum logic [2:0] {
    IDLE, BUSY,
    SPMR_W1, SPMR_R
  } axireq_fsm_t;

  localparam URAM_LATENCY = 9;
endpackage
