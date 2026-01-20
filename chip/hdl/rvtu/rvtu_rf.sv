//  SPDX-License-Identifier: MIT
//  rvtu_rf.sv — register file (potential PD IP)
//  Owner: Pradyun Narkadamilli
module rvtu_rf (
    input clk,

    input        [ 4:0] rs1_addr,
    output logic [31:0] rs1_rdata,

    input        [ 4:0] rs2_addr,
    output logic [31:0] rs2_rdata,

    input        rd_wr,
    input [ 4:0] rd_addr,
    input [31:0] rd_wdata
);
  logic [31:0] regs[1:31];

  assign rs1_rdata = ~(|rs1_addr) ? '0 :
                     ((rd_wr & rs1_addr == rd_addr) ? rd_wdata : regs[rs1_addr]);
  assign rs2_rdata = ~(|rs2_addr) ? '0 :
                     ((rd_wr & rs2_addr == rd_addr) ? rd_wdata : regs[rs2_addr]);

  always_ff @(posedge clk) if (rd_wr & |rd_addr) regs[rd_addr] <= rd_wdata;
endmodule
