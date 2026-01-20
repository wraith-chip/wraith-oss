//  SPDX-License-Identifier: MIT
//  rvtu.sv — RVTU top level
//  Owner: Pradyun Narkadamilli

module rvtu
  import rv_pkg::*;
#(
    parameter logic [31:0] pc_init = 'h40000000
) (
    input clk,
    input rst,

    // cache port
    output logic [31:0] maddr,
    output logic        mrd,
    output logic [ 3:0] mwr,
    output logic [31:0] mwdata,
    input               mresp,
    input        [31:0] mrdata,

    // mul egress port
    output logic        eg_empty,
    input  logic        eg_deq,
    output logic [35:0] eg_pkt,

    // mul ingress port
    input  logic        ig_empty,
    output logic        ig_deq,
    input        [35:0] ig_pkt,

    // div arbiter port
    output logic        div_req,
    output logic [31:0] div_src1,
    output logic [31:0] div_src2,
    output logic [ 1:0] div_fsel,

    input        div_resp,
    input [31:0] div_out,

    // halt flag
    output logic halt
);
  logic fe_stall, ex_stall, glb_stall, be_stall;

  logic        flush;
  logic [31:0] flush_addr;

  logic i_mresp, d_mrd, d_mresp;
  logic [3:0] d_mwr;
  logic [31:0] i_maddr, i_mrdata, d_maddr, d_mrdata, d_mwdata;

  logic rd_wr;
  logic [4:0] rs1_addr, rs2_addr, rd_addr;
  logic [31:0] rs1_rdata, rs2_rdata, rd_wdata;

  logic instr_vld, ex_vld;
  instrPkt_t instr;
  exMemPkt_t ex_pkt;

  logic ex_mem_has_ld, ex_req_mem_fwd;
  fwd_t mem_fwd, wb_fwd, skid_fwd;

  rvtu_fe #(
      .pc_init(pc_init)
  ) fe (
      .clk,
      .rst,

      .maddr (i_maddr),
      .mrdata(i_mrdata),
      .mresp (i_mresp),

      .instr_vld(instr_vld),
      .instr_o  (instr),

      .glb_stall(glb_stall),
      .fe_stall (fe_stall),

      .flush     (flush),
      .flush_addr(flush_addr),

      .rs1_addr (rs1_addr),
      .rs1_rdata(rs1_rdata),

      .rs2_addr (rs2_addr),
      .rs2_rdata(rs2_rdata)
  );

  rvtu_ex ex (
      .clk,
      .rst,

      .instr_vld(instr_vld),
      .instr_i  (instr),

      .ex_vld(ex_vld),
      .ex_pkt(ex_pkt),

      .flush     (flush),
      .flush_addr(flush_addr),

      .eg_empty(eg_empty),
      .eg_deq  (eg_deq),
      .eg_pkt  (eg_pkt),

      .ig_empty(ig_empty),
      .ig_deq  (ig_deq),
      .ig_pkt  (ig_pkt),

      .div_req (div_req),
      .div_src1(div_src1),
      .div_src2(div_src2),
      .div_fsel(div_fsel),

      .div_resp(div_resp),
      .div_out (div_out),

      .ex_mem_has_ld (ex_mem_has_ld),
      .ex_req_mem_fwd(ex_req_mem_fwd),
      .mem_fwd       (mem_fwd),
      .wb_fwd        (wb_fwd),
      .skid_fwd      (skid_fwd),

      .glb_stall(glb_stall),
      .ex_stall (ex_stall)
  );

  rvtu_mem_wb mem_wb (
      .clk,
      .rst,

      .ex_vld(ex_vld),
      .ex_pkt(ex_pkt),

      .rd_wr   (rd_wr),
      .rd_addr (rd_addr),
      .rd_wdata(rd_wdata),

      .maddr (d_maddr),
      .mrd   (d_mrd),
      .mwr   (d_mwr),
      .mwdata(d_mwdata),
      .mresp (d_mresp),
      .mrdata(d_mrdata),

      .ex_mem_has_ld (ex_mem_has_ld),
      .ex_req_mem_fwd(ex_req_mem_fwd),
      .mem_fwd       (mem_fwd),
      .wb_fwd        (wb_fwd),
      .skid_fwd      (skid_fwd),

      .fe_stall (fe_stall),
      .ex_stall (ex_stall),
      .glb_stall(glb_stall),
      .be_stall (be_stall),

      .halt (halt)
  );

  rvtu_rf rf (
      .clk,

      .rs1_addr (rs1_addr),
      .rs1_rdata(rs1_rdata),

      .rs2_addr (rs2_addr),
      .rs2_rdata(rs2_rdata),

      .rd_wr   (rd_wr),
      .rd_addr (rd_addr),
      .rd_wdata(rd_wdata)
  );

  rvtu_cache_arb cache_arb (
      .clk,
      .rst,

      .glb_stall(be_stall),

      .i_maddr (i_maddr),
      .i_mresp (i_mresp),
      .i_mrdata(i_mrdata),

      .d_maddr (d_maddr),
      .d_mrd   (d_mrd),
      .d_mwr   (d_mwr),
      .d_mwdata(d_mwdata),
      .d_mresp (d_mresp),
      .d_mrdata(d_mrdata),

      .c_maddr (maddr),
      .c_mrd   (mrd),
      .c_mwr   (mwr),
      .c_mwdata(mwdata),
      .c_mresp (mresp),
      .c_mrdata(mrdata)
  );
endmodule
