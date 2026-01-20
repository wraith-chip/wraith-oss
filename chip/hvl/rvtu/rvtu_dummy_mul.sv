module rvtu_dummy_mul
(
  input               clk,
  input               rst,

  output logic        eg_empty,
  input  logic        eg_deq,
  output logic [35:0] eg_pkt,

  input               ig_empty,
  output logic        ig_deq,
  input [35:0]        ig_pkt,

  output logic        init_done
);
  logic op_done;
  logic eg_full;
  logic [35:0] eg_wpkt;

  logic pktbuf_vld;
  logic [35:0] pktbuf;
  logic [31:0] src1;

  fifo #(
    .DEPTH      (1),
    .WIDTH      (36)
  ) u_fifo (
    .clk        (clk),
    .rst        (rst),
    .enqueue    (op_done),
    .wdata      (eg_wpkt),
    .dequeue    (eg_deq),
    .rdata      (eg_pkt),
    .full       (eg_full),
    .empty      (eg_empty)
  );

  assign ig_deq = '1;

  always_ff @ (posedge clk) begin
    if (rst) begin
      pktbuf_vld <= '0;
    end else begin
      if (~eg_full | ~pktbuf_vld) begin
        pktbuf_vld <= ~ig_empty;
        pktbuf <= ig_pkt;
      end

      if (pktbuf_vld & (pktbuf[35:32] == 'd11)) begin
        src1 <= pktbuf[31:0];
      end

      if (pktbuf_vld & pktbuf[35:32] < 'd10)
        $error("[err] invalid mul pid in dummy @ %t", $time);
    end
  end

  always_comb begin
    op_done = '0;
    eg_wpkt = 'x;

    if (pktbuf_vld & (pktbuf[35:32] != 'd11)) begin
      automatic logic [2:0] fsel = 3'(pktbuf[35:32] - 'd12);

      case (fsel)
        'b00: eg_wpkt = {4'b0, 32'(src1 * pktbuf[31:0])};
        'b01: eg_wpkt = {4'b0, 32'((33'($signed(src1)) * 33'($signed(pktbuf[31:0]))) >>> 32)};
        'b10: eg_wpkt = {4'b0, 32'((33'($signed(src1)) * 33'(pktbuf[31:0])) >>> 32)};
        'b11: begin
          automatic logic [63:0] res = src1 * pktbuf[31:0];
          eg_wpkt = {4'b0, res[63:32]};
        end
        default: eg_wpkt = 'x;
      endcase

      op_done = '1;
    end
  end

  assign init_done = '1;
endmodule
