//  SPDX-License-Identifier: MIT
//  rvtu_div_arb.sv — Arbited Divider
//  Owner: Pradyun Narkadamilli

module rvtu_div_arb
  import rv_pkg::*;
(
    input clk,
    input rst,

    input        a_req,
    input [31:0] a_src1,
    input [31:0] a_src2,
    input [ 1:0] a_fsel,

    output logic        a_resp,
    output logic [31:0] a_out,

    input        b_req,
    input [31:0] b_src1,
    input [31:0] b_src2,
    input [ 1:0] b_fsel,

    output logic        b_resp,
    output logic [31:0] b_out
);
  logic prio_en;
  typedef enum logic {
    A,
    B
  } div_prio_t;
  div_prio_t prio, prio_b;

  logic active_req, other_req;
  logic div_start, div_complete, div0;
  logic [32:0] div_src1, div_src2, div_quotient, div_rem;
  logic [31:0] div_quotient_sat;
  logic [ 3:0] div_fsel;

  logic running, running_b;

  assign active_req = prio == A ? a_req : b_req;
  assign other_req = prio == A ? b_req : a_req;

  assign prio_b = rst ? A : div_prio_t'(prio ^ (~active_req & (other_req | (div_complete & running))));
  always_ff @(posedge clk) prio <= prio_b;

  assign div_src1 = (prio == A) ?
                    {~a_fsel[0] & a_src1[31], a_src1} :
                    {~b_fsel[0] & b_src1[31], b_src1};
  assign div_src2 = (prio == A) ?
                    {~a_fsel[0] & a_src2[31], a_src2} :
                    {~b_fsel[0] & b_src2[31], b_src2};

  DW_div_seq #(
      .a_width    (33),
      .b_width    (33),
      .tc_mode    (1),
      .num_cyc    (6),
      .rst_mode   (1),
      .input_mode (1),
      .early_start(1)
  ) div_fu (
      .clk,
      .rst_n      (~rst),
      .hold       ('0),
      .start      (div_start),
      .a          (div_src1),
      .b          (div_src2),
      .complete   (div_complete),
      .divide_by_0(div0),
      .quotient   (div_quotient),
      .remainder  (div_rem)
  );

  assign running_b = ~rst & active_req;
  always_ff @(posedge clk) running <= running_b;

  assign div_start = active_req & ~running;

  assign a_resp = div_complete & running & (prio == A);
  assign b_resp = div_complete & running & (prio == B);

  assign div_quotient_sat = div0 ? '1 : div_quotient[31:0];
  assign a_out = a_fsel[1] ? div_rem[31:0] : div_quotient_sat;
  assign b_out = b_fsel[1] ? div_rem[31:0] : div_quotient_sat;
endmodule
