//  SPDX-License-Identifier: MIT
//  rvtu_harness.sv — Addl verif logic around RVTU
//  Owner: Pradyun Narkadamilli

module rvtu_harness
import rv_pkg::*;
#(
  parameter string dumpfile = "commit.log",
  parameter int notif_interval = 1000,
  parameter logic [31:0] pc_init = 'h40000000
) (
  input logic         clk,
  input logic         rst,

  output logic        halt,
  output logic        err,

  // cache port
  output logic [31:0] maddr,
  output logic        mrd,
  output logic [3:0]  mwr,
  output logic [31:0] mwdata,
  input               mresp,
  input [31:0]        mrdata,

  // mul egress port
  output logic        eg_empty,
  input               eg_deq,
  output logic [35:0] eg_pkt,

  // mul ingress port
  input               ig_empty,
  output logic        ig_deq,
  input [35:0]        ig_pkt,

  // div arbiter port
  output logic        div_req,
  output logic [31:0] div_src1,
  output logic [31:0] div_src2,
  output logic [1:0]  div_fsel,

  input               div_resp,
  input [31:0]        div_out
);
  logic rvfi_pipe_en;
  pipeRvfiPkt_t exmem_b, exmem, memwb_b, memwb;

  rvfiPkt_t     monpkt;
  rvInstrFmt_u  isn_union;
  assign isn_union.word = memwb.isn;

  rvtu #(
    .pc_init (pc_init)
  ) pipe (.*);

  always_comb begin
    exmem_b = '0;

    exmem_b.isn = pipe.fe.instr_o.idata;

    exmem_b.rs1 = pipe.fe.instr_o.req_rs1 ? pipe.fe.instr_o.idata.r.rs1 : '0;
    exmem_b.rs1_rdata = pipe.fe.instr_o.req_rs1 ? pipe.ex.rs1 : '0;
    exmem_b.rs2 = pipe.fe.instr_o.req_rs2 ? pipe.fe.instr_o.idata.r.rs2 : '0;
    exmem_b.rs2_rdata = pipe.fe.instr_o.req_rs2 ? pipe.ex.rs2 : '0;
    exmem_b.rd = pipe.fe.instr_o.req_rd ? pipe.fe.instr_o.idata.r.rd : '0;

    exmem_b.pc_rdata = pipe.fe.instr_o.iaddr;
    exmem_b.pc_wdata = pipe.ex.flush ? pipe.ex.flush_addr : (pipe.fe.instr_o.iaddr + 'd4);
  end

  always_comb begin
    memwb_b = exmem;
    memwb_b.rd_wdata = pipe.mem_wb.ex_pkt_r.req_rd ? pipe.mem_wb.mem_wb_b.rd_wdata : '0;

    if (pipe.mem_wb.ex_pkt_r.mem) begin
      memwb_b.mem_addr  = pipe.mem_wb.ex_pkt_r.ex_out;
      memwb_b.mem_rdata = pipe.mem_wb.mrdata;
      memwb_b.mem_wdata = pipe.mem_wb.mwdata;
    end
  end

  assign rvfi_pipe_en = ~pipe.mem_wb.be_stall;
  always_ff @ (posedge clk) if (rvfi_pipe_en) exmem <= exmem_b;
  always_ff @ (posedge clk) if (rvfi_pipe_en) memwb <= memwb_b;

  logic [63:0] order;
  always_ff @ (posedge clk) begin
    if (rst) order <= '0;
    else if (monpkt.valid) order <= order + 'd1;
  end

  always_comb begin
    monpkt = '0;

    monpkt.valid = ~rst & pipe.mem_wb.mem_wb_vld & ~pipe.mem_wb.be_stall;
    monpkt.ord   = order;
    monpkt.isn   = memwb.isn;

    monpkt.rs1       = memwb.rs1;
    monpkt.rs2       = memwb.rs2;
    monpkt.rs1_rdata = memwb.rs1_rdata;
    monpkt.rs2_rdata = memwb.rs2_rdata;

    monpkt.rd = memwb.rd;
    monpkt.rd_wdata = |memwb.rd ? memwb.rd_wdata : '0;

    monpkt.pc_rdata = memwb.pc_rdata;
    monpkt.pc_wdata = memwb.pc_wdata;

    monpkt.mem_addr = {memwb.mem_addr[31:2], 2'b0};
    monpkt.mem_rdata = memwb.mem_rdata;
    monpkt.mem_wdata = memwb.mem_wdata;

    // TODO: Pull based on address and instruction data
    if (isn_union.i.opcode == ld) begin
      monpkt.mem_rmask = get_ldbasemask(rvLdOp_t'(isn_union.i.funct3)) << memwb.mem_addr[1:0];
    end

    if (isn_union.i.opcode == st) begin
      monpkt.mem_wmask = get_basemask(rvStOp_t'(isn_union.i.funct3)) << memwb.mem_addr[1:0];
    end
  end

  logic [15:0] errcode;
  assign err = |errcode;

  rvfimon rvfi (
    .clock           (clk),
    .reset           (rst),
    .rvfi_valid      (monpkt.valid     ),
    .rvfi_order      (monpkt.ord       ),
    .rvfi_insn       (monpkt.isn       ),
    .rvfi_trap       (monpkt.trap      ),
    .rvfi_halt       (monpkt.halt      ),
    .rvfi_intr       (monpkt.intr      ),
    .rvfi_mode       (monpkt.mode      ),
    .rvfi_rs1_addr   (monpkt.rs1       ),
    .rvfi_rs2_addr   (monpkt.rs2       ),
    .rvfi_rs1_rdata  (monpkt.rs1_rdata ),
    .rvfi_rs2_rdata  (monpkt.rs2_rdata ),
    .rvfi_rd_addr    (monpkt.rd        ),
    .rvfi_rd_wdata   (monpkt.rd_wdata  ),
    .rvfi_pc_rdata   (monpkt.pc_rdata  ),
    .rvfi_pc_wdata   (monpkt.pc_wdata  ),
    .rvfi_mem_addr   (monpkt.mem_addr  ),
    .rvfi_mem_rmask  (monpkt.mem_rmask ),
    .rvfi_mem_wmask  (monpkt.mem_wmask ),
    .rvfi_mem_rdata  (monpkt.mem_rdata ),
    .rvfi_mem_wdata  (monpkt.mem_wdata ),
    .rvfi_mem_extamo (monpkt.mem_extamo),
    .errcode         (errcode          )
  );

  int fd;
  initial begin
    fd = $fopen(dumpfile);
    @(posedge clk iff ~rst);

    while (~halt) begin
      @(posedge clk);

      if (monpkt.valid) begin
        $fwrite(fd, "core   0: 3 0x%h (0x%h)", monpkt.pc_rdata, monpkt.isn);

        if (|monpkt.rd) begin
          $fwrite(fd, " x%0d%s 0x%h",
                  monpkt.rd, (monpkt.rd >= 10) ? "" : " ",monpkt.rd_wdata);
        end

        if ((|monpkt.mem_rmask) | (|monpkt.mem_wmask)) begin
          $fwrite(fd, " mem 0x%h", memwb.mem_addr);
        end

        if (|monpkt.mem_wmask) begin
          case(rvStOp_t'(isn_union.i.funct3))
            sw: $fwrite(fd, " 0x%08h", monpkt.mem_wdata);
            sh: $fwrite(fd, " 0x%04h", 16'(monpkt.mem_wdata >> {memwb.mem_addr[1:0], 3'b0}));
            sb: $fwrite(fd, " 0x%02h", 8'(monpkt.mem_wdata >> {memwb.mem_addr[1:0], 3'b0}));
          endcase
        end

        $fwrite(fd, "\n");

        if (order % notif_interval == 0) $display("[info] commit %0d", order);
      end
    end
  end
endmodule
