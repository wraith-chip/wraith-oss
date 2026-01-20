module rvtu_isolated_sim;
  parameter logic USE_DUMMY_MUL = '0;

  logic clk, rst, init_done;

  always #1 clk = ~clk;
  initial clk = '0;

  initial begin
    $fsdbDumpfile("dump.fsdb");
    $fsdbDumpvars(0, "+all");

    rst <= '1;
    @(posedge clk);
    rst <= '0;
  end

  logic halt, err;

  always_ff @(posedge clk) begin
    if (halt) begin
      $display("program done at %t", $time);
      $finish;
    end
    if (err) begin
      $error("[err] at %t", $time);
      $finish;
    end
  end

  logic mrd, mresp;
  logic [3:0] mwr;
  logic [31:0] maddr, mwdata, mrdata;

  logic        eg_empty, eg_deq, ig_empty, ig_deq;
  logic [35:0] eg_pkt, ig_pkt;

  logic        div_req, div_resp;
  logic [31:0] div_src1, div_src2, div_out;
  logic [1:0]  div_fsel;

  rvtu_harness dut (
    .clk,
    .rst      (rst | ~init_done),

    .halt,
    .err,

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

    .div_req  (div_req),
    .div_src1 (div_src1),
    .div_src2 (div_src2),
    .div_fsel (div_fsel),

    .div_resp (div_resp),
    .div_out  (div_out)
  );

  simple_memory #(
    .LOADMEMFILE (1),
    .STALL       (1),
    .MAXWAIT     (10)
  ) mem (.*);

  generate
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
  endgenerate

  rvtu_div_arb div (
    .clk, .rst,

    .a_req  (div_req),
    .a_src1 (div_src1),
    .a_src2 (div_src2),
    .a_fsel (div_fsel),

    .a_resp (div_resp),
    .a_out  (div_out),

    .b_req  ('0),
    .b_src1 ('x),
    .b_src2 ('x),
    .b_fsel ('x),

    .b_resp (),
    .b_out  ()
  );

  rvtu_cover #(
    .dumpfile("coverrep_isolated")
  ) covermod (
    .clk,
    .rst,

    .glb_stall(dut.pipe.glb_stall),
    .fe_stall (dut.pipe.fe_stall),
    .ex_stall (dut.pipe.ex_stall),
    .be_stall (dut.pipe.be_stall)
  );


endmodule
