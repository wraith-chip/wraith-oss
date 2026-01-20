//  SPDX-License-Identifier: MIT
//  rvtu_fe.sv — RVTU Front End
//  Owner: Pradyun Narkadamilli

module rvtu_fe
  import rv_pkg::*;
#(
    parameter pc_init = 'h40000000
) (
    input clk,
    input rst,

    // mem arb interface
    output logic [31:0] maddr,
    input        [31:0] mrdata,
    input               mresp,

    // EX pkt
    output logic      instr_vld,
    output instrPkt_t instr_o,

    // stall itf
    output logic fe_stall,
    input        glb_stall,

    // flush
    input        flush,
    input [31:0] flush_addr,

    // RF itf
    output logic [ 4:0] rs1_addr,
    input        [31:0] rs1_rdata,

    output logic [ 4:0] rs2_addr,
    input        [31:0] rs2_rdata
);
  logic [31:0] pc, pc_b;
  logic pc_en;
  logic pending_flush, pending_flush_b, pending_flush_en;

  logic [31:0] maddr_r, maddr_b;
  logic        maddr_en;

  logic        dec_vld;
  rvInstrFmt_u dec_idata;

  assign pc_en = rst | (~glb_stall & ~pending_flush & mresp) | flush;
  assign pc_b  = rst ? pc_init : (flush ? flush_addr : pc + 'd4);
  always_ff @(posedge clk) if (pc_en) pc <= pc_b;

  assign pending_flush_b  = rst ? '0 : ~mresp;
  assign pending_flush_en = rst | mresp | flush;
  always_ff @(posedge clk) if (pending_flush_en) pending_flush <= pending_flush_b;

  // [WARN] may need to add a flush condition
  assign maddr_en = rst | mresp;
  assign maddr    = ((~glb_stall) & mresp) ? maddr_b : maddr_r;
  assign maddr_b  = 32'(pc_en ? pc_b : pc);
  always_ff @(posedge clk) if (maddr_en) maddr_r <= maddr_b;

  assign fe_stall  = pending_flush | ~mresp;

  assign dec_vld   = ~rst & ~flush & mresp;
  assign dec_idata = rvInstrFmt_u'(mrdata);

  // ---
  // Decode logic & RF
  // ---

  logic instr_vld_b, instr_vld_en;
  instrPkt_t   instr_b;
  rvInstrFmt_u dec_instr;

  assign rs1_addr = dec_instr.r.rs1;
  assign rs2_addr = dec_instr.r.rs2;

  always_comb begin
    instr_b = 'x;

    instr_b.iaddr = maddr_r;
    instr_b.idata = dec_idata;

    instr_b.rs1_data = rs1_rdata;
    instr_b.rs2_data = rs2_rdata;

    dec_instr    = rvInstrFmt_u'(dec_idata);
    instr_b.fsel = rvAluOp_t'(dec_instr.i.funct3);

    case (dec_idata.i.opcode)
      lui: begin
        instr_b.req_rs1 = '0;
        instr_b.req_rs2 = '0;
        instr_b.req_rd  = '1;

        instr_b.use_pc  = '0;
        instr_b.use_imm = '1;
      end

      auipc, jal: begin
        instr_b.req_rs1 = '0;
        instr_b.req_rs2 = '0;
        instr_b.req_rd = '1;

        instr_b.use_pc = '1;
        instr_b.use_imm = '1;

        instr_b.fsel = add;
      end

      jalr, aluimm: begin
        instr_b.req_rs1 = '1;
        instr_b.req_rs2 = '0;
        instr_b.req_rd  = '1;

        instr_b.use_pc  = '0;
        instr_b.use_imm = '1;
      end


      br: begin
        instr_b.req_rs1 = '1;
        instr_b.req_rs2 = '1;
        instr_b.req_rd = '0;

        instr_b.use_pc = '1;
        instr_b.use_imm = '1;

        instr_b.fsel = add;
      end

      st: begin
        instr_b.req_rs1 = '1;
        instr_b.req_rs2 = '1;
        instr_b.req_rd = '0;

        instr_b.use_pc = '0;
        instr_b.use_imm = '1;

        instr_b.fsel = add;
      end

      ld: begin
        instr_b.req_rs1 = '1;
        instr_b.req_rs2 = '0;
        instr_b.req_rd = '1;

        instr_b.use_pc = '0;
        instr_b.use_imm = '1;

        instr_b.fsel = add;
      end

      alu: begin
        instr_b.req_rs1 = '1;
        instr_b.req_rs2 = '1;
        instr_b.req_rd  = '1;

        instr_b.use_pc  = '0;
        instr_b.use_imm = '0;
      end

      default: ;
    endcase
  end

  assign instr_vld_en = rst | ~glb_stall;
  always_ff @(posedge clk) if (instr_vld_en) instr_vld <= dec_vld;
  always_ff @(posedge clk) if (~glb_stall) instr_o <= instr_b;
endmodule
