module spm_top #(
    parameter int NUM_INGRESS_PE = 2,
    parameter int NUM_EGRESS_PE = 2,
    parameter int FIFO_WIDTH = 36,
    parameter int FIFO_DEPTH = 2,
    parameter int DBUS_WIDTH = 32,
    parameter int NUM_BANKS = 2,
    parameter int BANK_SIZE = 512,  // 2kB bank
    parameter int SRAM_WORD_SIZE = 32,
    parameter int CSR_REG_WIDTH = 32,
    parameter int NUM_CSRS = 32
) (
    input logic clk,
    input logic rst,

    // HERE U GO :) -ingi
    scratchpad_controller_if.spm arb_bus,

    // Fall-back mechanism
    input logic fb_en,
    input logic fb_d_in_vld,
    input logic fb_d_in,
    output logic fb_d_clsc,
    output logic fb_d_out,
    output logic fb_d_out_vld,


    input logic [31:0] csrfile_in,

    // Output CSRs,
    output logic [31:0] csrfile_out,

    // Signals to Mesh
    // SPM to Mesh Ingress (virtual) FIFO intf
    input logic ingress_fifo_dequeue[NUM_INGRESS_PE],
    output logic [FIFO_WIDTH-1:0] ingress_fifo_rdata[NUM_INGRESS_PE],
    output logic ingress_fifo_empty[NUM_INGRESS_PE],

    // Mesh to SPM Egress FIFOs
    output logic egress_fifo_dequeue[NUM_EGRESS_PE],
    input logic [FIFO_WIDTH-1:0] egress_fifo_rdata[NUM_EGRESS_PE],
    input logic egress_fifo_empty[NUM_EGRESS_PE]
);

  // Bit sliced input CSRs;
  logic ingress_fifo_sel;
  logic egress_fifo_sel;
  logic enable_wb;
  logic pid_sel;
  logic [3:0] pkt_id;
  logic [$clog2(BANK_SIZE)-1:0] num_words_in;
  logic [$clog2(BANK_SIZE)-1:0] num_words_out;

  // Bit sliced output CSRs
  logic pkt_ingress_fin;
  logic kernel_fin;


  // Do the funny bitslicing
  assign ingress_fifo_sel = csrfile_in[0];
  assign egress_fifo_sel = csrfile_in[1];
  assign enable_wb = csrfile_in[2];
  assign pid_sel= csrfile_in[3];
  assign pkt_id = csrfile_in[7:4];
  assign num_words_in = csrfile_in[8+$clog2(BANK_SIZE)-1:8];
  assign num_words_out = csrfile_in[(8+2*$clog2(BANK_SIZE))-1:8+$clog2(BANK_SIZE)];
  assign csrfile_out = {30'b0,pkt_ingress_fin, kernel_fin};

  logic ctrl_spm_mesh_full, ctrl_spm_mesh_enqueue;
  logic [SRAM_WORD_SIZE-1:0] ctrl_spm_mesh_wdata;

  logic ctrl_mesh_spm_empty, ctrl_mesh_spm_dequeue;
  logic [FIFO_WIDTH-1:0] ctrl_mesh_spm_rdata;

  spm_write_ctrl write_ctrl (
      .clk(clk),
      .rst(rst),
      .req_in(arb_bus.req_in),
      .dbus_in(arb_bus.dbus_in),
      .num_words(num_words_in),

      .fifo_wdata(ctrl_spm_mesh_wdata),
      .enqueue(ctrl_spm_mesh_enqueue),
      .fifo_full(ctrl_spm_mesh_full),
      .pkt_ingress_fin(pkt_ingress_fin)
  );

  spm_read_ctrl read_ctrl (
      .clk(clk),
      .rst(rst),
      .ack(arb_bus.bus_own_ack),
      .dbus_out(arb_bus.dbus_out),
      .dbus_valid(arb_bus.req_out),

      .num_words(num_words_out),
      .wb_enable(enable_wb),
      .kernel_fin(kernel_fin),

      .dequeue(ctrl_mesh_spm_dequeue),
      .fifo_empty(ctrl_mesh_spm_empty),
      .fifo_rdata(ctrl_mesh_spm_rdata)
  );


  // Fallback controller logic here
  /*
  * If fall back enable is High. Kill the controllers access into the FIFO and
  * hook up the fallback controllers
  */
  logic fb_spm_mesh_full, fb_spm_mesh_enqueue;
  logic [SRAM_WORD_SIZE-1:0] fb_spm_mesh_wdata;
  logic fb_mesh_spm_empty, fb_mesh_spm_dequeue;
  logic [FIFO_WIDTH-1:0] fb_mesh_spm_rdata;

  logic spm_mesh_full, spm_mesh_enqueue;
  logic [SRAM_WORD_SIZE-1:0] spm_mesh_wdata;

  logic mesh_spm_empty, mesh_spm_dequeue;
  logic [FIFO_WIDTH-1:0] mesh_spm_rdata;

  fallback fb (
    .clk(clk),
    .rst(rst),
    .fb_en(fb_en),
    .fb_d_in_vld(fb_d_in_vld),
    .fb_d_in(fb_d_in),
    .fb_d_clsc(fb_d_clsc),
    .fb_d_out(fb_d_out),
    .fb_d_out_vld(fb_d_out_vld),
    .fb_spm_mesh_full(fb_spm_mesh_full),
    .fb_spm_mesh_enqueue(fb_spm_mesh_enqueue),
    .fb_spm_mesh_wdata(fb_spm_mesh_wdata),
    .fb_mesh_spm_empty(fb_mesh_spm_empty),
    .fb_mesh_spm_dequeue(fb_mesh_spm_dequeue),
    .fb_mesh_spm_rdata(fb_mesh_spm_rdata)
  );


  assign fb_spm_mesh_full = spm_mesh_full;
  assign ctrl_spm_mesh_full = spm_mesh_full;

  assign spm_mesh_enqueue = (fb_en) ? fb_spm_mesh_enqueue : ctrl_spm_mesh_enqueue;
  assign spm_mesh_wdata = (fb_en) ? fb_spm_mesh_wdata : ctrl_spm_mesh_wdata;


  assign fb_mesh_spm_empty = mesh_spm_empty;
  assign ctrl_mesh_spm_empty = mesh_spm_empty;
  assign fb_mesh_spm_rdata = mesh_spm_rdata;
  assign ctrl_mesh_spm_rdata = mesh_spm_rdata;

  assign mesh_spm_dequeue = (fb_en) ? fb_mesh_spm_dequeue : ctrl_mesh_spm_dequeue;

  spm_to_mesh_ctrl spm_to_mesh (
      .clk(clk),
      .rst(rst),
      .fifo_sel(ingress_fifo_sel),
      .pkt_id(pkt_id),
      .pid_sel(pid_sel),
      // Facing write controller
      .enqueue(spm_mesh_enqueue),
      .full(spm_mesh_full),
      .wdata(spm_mesh_wdata),
      // Facing Mesh
      .ingress_dequeue(ingress_fifo_dequeue),
      .ingress_fifo_rdata(ingress_fifo_rdata),
      .ingress_fifo_empty(ingress_fifo_empty)
  );

  mesh_to_spm_ctrl mesh_to_spm (
      .fifo_sel(egress_fifo_sel),
      // Facing Read Controller
      .empty(mesh_spm_empty),
      .rdata(mesh_spm_rdata),
      .dequeue(mesh_spm_dequeue),
      // Facing Mesh
      .egress_empty(egress_fifo_empty),
      .egress_rdata(egress_fifo_rdata),
      .egress_dequeue(egress_fifo_dequeue)
  );

endmodule
