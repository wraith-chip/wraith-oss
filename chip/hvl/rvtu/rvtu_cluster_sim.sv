module rvtu_cluster_sim;
  import rv_pkg::*;
  import pe_types::*;

  logic clk, rst;

  logic halt[2], halt_r[2], err[2];
  logic init_done[2];

  always #500ps clk = ~clk;
  initial clk = '0;

  initial begin
    $fsdbDumpfile("dump.fsdb");
    $fsdbDumpvars(0, "+all");

    rst <= '1;
    @(posedge clk);
    rst <= '0;
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      halt_r[0] <= '0;
      halt_r[1] <= '0;
    end else begin
      halt_r[0] <= halt_r[0] | halt[0];
      halt_r[1] <= halt_r[1] | halt[1];
    end
  end

  always_ff @(posedge clk) begin
    if (~rst & halt_r[0] & halt_r[1]) begin
      $display("program done at %t", $time);
      $finish;
    end
    if (~rst & (err[0] | err[1])) begin
      $error("[err] at %t", $time);
      $finish;
    end
  end

  logic dfp_read, dfp_write, dfp_ack, dfp_resp;
  logic [31:0] dfp_rdata, dfp_wdata;

  logic ig_empty[2], eg_empty[2], ig_deq[2], eg_deq[2];
  packet_t ig_rdata[2], eg_rdata[2];

  rvtu_pair_arb_if dummy_arb_if();

  assign dfp_read  = dummy_arb_if.dfp_read;
  assign dfp_write = dummy_arb_if.dfp_write;
  assign dfp_wdata = dummy_arb_if.dfp_wdata;

  assign dummy_arb_if.dfp_rdata       = dfp_rdata;
  assign dummy_arb_if.dfp_ack         = dfp_ack;
  assign dummy_arb_if.dfp_rdata_valid = dfp_resp;

  rvtu_pair #(
    .pcs   ('{'h40000000, 'h80000000}),
    .DEBUG (1)
  ) pair (
    .clk,
    .rst(rst),

    .rvtu_rst_a(~init_done[0]),
    .rvtu_rst_b(~init_done[1]),

    .mul_eg_empty (eg_empty),
    .mul_eg_rdata (eg_rdata),
    .mul_eg_deq   (eg_deq),

    .mul_ig_empty (ig_empty),
    .mul_ig_rdata (ig_rdata),
    .mul_ig_deq   (ig_deq),

    .arb_bus      (dummy_arb_if),

    .halt         (halt)
  );

  assign err  = pair.err;

  autoconfig_mul_pe a_mul_pe (
    .clk, .rst,

    .eg_empty (ig_empty[0]),
    .eg_deq   (ig_deq[0]),
    .eg_pkt   (ig_rdata[0]),

    .ig_empty (eg_empty[0]),
    .ig_deq   (eg_deq[0]),
    .ig_pkt   (eg_rdata[0]),

    .init_done (init_done[0])
  );

  autoconfig_mul_pe b_mul_pe (
    .clk, .rst,

    .eg_empty (ig_empty[1]),
    .eg_deq   (ig_deq[1]),
    .eg_pkt   (ig_rdata[1]),

    .ig_empty (eg_empty[1]),
    .ig_deq   (eg_deq[1]),
    .ig_pkt   (eg_rdata[1]),

    .init_done (init_done[1])
  );

  transacted_memory #(
    .SEED        ('hECEBCAFE),
    .STALL       (1),
    .MAXWAIT     (10)
  ) mem (
    .clk, .rst,

    .dfp_read  (dfp_read),
    .dfp_write (dfp_write),
    .dfp_wdata (dfp_wdata),
    .dfp_ack   (dfp_ack),

    .dfp_resp  (dfp_resp),
    .dfp_rdata (dfp_rdata)
  );
endmodule
