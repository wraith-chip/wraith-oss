module rvtu_pair_sim;
  parameter logic USE_DUMMY_MUL = '0;

  logic clk, rst;

  always #1 clk = ~clk;
  initial clk = '0;

  initial begin
    $fsdbDumpfile("dump.fsdb");
    $fsdbDumpvars(0, "+all");

    rst <= '1;
    @(posedge clk);
    rst <= '0;
  end

  logic halt[2], err[2];

  always_ff @(posedge clk) begin
    if (halt[0] & halt[1]) begin
      $display("program done at %t", $time);
      $finish;
    end
    if (err[0] | err[1]) begin
      $error("[err] at %t", $time);
      $finish;
    end
  end

  logic        div_req[2], div_resp[2];
  logic [31:0] div_src1[2], div_src2[2], div_out[2];
  logic [1:0]  div_fsel[2];

  rvtu_div_arb div (
    .clk, .rst,

    .a_req  (div_req[0]),
    .a_src1 (div_src1[0]),
    .a_src2 (div_src2[0]),
    .a_fsel (div_fsel[0]),

    .a_resp (div_resp[0]),
    .a_out  (div_out[0]),

    .b_req  (div_req[1]),
    .b_src1 (div_src1[1]),
    .b_src2 (div_src2[1]),
    .b_fsel (div_fsel[1]),

    .b_resp (div_resp[1]),
    .b_out  (div_out[1])
  );

  genvar i;

  generate
    for (i=0; i<2; i++) begin : rvtu_subharnesses
      logic init_done;

      logic mrd, mresp;
      logic [3:0] mwr;
      logic [31:0] maddr, mwdata, mrdata;

      logic        eg_empty, eg_deq, ig_empty, ig_deq;
      logic [35:0] eg_pkt, ig_pkt;

      rvtu_harness #(
        .dumpfile(i == 0 ? "rvtu0_commit.log" : "rvtu1_commit.log")
      ) dut (
        .clk,
        .rst      (rst | ~init_done),

        .halt     (halt[i]),
        .err      (err[i]),

        .maddr,
        .mrd,
        .mwr,
        .mwdata,
        .mresp,
        .mrdata,

        .eg_empty (eg_empty),
        .eg_deq   (eg_deq),
        .eg_pkt   (eg_pkt),

        .ig_empty (ig_empty),
        .ig_deq   (ig_deq),
        .ig_pkt   (ig_pkt),

        .div_req  (div_req[i]),
        .div_src1 (div_src1[i]),
        .div_src2 (div_src2[i]),
        .div_fsel (div_fsel[i]),

        .div_resp (div_resp[i]),
        .div_out  (div_out[i])
      );

      simple_memory #(
        .LOADMEMFILE (1),
        .SEED        (i == 0 ? 'hECEBCAFE : 'hECE411),
        // format doesn't work here for simulation for some reason??
        .PLUSARGS    (i == 0 ? "SIM_MEMFILE0=%s" : "SIM_MEMFILE1=%s"),
        .STALL       (1),
        .MAXWAIT     (10)
      ) mem (.*);

      if (USE_DUMMY_MUL)
        rvtu_dummy_mul mul (
          .clk, .rst,

          .eg_empty (ig_empty),
          .eg_deq   (ig_deq),
          .eg_pkt   (ig_pkt),

          .ig_empty (eg_empty),
          .ig_deq   (eg_deq),
          .ig_pkt   (eg_pkt),

          .init_done (init_done)
        );
      else
        autoconfig_mul_pe mul_pe (
          .clk, .rst,

          .eg_empty (ig_empty),
          .eg_deq   (ig_deq),
          .eg_pkt   (ig_pkt),

          .ig_empty (eg_empty),
          .ig_deq   (eg_deq),
          .ig_pkt   (eg_pkt),

          .init_done (init_done)
        );
    end
  endgenerate
endmodule
