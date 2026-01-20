module top_tb;
	logic top_clk;
	logic top_reset;
  int timeout;
  logic fb_en;
  logic fb_d_in_vld;
  logic fb_d_in;
  logic fb_d_clsc;
  logic fb_d_out;
  logic fb_d_out_vld;
  logic led;
  logic [2:0] test_mmmu_fsm;

  logic rvtu_rst_a, rvtu_rst_b;

  initial top_clk = 1'b0;
  always #5ns top_clk = ~top_clk;

  tri [31:0] dbus_TRI;

  top dut (
      .clk (top_clk),
      .rst (top_reset),
      .dbus(dbus_TRI),
      .rvtu_rst_a(rvtu_rst_a),
      .rvtu_rst_b(rvtu_rst_b),
      .fb_en(fb_en),
      .fb_d_in_vld(fb_d_in_vld),
      .fb_d_in(fb_d_in),
      .fb_d_clsc(fb_d_clsc),
      .fb_d_out(fb_d_out),
      .fb_d_out_vld(fb_d_out_vld),
      .led(led),
      .test_mmmu_state(test_mmmu_fsm)
  );
  defparam dut.rvtu_pair_.DEBUG = 'b1;

  `include "../top_sim_tasks/bus_trans.svh"
  `include "../top_sim_tasks/drive_csr.svh"
  `include "../top_sim_tasks/spm_transactor.svh"
  `include "../top_sim_tasks/file_io.svh"
  `include "../top_sim_tasks/rvtu.svh"

  always_ff @(posedge top_clk) begin
    if (top_reset) begin
      timeout <= 400000000;
    end else begin
      timeout <= timeout -1;
      if (timeout == 0) begin
        $display("[error] TB Timed out");
        $fatal;
      end
    end
  end

  logic rvtu0_done, rvtu1_done;

  initial begin
    $fsdbDumpfile("dump.fsdb");
    $fsdbDumpvars(0, "+all");

    fb_en <= '0;
    fb_d_in_vld <= '0;
    top_reset <= '1;
    rvtu_rst_a <= '1;
    rvtu_rst_b <= '1;

    repeat (10) @(negedge clk);
    top_reset <= '0;
    @(negedge clk);

    mesh_setup();
    @(negedge clk);

    handler_cachewb();
    handle_cachemiss();
    repeat (10) @(negedge clk); // assuming this is to prevent race condition

    rvtu_rst_a <= '0;
    rvtu_rst_b <= '0;
    @(negedge clk);

    run_kernel();

    rvtu0_done <= '0;
    rvtu1_done <= '0;
    @(negedge clk);

    while (~rvtu0_done | ~rvtu1_done) begin
      if (~rvtu0_done) begin
        csr_read_rvtu0_completion(rvtu0_done);
        @(negedge clk);
        if (rvtu0_done) $display("[inf] RVTU0 read as finished @ %t", $time);
      end
      if (~rvtu1_done) begin
        csr_read_rvtu1_completion(rvtu1_done);
        @(negedge clk);
        if (rvtu1_done) $display("[inf] RVTU1 read as finished @ %t", $time);
      end
      repeat(1000) @(negedge clk);
    end

    $finish();
  end
endmodule
