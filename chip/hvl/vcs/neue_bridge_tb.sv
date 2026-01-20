module neue_bridge_tb;
  import glbl_pkg::*;
  import mmmu_types::*;

  logic clk, rst;
  initial clk = '0;
  always #2ns clk = ~clk;

  tri [31:0] dbus;

  dbus_pkt_cyc0_t dbus_i;
  logic [1:0]  tb_dbus_t;

  logic [31:0] dbus_o;
  logic [1:0]  dbus_t_compact;


  logic        arb_vld_i;
  logic [31:0] arb_pkt_i;
  logic        arb_ack;

  logic        arb_fin;

  // Arb response I/O
  logic        arb_vld_o;
  logic [31:0] arb_pkt_o;
  dbus_meta_t  arb_type_o;

  // pipe dbus back
  logic [31:0] dbus_loop;

  io_tri dbus_io_tri_connector[31:0] (
      .chipout(dbus),
      .i(dbus_loop),  // value read from the dbus
      .o(dbus_o),  // value to drive to dbus, maybe?
      .t({{16{dbus_t_compact[1]}}, {16{dbus_t_compact[0]}}})
  );

  io_tri dbus_io_tri_tb[31:0] (
      .chipout(dbus),
      .i(),  // value read from the dbus
      .o(dbus_i),  // value to drive to dbus, maybe?
      .t({{16{tb_dbus_t[1]}}, {16{tb_dbus_t[0]}}})
  );

  mmmu_bridge #() u_mmmu_bridge (
      .clk(clk),
      .rst(rst),

      .dbus              (dbus_loop),
      .dbus_wdata        (dbus_o),
      .dbus_tri_en       (dbus_t_compact),

      .arb_vld_i         (arb_vld_i),
      .arb_pkt_i         (arb_pkt_i),
      .arb_ack           (arb_ack),

      .arb_fin           (arb_fin),

      .arb_vld_o         (arb_vld_o),
      .arb_pkt_o         (arb_pkt_o),
      .arb_type_o        (arb_type_o),

      .rfile_rdata       (),
      .wfile_wdata       ('{default: 'hECEBCAFE}),

      .test_mmmu_state   ()
  );

  initial begin
    $fsdbDumpfile("dump.fsdb");
    $fsdbDumpvars(0, "+all");

    rst <= '1;

    arb_vld_i <= '0;
    arb_pkt_i <= '0;

    dbus_i[31:16] <= '0;
    tb_dbus_t <= 'b01;

    repeat (3) @(negedge clk);

    rst <= '0;

    repeat (3) @(negedge clk);

    dbus_i.off_chip_req <= '1;
    dbus_i.off_chip_meta <= csr_rd_req;

    @(negedge clk);
    // it's relaxing its bus
    @(negedge clk);
    // we take bus!
    tb_dbus_t <= '0;
    dbus_i <= 'd3;

    @(negedge clk);
    tb_dbus_t <= 'b01;
    dbus_i <= 'x;

    @(negedge clk);
    dbus_i <= 'x;
    dbus_i.off_chip_req <= '0;

    @(negedge clk);
    // it broadcasts its request
    tb_dbus_t <= '1;

    @(negedge clk);

    @(negedge clk);
    // addr
    @(negedge clk);
    // data
    @(negedge clk);
    // it releases
    @(negedge clk);
    tb_dbus_t <= 'b01;
    dbus_i <= 'x;
    dbus_i.off_chip_req <= '0;

    repeat (3) @(negedge clk);

    $finish();
  end

  dbus_pkt_cyc0_t dbus_cast;
  assign dbus_cast = dbus;
endmodule
