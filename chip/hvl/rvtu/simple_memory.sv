module simple_memory #(
  parameter logic LOADMEMFILE = '0,
  parameter logic STALL = '0,
  parameter int MAXWAIT = 1,
  parameter int SEED = 'hECEB0000,
  parameter string PLUSARGS = "SIM_MEMFILE=%s"
) (
  input logic         clk,
  input logic         rst,

  input logic [31:0]  maddr,
  input logic         mrd ,
  input logic [3:0]   mwr,
  input logic [31:0]  mwdata,
  output logic        mresp,
  output logic [31:0] mrdata
);
  logic [31:0]       mem [logic [31:2]];
  logic [31:0]       mwaitctr;

  logic              rereq, mresp_b, lastaddr_vld, lastaddr_vld_b;
  logic [31:0]       lastaddr;

  assign mresp_b = ~rst & (mrd | (|mwr)) & (!STALL | (mwaitctr=='0) | rereq);
  assign lastaddr_vld_b = rst ? '0 : (mresp_b | lastaddr_vld);

  always_ff @ (posedge clk) mresp <= mresp_b;
  always_ff @ (posedge clk) if (mresp_b) lastaddr <= maddr;
  always_ff @ (posedge clk) if (rst | mresp_b) lastaddr_vld <= lastaddr_vld_b;

  assign rereq = lastaddr_vld & (lastaddr == maddr);

  always_ff @(posedge clk)
    if (mrd & (!STALL | (mwaitctr=='0))) mrdata <= mem[maddr[31:2]];


  logic [31:0] int_wmask;
  always_comb begin
    int_wmask = '0;
    for (int i=0; i<4; i++)
      if (~rst & (|mwr))
        int_wmask[i*8 +: 8] = {8{mwr[i]}};
  end

  always_ff @(posedge clk)
    begin
      if (~rst && (|mwr) && ((mwaitctr == '0) | !STALL))
        mem[maddr[31:2]] <= (mwdata & int_wmask) | (mem[maddr[31:2]] & ~int_wmask);
    end

  generate
    if (STALL) begin : stallupdater
      always_ff @ (posedge clk) begin
        if (rst)
          mwaitctr <= $urandom(SEED) % MAXWAIT;
        else if (STALL)
          mwaitctr <= (mwaitctr == '0 | rereq) ? ($urandom_range(1, MAXWAIT)) : (mwaitctr-1);
        end
    end
  endgenerate

  initial
    begin
      mem.delete();
      if (LOADMEMFILE)
        begin
          automatic string memfile;
          $value$plusargs(PLUSARGS, memfile);
          $display("Loading out of %s", memfile);
          $readmemh(memfile, mem);
        end
    end
endmodule
