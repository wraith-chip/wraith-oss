//  SPDX-License-Identifier: MIT
//  husk.sv — Top-Level for Husk (WRAITH Lab Harness)
//  Copyright (c) 2026 Pradyun Narkadamilli

module husk(
  input              clk_p,
  input              clk_n,

  input              rst,

  output             wraith_clk,
  output             wraith_rst,
  output             wraith_pwr,

  inout              dbus[31:0],

  output logic       rvtu_0_rst,
  output logic       rvtu_1_rst,

  // debug signals
  input              dbus_fsm[2:0],

  // fallbacks are named from chip perspective
  input              fb_d_out_vld,
  input              fb_d_out,
  input              fb_d_clsc,

  output logic       fb_en,
  output logic       fb_d_in_vld,
  output logic       fb_d_in,

  // debug LEDs
  output logic [7:0] led,

  // SOC pins
  output             ddr4_sdram_c1_062_act_n,
  output [16:0]      ddr4_sdram_c1_062_adr,
  output [1:0]       ddr4_sdram_c1_062_ba,
  output             ddr4_sdram_c1_062_bg,
  output             ddr4_sdram_c1_062_ck_c,
  output             ddr4_sdram_c1_062_ck_t,
  output             ddr4_sdram_c1_062_cke,
  output             ddr4_sdram_c1_062_cs_n,
  inout [7:0]        ddr4_sdram_c1_062_dm_n,
  inout [63:0]       ddr4_sdram_c1_062_dq,
  inout [7:0]        ddr4_sdram_c1_062_dqs_c,
  inout [7:0]        ddr4_sdram_c1_062_dqs_t,
  output             ddr4_sdram_c1_062_odt,
  output             ddr4_sdram_c1_062_reset_n,

  input              default_250mhz_clk1_clk_n,
  input              default_250mhz_clk1_clk_p,
  input              default_250mhz_clk2_clk_n,
  input              default_250mhz_clk2_clk_p,

  input              rs232_uart_0_rxd,
  output             rs232_uart_0_txd
);
  logic clk_500_skew;

  // use this as an addl reset condition
  logic locked;

  // SPM BRAM connections
  logic [11:0] soc_spm_addr;
  logic        soc_spm_clk;
  logic [31:0] soc_spm_din;
  logic [31:0] soc_spm_dout;
  logic        soc_spm_en;
  logic        soc_spm_rst;
  logic [3:0]  soc_spm_we;

  logic [31:0] uram0_addr, uram1_addr;
  logic [127:0] uram0_wdata, uram1_wdata;
  logic [127:0] uram0_rdata, uram1_rdata;
  logic         uram0_en, uram1_en;
  logic         uram0_we, uram1_we;

  logic [8:0]  bridge_spm_addr;
  logic [31:0] bridge_spm_rdata, bridge_spm_wdata;
  logic        bridge_spm_en;
  logic        bridge_spm_we;

  logic        axi_clk;
  logic        axi_resetn;

  logic [5:0]  axi_addr;
  logic        axi_rd;
  logic        axi_wr;
  logic [3:0]  axi_wmask;
  logic [31:0] axi_wdata;

  logic        axi_resp;
  logic [31:0] axi_rdata;

  (* max_fanout = 1 *) logic [31:0] dbus_dir;
  logic [31:0] dbus_i, dbus_o;

  // reset sequence/logic
  (* ASYNC_REG = "TRUE" *) logic rst_meta, rst_sync, rst_sync_q;
  logic [20:0] db_cnt;
  logic        rst_db, sat_db_cnt;

  always_ff @(posedge clk_500) begin
    rst_meta <= rst;
    rst_sync <= rst_meta; // sample into our clock domain
    rst_sync_q <= rst_sync; // track posedge

    if (~rst_sync)
      db_cnt <= '0;
    else if (rst_sync & ~rst_sync_q)
      db_cnt <= '0;
    else if (rst_sync & rst_sync_q & ~(&db_cnt))
      db_cnt <= db_cnt + 21'd1;
  end

  always_ff @(posedge clk_500)
    sat_db_cnt <= &db_cnt;

  assign rst_db = sat_db_cnt | ~locked;

  // for obvious reasons, don't do this fr -- add an ODDR?
  assign wraith_pwr = '1;

  // neuter debug hardware in full-speed harness
  assign fb_en       = '0;
  assign fb_d_in_vld = '0;
  assign fb_d_in     = '0;

  // tap some debug signals
  always_ff @(posedge clk_500) begin
    led[0] <= rst;    // rst button?
    led[1] <= rst_db; // is reset even getting asserted?
    led[2] <= locked; // is the MMCM working?
    led[3] <= '0;     // empty
    led[4] <= wraith_rst;
    led[5] <= rvtu_0_rst;
    led[6] <= rvtu_1_rst;
    led[7] <= '0;
  end

  clk_wiz_0 clkgen(
    .clk_in1_p(clk_p),
    .clk_in1_n(clk_n),

    .locked(locked),

    .clk_out1 (clk_500),
    .clk_out2 (clk_500_skew)
  );

  ODDR #(
    .DDR_CLK_EDGE("SAME_EDGE"),
    .INIT(1'b0),
    .SRTYPE("ASYNC")
  ) clk_out_oddr (
    .Q  (wraith_clk),   // to FMC+ pin
    .C  (clk_500_skew),    // from MMCM
    .CE (1'b1),
    .D1 (1'b1),
    .D2 (1'b0),
    .R  (~locked),
    .S  (1'b0)
  );

  soc_spm spm(
    .clka(soc_spm_clk),
    .addra(soc_spm_addr[10:2]),
    .rsta(soc_spm_rst),
    .ena(soc_spm_en),
    .wea(soc_spm_we),
    .dina(soc_spm_din),
    .douta(soc_spm_dout),

    .clkb  (clk_500),
    .addrb (bridge_spm_addr),
    .enb   (bridge_spm_en),
    .web   ({4{bridge_spm_we}}),
    .dinb  (bridge_spm_wdata),
    .doutb (bridge_spm_rdata),

    .rsta_busy(),
    .rstb_busy()
  );

  husk_bd husk_soc (
    .ddr4_sdram_c1_062_act_n,
    .ddr4_sdram_c1_062_adr,
    .ddr4_sdram_c1_062_ba,
    .ddr4_sdram_c1_062_bg,
    .ddr4_sdram_c1_062_ck_c,
    .ddr4_sdram_c1_062_ck_t,
    .ddr4_sdram_c1_062_cke,
    .ddr4_sdram_c1_062_cs_n,
    .ddr4_sdram_c1_062_dm_n,
    .ddr4_sdram_c1_062_dq,
    .ddr4_sdram_c1_062_dqs_c,
    .ddr4_sdram_c1_062_dqs_t,
    .ddr4_sdram_c1_062_odt,
    .ddr4_sdram_c1_062_reset_n,

    .default_250mhz_clk1_clk_n,
    .default_250mhz_clk1_clk_p,
    .default_250mhz_clk2_clk_n,
    .default_250mhz_clk2_clk_p,

    .BRAM_PORTA_0_addr (soc_spm_addr),
    .BRAM_PORTA_0_clk  (soc_spm_clk),
    .BRAM_PORTA_0_din  (soc_spm_din),
    .BRAM_PORTA_0_dout (soc_spm_dout),
    .BRAM_PORTA_0_en   (soc_spm_en),
    .BRAM_PORTA_0_rst  (soc_spm_rst),
    .BRAM_PORTA_0_we   (soc_spm_we),

    .RVTU0_URAM_clk  (clk_500),
    .RVTU0_URAM_rst  (rst_db),
    .RVTU0_URAM_en   (uram0_en),
    .RVTU0_URAM_addr (uram0_addr), // 32-bit byte address
    .RVTU0_URAM_din  (uram0_wdata), // 128-bit
    .RVTU0_URAM_dout (uram0_rdata), // 128-bit
    .RVTU0_URAM_we   ({16{uram0_we}}),

    .RVTU1_URAM_clk  (clk_500),
    .RVTU1_URAM_rst  (rst_db),
    .RVTU1_URAM_en   (uram1_en),
    .RVTU1_URAM_addr (uram1_addr), // 32-bit byte address
    .RVTU1_URAM_din  (uram1_wdata), // 128-bit
    .RVTU1_URAM_dout (uram1_rdata), // 128-bit
    .RVTU1_URAM_we   ({16{uram1_we}}),

    .port_clk_0        (axi_clk),
    .port_resetn_0     (axi_resetn),

    .port_addr_0       (axi_addr),
    .port_rd_0         (axi_rd),
    .port_wr_0         (axi_wr),
    .port_wstrb_0      (axi_wmask),
    .port_wdata_0      (axi_wdata),

    .port_resp_0       (axi_resp),
    .port_rdata_0      (axi_rdata),

    .rs232_uart_0_txd,
    .rs232_uart_0_rxd,

    .fabric_clk        (clk_500),
    .reset             (rst_db)
  );

  bridge husk_bridge(
    .fabric_clk  (clk_500),
    .fabric_rst  (rst_db),

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

    .uram0_en    (uram0_en),
    .uram0_we    (uram0_we),
    .uram0_addr  (uram0_addr), // 32-bit byte address
    .uram0_wdata (uram0_wdata), // 128-bit
    .uram0_rdata (uram0_rdata), // 128-bit

    .uram1_en    (uram1_en),
    .uram1_we    (uram1_we),
    .uram1_addr  (uram1_addr), // 32-bit byte address
    .uram1_wdata (uram1_wdata), // 128-bit
    .uram1_rdata (uram1_rdata), // 128-bit

    .axi_clk     (axi_clk),
    .axi_rst_n   (axi_resetn),
    .axi_addr    (axi_addr),
    .axi_rd      (axi_rd),
    .axi_wr      (axi_wr),
    .axi_wmask   (axi_wmask),
    .axi_wdata   (axi_wdata),
    .axi_resp    (axi_resp),
    .axi_rdata   (axi_rdata)
  );

  IOBUF #(
     .DRIVE(8), // TODO: confirm that these parameters are correct
     .IBUF_LOW_PWR("FALSE"),
     .IOSTANDARD("LVCMOS12"),
     .SLEW("FAST")
  ) IOBUF_inst[31:0] (
     .O(dbus_i),
     .IO(dbus),
     .I(dbus_o),
     .T(dbus_dir)
  );
endmodule
