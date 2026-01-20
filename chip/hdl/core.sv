module top
  import pe_types::*;
  import mmmu_types::*;
  import glbl_pkg::*;
(
    input bit clk,
    input bit rst,

    // For MMMU
    inout tri [31:0] dbus,

    input logic rvtu_rst_a,
    input logic rvtu_rst_b,

    input logic fb_en,
    input logic fb_d_in_vld,
    input logic fb_d_in,

    // Chip outputs
    output logic fb_d_clsc,
    output logic fb_d_out,
    output logic fb_d_out_vld,
    output logic led,

    // DBUS State
    output logic [2:0] test_mmmu_state
);

  // Set powered led
  io_out led_i (
      .chipout(led),
      .chipin (1'b1)
  );

  logic              mesh_in_deq                                         [8];
  logic              mesh_in_empty                                       [8];
  packet_t           mesh_in_rdata                                       [8];

  logic              mesh_out_deq                                        [8];
  logic              mesh_out_empty                                      [8];
  packet_t           mesh_out_rdata                                      [8];

  logic              smem_in_deq                                         [4];
  logic              smem_in_empty                                       [4];
  packet_t           smem_in_rdata                                       [4];

  logic              smem_out_deq                                        [4];
  logic              smem_out_empty                                      [4];
  packet_t           smem_out_rdata                                      [4];


  logic              arb_vld;
  logic       [31:0] arb_pkt;
  logic              bridge_valid_incoming_req;
  logic       [31:0] bridge_incoming_req;
  logic              bridge_ack_arb;
  logic              bridge_transaction_fin;
  dbus_meta_t        bridge_transaction_type;


  logic       [31:0] dbus_i;  // Input
  logic       [31:0] dbus_o;  // Output
  logic       [1:0]  dbus_t_compact;
  logic       [31:0] dbus_t;  // Tristate enable. t=0 means drive chipout

  assign dbus_t = {{16{dbus_t_compact[1]}}, {16{dbus_t_compact[0]}}};

  io_tri dbus_io_tri_connector[31:0] (
      .chipout(dbus),
      .i(dbus_i),  // value read from the dbus
      .o(dbus_o),  // value to drive to dbus, maybe?
      .t(dbus_t)  // 1=don't drive the o value to dbus
  );


  logic [31:0] rfile_rdata[NUM_RFILE];
  logic [31:0] wfile_wdata[NUM_WFILE];

  // Buffer for top-level MMMU state debugging output
  logic [2:0] test_mmmu_state__buf_in;

  io_out test_mmmu_state_i[2:0] (
    .chipout(test_mmmu_state),
    .chipin(test_mmmu_state__buf_in)
  );

  mmmu_bridge #() u_mmmu_bridge (
      .clk(clk),
      .rst(rst),

      .dbus              (dbus_i),
      .dbus_wdata        (dbus_o),
      .dbus_tri_en       (dbus_t_compact),

      .arb_vld_i         (arb_vld),
      .arb_pkt_i         (arb_pkt),
      .arb_ack           (bridge_ack_arb),

      .arb_fin           (bridge_transaction_fin),

      .arb_vld_o         (bridge_valid_incoming_req),
      .arb_pkt_o         (bridge_incoming_req),
      .arb_type_o        (bridge_transaction_type),

      .rfile_rdata       (rfile_rdata),
      .wfile_wdata       (wfile_wdata),

      .test_mmmu_state   (test_mmmu_state__buf_in)
  );

  // SPM ARB bus
  scratchpad_controller_if spm_arb_bus ();

  // RVTU PAIR and ARB bus
  rvtu_pair_arb_if rvtu_arb_bus ();

  mmmu_arb #(
      .NUM_RVTUS(2)
  ) mmmu_arb_ (
      .clk          (clk),
      .rst          (rst),
      .spm          (spm_arb_bus.mmmu_arb),
      .rvtu         (rvtu_arb_bus.mmmu_arb),      // connection to RVTU pair
      .recv_data    (bridge_incoming_req),
      .recv_data_vld(bridge_valid_incoming_req),
      .bridge_ack   (bridge_ack_arb),
      .bridge_fin   (bridge_transaction_fin),
      .bridge_type  (bridge_transaction_type),

      .arb_vld      (arb_vld),
      .arb_pkt      (arb_pkt)
  );

  logic mesh_out_to_spm_deq[1:0];
  assign smem_out_deq[2] = mesh_out_to_spm_deq[0];
  assign smem_out_deq[3] = mesh_out_to_spm_deq[1];

  logic mesh_out_to_spm_empty[1:0];
  assign mesh_out_to_spm_empty[0] = smem_out_empty[2];
  assign mesh_out_to_spm_empty[1] = smem_out_empty[3];

  packet_t mesh_out_to_spm_rdata[1:0];
  assign mesh_out_to_spm_rdata[0] = smem_out_rdata[2];
  assign mesh_out_to_spm_rdata[1] = smem_out_rdata[3];

  packet_t spm_to_mesh_rdata[1:0];
  assign smem_in_rdata[0] = spm_to_mesh_rdata[0];
  assign smem_in_rdata[1] = spm_to_mesh_rdata[1];

  logic spm_to_mesh_empty[1:0];
  assign smem_in_empty[0] = spm_to_mesh_empty[0];
  assign smem_in_empty[1] = spm_to_mesh_empty[1];

  logic spm_to_mesh_dequeue[1:0];
  assign spm_to_mesh_dequeue[0] = smem_in_deq[0];
  assign spm_to_mesh_dequeue[1] = smem_in_deq[1];

  logic fb_d_clsc__buf_in;
  logic fb_d_out__buf_in;
  logic fb_d_out_vld__buf_in;
  io_out fb_d_clsc_i (
      .chipout(fb_d_clsc),
      .chipin (fb_d_clsc__buf_in)
  );
  io_out fb_d_out_i (
      .chipout(fb_d_out),
      .chipin (fb_d_out__buf_in)
  );
  io_out fb_d_out_vld_i (
      .chipout(fb_d_out_vld),
      .chipin (fb_d_out_vld__buf_in)
  );

  spm_top #(
      .NUM_INGRESS_PE(2),
      .NUM_EGRESS_PE (2),
      .FIFO_WIDTH    (36),
      .FIFO_DEPTH    (2),
      .DBUS_WIDTH    (16),
      .NUM_BANKS     (2),
      .BANK_SIZE     (512),
      // 2kB bank
      .SRAM_WORD_SIZE(32),
      .CSR_REG_WIDTH (32),
      .NUM_CSRS      (32)
  ) u_spm_top (
      .clk(clk),
      .rst(rst),

      // This handles all needed wires between MMMU_ARBITER and SPM
      .arb_bus(spm_arb_bus.spm),

      .csrfile_in (rfile_rdata[0]),
      .csrfile_out(wfile_wdata[0]),

      // Fallback mechanism
      .fb_en(fb_en),
      .fb_d_in_vld(fb_d_in_vld),
      .fb_d_in(fb_d_in),
      .fb_d_clsc(fb_d_clsc__buf_in),
      .fb_d_out(fb_d_out__buf_in),
      .fb_d_out_vld(fb_d_out_vld__buf_in),

      // Signals to Mesh
      // SPM to Mesh Ingress (virtual) FIFO intf
      .ingress_fifo_dequeue(spm_to_mesh_dequeue),
      .ingress_fifo_rdata  (spm_to_mesh_rdata),
      .ingress_fifo_empty  (spm_to_mesh_empty),
      // Mesh to SPM Egress FIFOs
      .egress_fifo_dequeue (mesh_out_to_spm_deq),
      .egress_fifo_rdata   (mesh_out_to_spm_rdata),
      .egress_fifo_empty   (mesh_out_to_spm_empty)
  );

  // Map (2, 0) <-> (0, 1)
  logic rvtu_to_mesh_empty[2];
  assign mesh_in_empty[2] = rvtu_to_mesh_empty[0];
  assign mesh_in_empty[0] = rvtu_to_mesh_empty[1];

  logic [35:0] rvtu_to_mesh_rdata[2];
  assign mesh_in_rdata[2] = rvtu_to_mesh_rdata[0];
  assign mesh_in_rdata[0] = rvtu_to_mesh_rdata[1];

  logic rvtu_to_mesh_deq[2];
  assign rvtu_to_mesh_deq[0] = mesh_in_deq[2];
  assign rvtu_to_mesh_deq[1] = mesh_in_deq[0];

  logic mesh_to_rvtu_deq[2];
  assign mesh_out_deq[2] = mesh_to_rvtu_deq[0];
  assign mesh_out_deq[0] = mesh_to_rvtu_deq[1];

  logic mesh_to_rvtu_empty[2];
  assign mesh_to_rvtu_empty[0] = mesh_out_empty[2];
  assign mesh_to_rvtu_empty[1] = mesh_out_empty[0];

  logic [35:0] mesh_to_rvtu_rdata[2];
  assign mesh_to_rvtu_rdata[0] = mesh_out_rdata[2];
  assign mesh_to_rvtu_rdata[1] = mesh_out_rdata[0];

  logic halt[2];
  assign wfile_wdata[1] = 32'(halt[0]);
  assign wfile_wdata[2] = 32'(halt[1]);

  rvtu_pair #(
      .pcs('{32'h40000000, 32'h80000000})
  ) rvtu_pair_ (
      .clk(clk),
      .rst(rst),

      .rvtu_rst_a(rvtu_rst_a),
      .rvtu_rst_b(rvtu_rst_b),

      // Mesh Side Signals
      .mul_eg_empty(rvtu_to_mesh_empty),
      .mul_eg_rdata(rvtu_to_mesh_rdata),
      .mul_eg_deq  (rvtu_to_mesh_deq),

      .mul_ig_empty(mesh_to_rvtu_empty),
      .mul_ig_rdata(mesh_to_rvtu_rdata),
      .mul_ig_deq  (mesh_to_rvtu_deq),

      // MMMU Arb Side Signals
      .arb_bus(rvtu_arb_bus.rvtu_pair),

      .halt(halt)
  );

  // Assign unused scratchpad memory empty signals
  assign smem_in_empty[2] = 1'b1;
  assign smem_in_rdata[2] = 'x;
  assign smem_in_empty[3] = 1'b1;
  assign smem_in_rdata[3] = 'x;

  assign smem_out_deq[0]  = 1'b0;
  assign smem_out_deq[1]  = 1'b0;

  // assign unused mesh signals
  assign mesh_in_empty[1] = 1'b1;
  assign mesh_in_rdata[1] = 'x;

  assign mesh_in_empty[3] = 1'b1;
  assign mesh_in_rdata[3] = 'x;

  assign mesh_in_empty[4] = 1'b1;
  assign mesh_in_rdata[4] = 'x;

  assign mesh_in_empty[5] = 1'b1;
  assign mesh_in_rdata[5] = 'x;

  assign mesh_in_empty[6] = 1'b1;
  assign mesh_in_rdata[6] = 'x;

  assign mesh_in_empty[7] = 1'b1;
  assign mesh_in_rdata[7] = 'x;

  assign mesh_out_deq[1]  = 1'b0;
  assign mesh_out_deq[3]  = 1'b0;
  assign mesh_out_deq[4]  = 1'b0;
  assign mesh_out_deq[5]  = 1'b0;
  assign mesh_out_deq[6]  = 1'b0;
  assign mesh_out_deq[7]  = 1'b0;

  pe_mesh u_pe_mesh (
      .clk(clk),
      .rst(rst),

      .mesh_in_deq  (mesh_in_deq),
      .mesh_in_empty(mesh_in_empty),
      .mesh_in_rdata(mesh_in_rdata),

      .mesh_out_deq  (mesh_out_deq),
      .mesh_out_empty(mesh_out_empty),
      .mesh_out_rdata(mesh_out_rdata),

      .smem_in_deq  (smem_in_deq),
      .smem_in_empty(smem_in_empty),
      .smem_in_rdata(smem_in_rdata),

      .smem_out_deq  (smem_out_deq),
      .smem_out_empty(smem_out_empty),
      .smem_out_rdata(smem_out_rdata)
  );

endmodule
