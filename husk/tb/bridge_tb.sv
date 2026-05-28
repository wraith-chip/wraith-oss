//  SPDX-License-Identifier: MIT
//  bridge_tb.sv — Husk Main Bridge Testbench
//  Copyright (c) 2026 Pradyun Narkadamilli

import bridge_types::*;

module bridge_tb;
  // 500 MHz <-> 2ns
  // hence 1 clock period <-> #20
  // 333 MHz <-> 3ns
  // hence 1 clock period <-> #30
  timeunit 100ps;
  timeprecision 1ps;

  logic fabric_clk, fabric_rst;

  // signals
  logic wraith_rst;
  logic rvtu_0_rst;
  logic rvtu_1_rst;

  // SPM BRAM connections
  logic [8:0]  bridge_spm_addr;
  logic [31:0] bridge_spm_rdata, bridge_spm_wdata;
  logic        bridge_spm_en;
  logic        bridge_spm_we;

  wire [31:0] dbus;
  logic [31:0]  dbus_dir;
  logic [31:0] dbus_i, dbus_o;

  logic [5:0]  axi_addr;
  logic        axi_rd;
  logic        axi_wr;
  logic [3:0]  axi_wmask;
  logic [31:0] axi_wdata;

  logic        axi_resp;
  logic [31:0] axi_rdata;
  logic axi_clk, axi_rst_n;

  // dummy dbus signals
  dbus_handshake_t tb_dbus_o, tb_dbus_i;

  initial fabric_clk = 0;
  initial axi_clk = 0;

  always #15 axi_clk = ~axi_clk;
  always #10 fabric_clk = ~fabric_clk;

  initial begin
    fabric_rst <= '1;
    repeat(2) @(posedge fabric_clk);
    fabric_rst <= '0;
  end


  // DBUS monitor & driver
  assign tb_dbus_i = dbus;

  initial begin
    @(posedge fabric_clk iff ~fabric_rst);
    tb_dbus_o.wraith_req <= '0;

    forever begin
      @(posedge fabric_clk);

      // ignore everything if wraith is supposed to be disabled...
      if (husk_bridge.wraith_rst) continue;

      if (dbus_dir != {6'b0, {26{1'b1}}}) begin
        $error("DBUS dir is wrong!!! Incorrect config for POLL");
        $finish();
      end

      if (tb_dbus_i.husk_req &
          tb_dbus_i.husk_meta == csr_write) begin
        @(posedge fabric_clk iff dbus_dir[0] == '1); // wait for MCLR
        @(posedge fabric_clk iff dbus_dir[0] == '1); // wait for FCLR
      end

      if (tb_dbus_i.husk_req &
          tb_dbus_i.husk_meta == csr_rd_req) begin
        @(posedge fabric_clk iff dbus_dir[0] == '1); // wait for MCLR
        @(posedge fabric_clk iff dbus_dir[0] == '1); // wait for FCLR

        // transaction for CSR rd resp!
        // TODO: snoop husk state
        repeat (8) @(posedge fabric_clk);

        tb_dbus_o.wraith_req <= '1;
        tb_dbus_o.wraith_meta <= csr_rd_resp;
        @(posedge fabric_clk);

        // our crap is on the bridge now, we win bc vibes
        @(posedge fabric_clk);

        // WE are in MCLR -- drive some bullshit for addr
        if (dbus_dir[0] != '1) begin
          $error("DBUS dir is wrong!!! We should be in MCLR??");
          $finish();
        end

        tb_dbus_o <= 32'hECEBCAFE;
        @(posedge fabric_clk);

        // ok now we drive bullshit data. MADDR on bus
        if (dbus_dir != '1) begin
          $error("DBUS dir is wrong!!! Should be MADDR!!!");
          $finish();
        end

        tb_dbus_o <= 32'hFAAAAAAA;
        @(posedge fabric_clk);

        // MDATA on bus
        if (dbus_dir != '1) begin
          $error("DBUS dir is wrong!!! Should be MDATA!!!");
          $finish();
        end
        @(posedge fabric_clk);

        // FCLR. clear req pins
        if (dbus_dir[25:0] != '1) begin
          $error("DBUS dir is wrong!!! Should be FCLR!!!");
          $finish();
        end
        tb_dbus_o.wraith_req <= '0;
        @(posedge fabric_clk);
      end

      if (tb_dbus_i.husk_req &
          tb_dbus_i.husk_meta == SPMLEN_spm_write) begin
        @(posedge fabric_clk iff dbus_dir[0] == '1); // wait for MCLR
        @(posedge fabric_clk iff dbus_dir[0] == '1); // wait for FCLR
      end

      // TODO: snoop husk's bridge signals to see if we should wb
      if (husk_bridge.dbus_state == POLL & husk_bridge.axireq_vld &
          husk_bridge.axireq.spm & husk_bridge.axireq.rd) begin
        tb_dbus_o.wraith_req <= '1;
        tb_dbus_o.wraith_meta <= SPMLEN_spm_wb;

        @(posedge fabric_clk iff dbus_dir[31] == '1);
        $display("made it INTO the whole");

        // husk going to be in SADDR
        tb_dbus_o <= '0;
        @(posedge fabric_clk);

        // husk going into SDATA for the first time
        tb_dbus_o <= 32'h100;

        forever begin
          @(posedge fabric_clk);
          if (husk_bridge.dbus_state == FCLR) break;
          else tb_dbus_o <= tb_dbus_o + 32'd1;
        end

        $display("made it outta the hole");
        tb_dbus_o.wraith_req <= '0;

        @(posedge fabric_clk);
      end
    end
  end

  // Axi requests
  initial begin
    axi_rst_n <= '0;

    axi_addr <= 'x;
    axi_rd <= '0;
    axi_wr <= '0;
    axi_wmask <= '0;
    axi_wdata <= '0;

    repeat(10) @(posedge axi_clk);
    axi_rst_n <= '1;

    // Enable bridge: Write 32'd1 to metacsr
    @(posedge axi_clk);
    // addr = 4'd10 << 2
    axi_addr <= 6'd40;
    axi_wr <= '1;
    axi_wdata <= 32'd1;
    @(posedge axi_clk iff axi_resp);
    axi_wr <= '0;

    // Do dummy CSR write through AXI
    @(posedge axi_clk);
    axi_addr <= 6'b001100;
    axi_wr <= '1;
    axi_wdata <= 32'hfaaa;

    @(posedge axi_clk iff axi_resp);
    axi_wr <= '0;

    // Read request 1
    @(posedge axi_clk);
    axi_addr <= 6'b001100;
    axi_rd <= '1;

    @(posedge axi_clk iff axi_resp);
    axi_rd <= '0;

    $display("done w 1");

    // Read request 2
    @(posedge axi_clk);
    axi_addr <= 6'b001100;
    axi_rd <= '1;

    @(posedge axi_clk iff axi_resp);
    axi_rd <= '0;

    $display("done w 2");

    // configure SPM len
    @(posedge axi_clk);
    axi_addr <= 6'd0;
    axi_wr <= '1;
    axi_wdata <= (32'd64 << 17) | (32'd32 << 8);

    @(posedge axi_clk iff axi_resp);
    axi_wr <= '0;

    $display("done w w");

    repeat(8) @(posedge axi_clk);

    // SPM read req
    @(posedge axi_clk);
    axi_addr <= 6'd28;
    axi_rd <= '1;

    @(posedge axi_clk iff axi_resp);
    axi_rd <= '0;

    $display("done w spmr");

    repeat(10) @(posedge axi_clk);

    // SPM write req
    @(posedge axi_clk);
    axi_addr <= 6'd28;
    axi_wr <= '1;

    @(posedge axi_clk iff axi_resp);
    axi_wr <= '0;

    $display("done w spmw");

    repeat(150) @(posedge axi_clk);
    $finish();
  end

  // instantiations
  IOBUF IOBUF_inst[31:0] (
    .O(dbus_i),
    .IO(dbus),
    .I(dbus_o),
    .T(dbus_dir)
  );

  IOBUF IOBUF_inst_Bridge[31:0] (
    .O(),
    .IO(dbus),
    .I(tb_dbus_o),
    .T(~dbus_dir) // we assume that Husk has a functioning FSM
  );

  bridge husk_bridge(
    .fabric_clk  (fabric_clk),
    .fabric_rst  (fabric_rst),

    .dbus_i      (dbus_i),
    .dbus_o      (dbus_o),
    .dbus_dir    (dbus_dir),

    .wraith_rst  (wraith_rst),
    .rvtu_0_rst  (rvtu_0_rst),
    .rvtu_1_rst  (rvtu_1_rst),

    .spm_en      (bridge_spm_en),
    .spm_addr    (bridge_spm_addr),
    .spm_we      (bridge_spm_we),
    .spm_wdata   (bridge_spm_wdata),
    .spm_rdata   (bridge_spm_rdata),

    .uram0_en    (),
    .uram0_we    (),
    .uram0_addr  (), // 32-bit byte address
    .uram0_wdata (), // 128-bit
    .uram0_rdata ('0), // 128-bit

    .uram1_en    (),
    .uram1_we    (),
    .uram1_addr  (), // 32-bit byte address
    .uram1_wdata (), // 128-bit
    .uram1_rdata ('0), // 128-bit

    .axi_clk     (axi_clk),
    .axi_rst_n   (axi_rst_n),
    .axi_addr    (axi_addr),
    .axi_rd      (axi_rd),
    .axi_wr      (axi_wr),
    .axi_wmask   (axi_wmask),
    .axi_wdata   (axi_wdata),
    .axi_resp    (axi_resp),
    .axi_rdata   (axi_rdata)
  );

  soc_spm spm(
    .clka('0),
    .addra('0),
    .rsta('0),
    .ena('0),
    .wea('0),
    .dina('x),
    .douta(),

    .clkb  (fabric_clk),
    .addrb (bridge_spm_addr),
    .enb   (bridge_spm_en),
    .web   ({4{bridge_spm_we}}),
    .dinb  (bridge_spm_wdata),
    .doutb (bridge_spm_rdata),

    .rsta_busy(),
    .rstb_busy()
  );
endmodule
