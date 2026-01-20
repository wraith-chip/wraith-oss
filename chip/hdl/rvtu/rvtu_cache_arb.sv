//  SPDX-License-Identifier: MIT
//  rvtu_cache_arb.sv — Shared Cache Arbiter
//  Owner: Pradyun Narkadamilli

module rvtu_cache_arb
  import rv_pkg::*;
(
    input clk,
    input rst,

    input glb_stall,

    input        [31:0] i_maddr,
    output logic        i_mresp,
    output logic [31:0] i_mrdata,

    input        [31:0] d_maddr,
    input               d_mrd,
    input        [ 3:0] d_mwr,
    input        [31:0] d_mwdata,
    output logic        d_mresp,
    output logic [31:0] d_mrdata,

    output logic [31:0] c_maddr,
    output logic        c_mrd,
    output logic [ 3:0] c_mwr,
    output logic [31:0] c_mwdata,
    input               c_mresp,
    input        [31:0] c_mrdata
);
  // -- assumptions --
  // once out of reset, we are ALWAYS fetching from the cache (I or D)
  // cache can ignore our request during reset

  logic owner_en;
  enum logic {
    DATA,
    INSTR
  }
      owner, owner_b;

  logic d_mresp_b;

  logic d_mrdata_en;

  assign owner_en = rst | c_mresp;
  assign owner_b  = ((|d_mwr) | d_mrd) & ~d_mresp & (owner == INSTR) ? DATA : INSTR;
  always_ff @(posedge clk) if (owner_en) owner <= rst ? INSTR : owner_b;

  // NOTE: FSM cache -> change this to owner for critpath improvement
  logic rst_r; // flop this so that signal is off of the reset path
  always_ff @(posedge clk) rst_r <= rst;

  assign c_maddr  = (owner == DATA) ? d_maddr : i_maddr;
  assign c_mrd    = ((owner != DATA) | d_mrd) & ~c_mresp & ~rst_r;
  assign c_mwr    = {4{(owner == DATA) & ~c_mresp}} & d_mwr;
  assign c_mwdata = d_mwdata;

  assign i_mresp  = c_mresp & (owner == INSTR);
  assign i_mrdata = c_mrdata;

  assign d_mresp_b = ~rst & (d_mresp ? glb_stall : (c_mresp & (owner == DATA)));
  always_ff @(posedge clk) d_mresp <= d_mresp_b;

  assign d_mrdata_en = c_mresp & (owner == DATA);
  always_ff @(posedge clk) if (d_mrdata_en) d_mrdata <= c_mrdata;
endmodule
