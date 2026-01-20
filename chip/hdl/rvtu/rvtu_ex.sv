//  SPDX-License-Identifier: MIT
//  rvtu_ex.sv — Execute Stage
//  Owner: Pradyun Narkadamilli

module rvtu_ex
  import rv_pkg::*;
#(
    parameter logic [4:0] packet1_id = 'd11,
    parameter logic [4:0] packet2_id_off = 'd12
) (
    input clk,
    input rst,

    // Decode Input
    input logic      instr_vld,
    input instrPkt_t instr_i,

    // Mem Output
    output logic      ex_vld,
    output exMemPkt_t ex_pkt,

    // Flush
    output logic        flush,
    output logic [31:0] flush_addr,

    // MUL egress interface
    output logic        eg_empty,
    input  logic        eg_deq,
    output logic [35:0] eg_pkt,

    // MUL ingress interface
    input               ig_empty,
    output logic        ig_deq,
    input        [35:0] ig_pkt,

    // Div Arb interface
    output logic        div_req,
    output logic [31:0] div_src1,
    output logic [31:0] div_src2,
    output logic [ 1:0] div_fsel,

    input        div_resp,
    input [31:0] div_out,

    // Forwarding Packet
    input        ex_mem_has_ld,
    output logic ex_req_mem_fwd,
    input  fwd_t mem_fwd,
    input  fwd_t wb_fwd,
    input  fwd_t skid_fwd,

    // Stall
    input  glb_stall,
    output ex_stall
);
  rvOpclass_t opclass;
  assign opclass = get_opclass(instr_i.idata);

  logic [31:0] rs1, rs2, src1, src2, add_out, alu_out;

  assign rs1  = (mem_fwd.valid & (mem_fwd.addr == instr_i.idata.r.rs1))   ? mem_fwd.data :
                (wb_fwd.valid & (wb_fwd.addr == instr_i.idata.r.rs1))     ? wb_fwd.data  :
                (skid_fwd.valid & (skid_fwd.addr == instr_i.idata.r.rs1)) ? skid_fwd.data : instr_i.rs1_data;

  assign rs2  = (mem_fwd.valid & (mem_fwd.addr == instr_i.idata.r.rs2))   ? mem_fwd.data :
                (wb_fwd.valid & (wb_fwd.addr == instr_i.idata.r.rs2))     ? wb_fwd.data  :
                (skid_fwd.valid & (skid_fwd.addr == instr_i.idata.r.rs2)) ? skid_fwd.data : instr_i.rs2_data;

  assign ex_req_mem_fwd = instr_vld & ((mem_fwd.addr == instr_i.idata.r.rs1 & instr_i.req_rs1) |
                                       (mem_fwd.addr == instr_i.idata.r.rs2 & instr_i.req_rs2));

  assign src1 = (instr_i.use_pc) ? instr_i.iaddr : rs1;
  assign src2 = (instr_i.use_imm) ? get_imm(instr_i.idata) : rs2;

  always_comb begin
    add_out = (instr_i.req_rs2 & ~instr_i.use_imm & instr_i.idata[30]) ? src1 - src2 : src1 + src2;

    if (instr_i.idata.i.opcode == lui) begin
      alu_out = src2;
    end else begin
      unique case (instr_i.fsel)
        add: alu_out = add_out;
        sllOp: alu_out = src1 << src2[4:0];
        slt: alu_out = 32'($signed(src1) < $signed(src2));
        sltu: alu_out = 32'(src1 < src2);
        xorOp: alu_out = src1 ^ src2;
        srlOp:
        alu_out = (instr_i.idata[30] ?
                   $unsigned($signed(src1) >>> src2[4:0]) : (src1 >>> src2[4:0]));
        orOp: alu_out = src1 | src2;
        andOp: alu_out = src1 & src2;
        default: ;
      endcase
    end
  end

  logic br_en;
  always_comb begin
    unique case (rvBrOp_t'(instr_i.idata.i.funct3))
      beq: br_en = (rs1 == rs2);
      bne: br_en = (rs1 != rs2);
      blt: br_en = $signed(rs1) < $signed(rs2);
      bge: br_en = $signed(rs1) >= $signed(rs2);
      bltu: br_en = rs1 < rs2;
      bgeu: br_en = rs1 >= rs2;
      default: br_en = 'x;
    endcase
  end

  assign flush      = instr_vld & (opclass == ctrl) & ((instr_i.idata.i.opcode != br) | br_en) & ~glb_stall;
  assign flush_addr = add_out;

  enum logic [2:0] {
    PKT1,
    PKT2,
    WAIT
  }
      mul_state, mul_state_b;

  logic mul_state_en;

  logic eg_fifo_full;
  logic eg_fifo_enq;
  logic [35:0] eg_fifo_pkt;
  fifo #(
      .DEPTH(1),
      .WIDTH(36)
  ) u_fifo (
      .clk    (clk),
      .rst    (rst),
      .enqueue(eg_fifo_enq),
      .wdata  (eg_fifo_pkt),
      .dequeue(eg_deq),
      .rdata  (eg_pkt),
      .full   (eg_fifo_full),
      .empty  (eg_empty)
  );

  logic memdep;
  assign memdep = ex_req_mem_fwd & ex_mem_has_ld;

  always_comb begin
    eg_fifo_enq = '0;
    eg_fifo_pkt = 'x;

    ig_deq = '0;

    if (rst) begin
      mul_state_b = PKT1;
    end else begin
      mul_state_b = mul_state;

      case (mul_state)
        PKT1: begin
          eg_fifo_pkt = {4'(packet1_id), rs1};

          if (instr_vld & ~eg_fifo_full & (opclass == mul) & ~memdep) begin
            eg_fifo_enq = '1;
            mul_state_b = PKT2;
          end
        end

        PKT2: begin
          eg_fifo_pkt = {4'(packet2_id_off + 2'(instr_i.idata.i.funct3)), rs2};

          if (~eg_fifo_full) begin
            eg_fifo_enq = '1;
            mul_state_b = WAIT;
          end
        end

        WAIT: begin
          if (~ig_empty & ~glb_stall) begin
            ig_deq = '1;
            mul_state_b = PKT1;
          end
        end
      endcase
    end
  end

  assign mul_state_en = rst | instr_vld;
  always_ff @(posedge clk) if (mul_state_en) mul_state <= mul_state_b;

  assign div_req  = instr_vld & (opclass == div) & ~memdep & glb_stall;
  assign div_src1 = rs1;
  assign div_src2 = rs2;
  assign div_fsel = instr_i.fsel[1:0];

  logic [31:0] ex_out;
  always_comb begin
    case (opclass)
      aluC: ex_out = alu_out;
      mul: ex_out = ig_pkt[31:0];
      div: ex_out = div_out;
      mem: ex_out = alu_out;
      ctrl: ex_out = instr_i.iaddr + 'd4;
      default: ex_out = 'x;
    endcase
  end

  assign ex_vld = instr_vld & ~glb_stall;
  always_comb begin
    ex_pkt.req_rd = instr_i.req_rd;
    ex_pkt.rd_addr = instr_i.idata.i.rd;
    ex_pkt.ex_out = ex_out;

    ex_pkt.mem = opclass == mem;
    ex_pkt.fsel = rvLdOp_t'(instr_i.idata.i.funct3);
    ex_pkt.rs2 = rs2;

    ex_pkt.is_halt = flush & (flush_addr == instr_i.iaddr);
  end

  assign ex_stall = instr_vld &
                    ((opclass == mul & (mul_state != WAIT | ig_empty)) |
                    (opclass == div & ~div_resp));
endmodule
