module mmmu_transaction_tb;
  import mmmu_types::*;
  import glbl_pkg::*;

  bit clk;
  bit rst;

  initial clk = 1'b1;
  always #500ps clk = ~clk;
  initial rst = 1'b1;

  // Initialize MMMU-Bridge, MMMU-Arbiter

  scratchpad_controller_if spm_bus ();
  rvtu_pair_arb_if rvtu_bus ();

  dbus_meta_t        transaction_type;
  logic              transaction_fin;
  tri         [31:0] dbus_TRI;
  logic       [31:0] arb_out;
  logic       [31:0] incoming_req;
  logic              valid_incoming_req;
  logic              bridge_ack_arb;

  logic       [31:0] dbus_i;  // Input
  logic       [31:0] dbus_o;  // Output
  logic       [31:0] dbus_t;  // Tristate enable. t=0 means drive chipout
  io_tri dbus_io_tri_connector[31:0] (
      .chipout(dbus_TRI),
      .i(dbus_i),
      .o(dbus_o),
      .t(dbus_t)
  );


  logic [31:0] rfile_rdata[NUM_RFILE];
  logic [31:0] wfile_wdata[NUM_WFILE];

  mmmu_bridge dut_bridge (
      .clk(clk),
      .rst(rst),

      .dbus_into_chip(dbus_i),
      .dbus_outa_chip(dbus_o),
      .dbus_tri_en(dbus_t),

      .arb_out(arb_out),
      .valid_incoming_req(valid_incoming_req),
      .incoming_req(incoming_req),
      .bridge_ack_arb(bridge_ack_arb),
      .transaction_fin(transaction_fin),
      .transaction_type(transaction_type),
      .rfile_rdata(rfile_rdata),
      .wfile_wdata(wfile_wdata)
  );

  mmmu_arb dut_arbiter (
      .clk(clk),
      .rst(rst),
      .spm(spm_bus.mmmu_arb),
      .rvtu(rvtu_bus.mmmu_arb),
      .recv_data(incoming_req),
      .recv_data_vld(valid_incoming_req),
      .arb_out(arb_out),
      .bridge_ack(bridge_ack_arb),
      .bridge_fin(transaction_fin),
      .bridge_type(transaction_type)
  );

  always_ff @(posedge clk) begin : POOPOO_DETECTOR
    if (~rst) begin
      if (dut_bridge.fsm == 'x) begin
        $error("FSM State cooked");
        $fatal;
      end
    end
  end

  function automatic logic [31:0] gen_rand_bus_word();
    logic [31:0] randn;
    assert (std::randomize(randn));
    return randn;
  endfunction

  /**
   * This adds another request to the current combination of on-chip requests.
   *
   * It can only be called once per cycle for each `rvtu_num`.
   */
  task automatic initiate_on_chip_request(input dbus_meta_t trans);
    case (trans)
      SPMLEN_spm_wb: begin
        spm_bus.req_out <= 1'b1;
      end

      cacheline_rd_req: begin
        rvtu_bus.dfp_read <= 1'b1;
      end

      cacheline_wb: begin
        rvtu_bus.dfp_write <= 1'b1;
      end

      csr_rd_resp: begin
        $error("a rd_resp should never be raised without an initiating csr_read from offchip");
        $fatal;
      end

      default: begin
        $error("tried to raise unhandled on-chip request");
        $fatal;
      end
    endcase

    $display("Awaiting ACK for cacheline writeback or SPM writeback");
    @(posedge clk iff rvtu_bus.dfp_ack | spm_bus.bus_own_ack);
    case (trans)
      cacheline_wb:     rvtu_bus.dfp_write <= 1'b0;
      cacheline_rd_req: rvtu_bus.dfp_read <= 1'b0;
      SPMLEN_spm_wb:    spm_bus.req_out <= 1'b0;
      default:          $error("poopoo");
    endcase

    if (trans == cacheline_wb) begin
      forever begin
        // Apply some data at the source, we should see it at the output correctly
        rvtu_bus.dfp_wdata <= gen_rand_bus_word();
        @(posedge clk);
        if (dut_arbiter.bridge_fin) begin
          $display("Finished transaction ($wb)!");
          return;
        end
      end
    end else if (trans == SPMLEN_spm_wb) begin
      $display("This works, but the SPM length might not be properly respected if not configured");
      forever begin
        spm_bus.dbus_out <= gen_rand_bus_word();
        @(posedge clk);
        if (dut_arbiter.bridge_fin) begin
          $display("Finished SPM wb!");
          return;
        end
      end
    end

    @(posedge clk iff dut_arbiter.bridge_fin);

    $display("Finished transaction!");
    return;
  endtask

  logic [31:0] ofc_dbus_i;
  logic [31:0] ofc_dbus_o;
  logic [31:0] ofc_dbus_t;
  io_tri ofc_io_tri_connector[31:0] (
      .chipout(dbus_TRI),
      .i(ofc_dbus_i),
      .o(ofc_dbus_o),
      .t(ofc_dbus_t)
  );

  logic [31:0] ofc_o_b;
  logic [31:0] ofc_o;

  assign ofc_dbus_o = ofc_o;

  logic [31:0] ofc_dbus_reg;

  always_ff @(posedge clk) begin
    if (rst) begin
      // NOTE(Ingi): Idk if an offchip driver needs to hold
      // this in reset, this is just pathologically easy for my testcase
      ofc_dbus_reg <= 32'h0000_ffff;
      ofc_o <= 32'h0000_0000;
    end else begin
      ofc_o <= ofc_o_b;

      if (dut_bridge.fsm == poll_wait_bus_clr) begin
        ofc_dbus_reg <= 32'h0000_ffff;
      end else if (dut_bridge.fsm == poll) begin

        if (dut_bridge.bus_select[0]) ofc_dbus_reg <= 32'h0000_0000;
        else if (dut_bridge.bus_select[1]) ofc_dbus_reg <= 32'hffff_ffff;
        else ofc_dbus_reg <= 32'h0000_ffff;
      end else if (dut_bridge.fsm inside {passenger_addr0, passenger_data}) begin
        ofc_dbus_reg <= 32'h0000_0000;
      end else begin
        ofc_dbus_reg <= 32'hffff_ffff;
      end
    end
  end

  assign ofc_dbus_t = ofc_dbus_reg;


  task automatic initiate_off_chip_resp(input dbus_meta_t trans);
    case (trans)
      SPMLEN_spm_write, csr_write, csr_rd_req: begin
        $error("This is out of scope for current testing: send a response type");
        $fatal;
      end

      cacheline_rd_resp: begin  // Others?
        // Indicate that there is a request, and add metadata
        ofc_o_b = {1'b1, trans, 27'b0};
      end

      default: begin
        $error("unrecognized transaction for off-chip response");
        $fatal;
      end
    endcase

    // wait for the off-chip to be selected
    @(posedge clk iff (dut_bridge.bus_select[0] && dut_bridge.fsm == poll));

    @(posedge clk);

    if (dut_bridge.fsm != passenger_addr0) begin
      $display("fsm mismatch, not passaddr");
      $fatal;
    end

    if (trans inside {cacheline_rd_resp}) begin
      forever begin
        ofc_o_b = gen_rand_bus_word();

        @(posedge clk);
        if (dut_bridge.valid_incoming_req != 1'b1) begin
          $display("[fatal] Did not register incoming resp from off-chip");
          $fatal;
        end
        if (dut_bridge.transaction_fin) begin
          $display("Finished transaction for off chip response!");
          // Lower request
          ofc_o_b = 32'h0;
          return;
        end
      end
    end
  endtask


  // If csr write, csrdata is written
  // else csrdata is ignored
  task automatic initiate_off_chip_request(input dbus_meta_t trans, input logic [31:0] addr,
                                           input logic [31:0] csrdata);
    case (trans)
      SPMLEN_spm_write, csr_write, csr_rd_req: begin
        ofc_o_b = {1'b1, trans, 27'h0};
      end

      default: begin
        $error("unrecognized transaction for off-chip initiated message");
        $fatal;
      end
    endcase

    // wait for the off-chip to be selected
    @(posedge clk iff (dut_bridge.bus_select[0] && dut_bridge.fsm == poll));

    @(posedge clk);

    if (trans == SPMLEN_spm_write) begin
      if (dut_bridge.fsm != passenger_addr0) begin
        $display("fsm mismatch, not passsaddr for SPM");
        $fatal;
      end
    end else begin
      if (dut_bridge.fsm != passenger_addr0) begin
        $display("fsm mismatch, not passaddr");
        $fatal;
      end
    end

    if (trans inside {SPMLEN_spm_write, csr_write, csr_rd_req}) begin
      forever begin
        // Apply some data at the off-chip input point
        if (trans == SPMLEN_spm_write) begin
          ofc_o_b = gen_rand_bus_word();
        end else if (trans inside {csr_write, csr_rd_req}) begin
          ofc_o_b = addr;  // 10th bit zero, write to rfile
        end

        @(posedge clk);

        // If we actually need to send something on the "last data cycle"
        if (trans == csr_write) begin
          ofc_o_b = trans == csr_write ? csrdata : gen_rand_bus_word();
          @(posedge clk);
          $display("Finished csr_write");
          ofc_o_b = '0;
          return;
        end

        if (dut_bridge.fsm == poll_wait_bus_clr) begin
          $display("Finished transaction for off chip SEND!");
          // Lower request
          ofc_o_b[31:0] = 32'h0000_0000;
          return;
        end
      end
    end
  endtask


  initial begin
    $fsdbDumpfile("dump.fsdb");
    $fsdbDumpvars(0, "+all");
    rst = '1;
    ofc_o_b <= '0;
    repeat (2) @(posedge clk);
    rst <= '0;

    $display("[mmmu] exiting rst, starting simulation!");

    spm_bus.req_out <= 1'b0;
    rvtu_bus.dfp_read <= 1'b0;
    rvtu_bus.dfp_write <= 1'b0;
    @(posedge clk);

    fork
      begin
        initiate_on_chip_request(cacheline_wb);
        initiate_on_chip_request(cacheline_wb);
        initiate_on_chip_request(cacheline_rd_req);
        initiate_on_chip_request(cacheline_wb);
        #10ns;
        // Initiate SPM writeback, which should be 4 data cycles (see below)
        initiate_on_chip_request(SPMLEN_spm_wb);
      end

      begin
        $display("Setting spm.ILEN to 8, and spm.OLEN to 4");
        initiate_off_chip_request(csr_write, 32'h0000_01f0, {6'h0, 9'd3, 9'd7, 8'h0});

        $display("Initiating SPM write");
        initiate_off_chip_request(SPMLEN_spm_write, 32'h0000_01f0, 32'hx);

        $display("Done with SPM write transaction");

        $display("Sending read response");

        #40ns;
        initiate_off_chip_resp(cacheline_rd_resp);
      end
    join

    // Add some extra delay for sim scrolling
    #100ns;
    $finish;
  end

endmodule
