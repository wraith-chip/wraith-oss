package glbl_pkg;
  // Must be powers of 2!!
  localparam integer unsigned SPM_BANK_SIZE = 512;
  localparam integer unsigned NUM_RFILE = 2;
  localparam integer unsigned NUM_WFILE = 3;
  localparam integer unsigned NUM_CSRS_EFF = 2 * ((NUM_RFILE > NUM_WFILE) ? NUM_RFILE : NUM_WFILE);

  localparam integer unsigned CSR_IDX_BITS = $clog2(NUM_CSRS_EFF);

  // If this order bit (from lowest) is 1, then address correpsonds to memmapped csr
  localparam integer unsigned MMIO_CSR_SELECT_BITIDX = 10;

  localparam integer unsigned SPMLEN_RFILE_IDX   = 0;
  localparam integer unsigned SPMLEN_IN_BOT_IDX  = 8;
  localparam integer unsigned SPMLEN_OUT_BOT_IDX = 17;
endpackage
