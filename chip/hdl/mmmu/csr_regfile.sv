module csr_regfile
  import glbl_pkg::*;
  import mmmu_types::*;
(
    input logic clk,
    input logic rst,

    // Do something a little more structure aware?
    input logic [$clog2(NUM_CSRS_EFF)-1:0] off_chip_csr_addr,
    input logic off_chip_rfile_wen,
    input logic [31:0] off_chip_rfile_wdata,
    output logic [31:0] off_chip_csrfile_rdata,

    output logic [31:0] rfile_rdata[NUM_RFILE],

    // on-chip guys write to this
    input  logic [31:0] wfile_wdata[NUM_WFILE]
);
  localparam integer unsigned NUMMAX = ((NUM_RFILE > NUM_WFILE) ? NUM_RFILE : NUM_WFILE);

  // The actual CSRs??
  // The offchip guys write  to the rfile, this is read by the on-chip guys
  logic [31:0] csr_rfile[NUM_RFILE];
  // The on-chip guys write to the wfile, this is read by the off-chip guys
  logic [31:0] csr_wfile[NUM_WFILE];

  assign rfile_rdata = csr_rfile;

  always_ff @(posedge clk) begin
    if (rst) begin
      csr_rfile <= '{default: '0};
      csr_wfile <= '{default: '0};
    end else begin
      // Update rfile_wdata if rfile_wen
      if (off_chip_rfile_wen)
        csr_rfile[off_chip_csr_addr[$clog2(NUM_RFILE)-1:0]] <= off_chip_rfile_wdata;

      csr_wfile <= wfile_wdata;
    end
  end

  logic [31:0] csr_rfile_padded[NUMMAX];
  logic [31:0] csr_wfile_padded[NUMMAX];

  always_comb begin
    // Pad
    for (integer unsigned i = NUM_RFILE; i < NUMMAX; i++) csr_rfile_padded[i] = 'x;
    for (integer unsigned i = NUM_WFILE; i < NUMMAX; i++) csr_wfile_padded[i] = 'x;
    // Copy all real registers
    for (integer unsigned i = 0; i < NUM_RFILE; i++) csr_rfile_padded[i] = csr_rfile[i];
    for (integer unsigned i = 0; i < NUM_WFILE; i++) csr_wfile_padded[i] = csr_wfile[i];
  end

  logic select_file;
  assign select_file = off_chip_csr_addr[$clog2(NUM_CSRS_EFF)-1];

  logic [$clog2(NUM_CSRS_EFF)-2:0] idx;
  assign idx = off_chip_csr_addr[$clog2(NUM_CSRS_EFF)-2:0];

  assign off_chip_csrfile_rdata = select_file ? csr_wfile_padded[idx] : csr_rfile_padded[idx];
endmodule
