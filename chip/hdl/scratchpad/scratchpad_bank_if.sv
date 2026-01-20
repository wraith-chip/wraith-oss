interface scratchpad_bank_if #(
    parameter integer unsigned ADDRBITS = 9 // Value for 2KiB sram
) ();
  // Deciding which address mapping to use is up to you
  logic [ADDRBITS - 1:0] addr;
  logic ren;
  logic wen;
  logic [31:0] rdata;
  logic rvalid;
  logic [31:0] wdata;

  modport ctrl(input rdata, rvalid, output addr, ren, wen, wdata);

  modport bank(input addr, ren, wen, wdata, output rdata, rvalid);

endinterface
