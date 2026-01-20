//  SPDX-License-Identifier: MIT
//  rvtu_mem_wb.sv — Memory and WB stage
//  Owner: Pradyun Narkadamilli

module rvtu_mem_wb
  import rv_pkg::*;
(
    input clk,
    input rst,

    input            ex_vld,
    input exMemPkt_t ex_pkt,

    output logic        rd_wr,
    output logic [ 4:0] rd_addr,
    output logic [31:0] rd_wdata,

    output logic [31:0] maddr,
    output logic        mrd,
    output logic [ 3:0] mwr,
    output logic [31:0] mwdata,
    input               mresp,
    input        [31:0] mrdata,

    output logic ex_mem_has_ld,
    input        ex_req_mem_fwd,
    output fwd_t mem_fwd,
    output fwd_t wb_fwd,
    output fwd_t skid_fwd,

    input        fe_stall,
    input        ex_stall,
    output logic glb_stall,
    output logic be_stall,

    output logic halt
);
  logic ex_vld_r, ex_vld_b, ex_vld_en;
  exMemPkt_t ex_pkt_r;

  logic mem_wb_vld, mem_wb_vld_b, mem_wb_vld_en;
  memWbPkt_t mem_wb, mem_wb_b;

  logic skid_vld, skid_vld_b, skid_vld_en;
  skidPkt_t skid, skid_b;

  logic [ 3:0] wmask;
  logic [31:0] s_mrdata;

  logic upstream_stall, need_bubble, mem_stall;

  logic halt_b, halt_en;

  // need additional term for outbound to account for bubbling
  assign upstream_stall = fe_stall | ex_stall;
  assign need_bubble    = ex_vld_r & ex_pkt_r.mem & ex_pkt_r.req_rd & ex_req_mem_fwd;
  assign mem_stall      = ex_vld_r & ex_pkt_r.mem & ~mresp;

  assign be_stall       = mem_stall | (~need_bubble & upstream_stall);
  assign glb_stall      = upstream_stall | need_bubble | mem_stall;

  assign ex_vld_en      = rst | ~be_stall;
  assign ex_vld_b       = ~rst & ex_vld;

  assign ex_mem_has_ld  = ex_vld_r & ex_pkt_r.mem & ex_pkt_r.req_rd;
  always_ff @(posedge clk) if (ex_vld_en) ex_vld_r <= ex_vld_b;
  always_ff @(posedge clk) if (~be_stall) ex_pkt_r <= ex_pkt;

  assign mem_fwd.valid = ex_vld_r & ex_pkt_r.req_rd & ~ex_pkt_r.mem & (|ex_pkt_r.rd_addr);
  assign mem_fwd.addr  = ex_pkt_r.rd_addr;
  assign mem_fwd.data  = ex_pkt_r.ex_out;

  assign maddr  = {ex_pkt_r.ex_out[31:2], 2'b0};
  assign mrd    = ex_vld_r & ex_pkt_r.mem & ex_pkt_r.req_rd;

  assign wmask  = get_basemask(rvStOp_t'(ex_pkt_r.fsel)) << ex_pkt_r.ex_out[1:0];
  assign mwr    = {4{ex_vld_r & ex_pkt_r.mem & ~ex_pkt_r.req_rd}} & wmask;
  assign mwdata = ex_pkt_r.rs2 << {ex_pkt_r.ex_out[1:0], 3'b0};

  assign mem_wb_vld_b  = ~rst & ex_vld_r;
  assign mem_wb_vld_en = rst | ~be_stall;
  always_ff @(posedge clk) if (mem_wb_vld_en) mem_wb_vld <= mem_wb_vld_b;

  assign s_mrdata = get_lddataproc(ex_pkt_r.fsel, $signed(mrdata) >>> {ex_pkt_r.ex_out[1:0], 3'b0});

  assign mem_wb_b.req_rd = ex_pkt_r.req_rd;
  assign mem_wb_b.rd_addr = ex_pkt_r.rd_addr;
  assign mem_wb_b.rd_wdata = ex_pkt_r.mem ? s_mrdata : ex_pkt_r.ex_out;
  assign mem_wb_b.is_halt = ex_pkt_r.is_halt;
  always_ff @(posedge clk) if (~be_stall) mem_wb <= mem_wb_b;

  assign rd_wr    = mem_wb_vld & mem_wb.req_rd;
  assign rd_addr  = mem_wb.rd_addr;
  assign rd_wdata = mem_wb.rd_wdata;

  assign wb_fwd.valid = mem_wb_vld & mem_wb.req_rd & (|mem_wb.rd_addr);
  assign wb_fwd.addr  = mem_wb.rd_addr;
  assign wb_fwd.data  = mem_wb.rd_wdata;

  assign skid_vld_en = rst | ~be_stall;
  assign skid_vld_b = ~rst & mem_wb_vld;

  assign skid_b.req_rd   = mem_wb.req_rd & (|mem_wb.rd_addr);
  assign skid_b.rd_addr  = mem_wb.rd_addr;
  assign skid_b.rd_wdata = mem_wb.rd_wdata;

  always_ff @(posedge clk) if (skid_vld_en) skid_vld <= skid_vld_b;
  always_ff @(posedge clk) if (~be_stall) skid <= skid_b;

  assign skid_fwd.valid = skid_vld & skid.req_rd;
  assign skid_fwd.addr  = skid.rd_addr;
  assign skid_fwd.data  = skid.rd_wdata;

  assign halt_en = rst | (~halt);
  assign halt_b  = ~rst & mem_wb.is_halt & mem_wb_vld;
  always_ff @(posedge clk) if (halt_en) halt <= halt_b;
endmodule
