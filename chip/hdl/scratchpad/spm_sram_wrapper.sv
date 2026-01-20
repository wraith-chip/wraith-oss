// This wraps a 1 KiB SRAM, for now (which has writethrough)

module spm_sram_wrapper (
  input logic clk,
  rst,
  scratchpad_bank_if.bank ctrl_if
);
  // SRAM inputs/outputs
  logic CEN;
  logic WEN;
  logic [8:0] A;
  logic [31:0] D, Q;
  logic RETN;
  logic [2:0] EMA;

  spm_bank_sram sram(
    .CLK(clk),
    .WEN(WEN),
    .CEN(CEN),
    .A(A),
    .D(D),
    .Q(Q),
    .RETN(RETN),
    .EMA(EMA)
  );

  logic creq, creq_last;

  assign creq = ctrl_if.ren | ctrl_if.wen;
  always_ff @(posedge clk) begin
    if (rst) creq_last <= '0;
    else creq_last <= creq;
  end

  logic rreq_last;
  always_ff @(posedge clk) begin
    if (rst) rreq_last <= '0;
    else rreq_last <= ctrl_if.ren;
  end

  assign CEN = '0;
  assign WEN = ~ctrl_if.wen;
  assign A = ctrl_if.addr;
  assign D = ctrl_if.wdata;

  assign RETN = ~rst;
  assign EMA = 3'h0;

  // Drive iface outputs
  assign ctrl_if.rdata = rreq_last ? Q : 'x;
  assign ctrl_if.rvalid = rreq_last ? creq_last : '0; 
  // assign ctrl_if.rvalid = creq_last; // read is interesting after write, since writethrough

endmodule
