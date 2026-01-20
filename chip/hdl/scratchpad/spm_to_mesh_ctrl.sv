module spm_to_mesh_ctrl #(
  parameter int SRAM_WRD_SIZE = 32,
  parameter int FIFO_WIDTH = 36,
  parameter int FIFO_DEPTH = 2, 
  parameter int NUM_INGRESS_PE = 2,
  parameter int PKT_ID_WIDTH = 4
  )(
    input logic clk,
    input logic rst,

    input logic fifo_sel,
    input logic pid_sel,
    input logic [PKT_ID_WIDTH-1:0] pkt_id,

    // spm facing ports
    input logic enqueue,
    output logic full,
    input logic [SRAM_WRD_SIZE-1:0] wdata,

    // Mesh facing ports
    input  logic ingress_dequeue [NUM_INGRESS_PE],
    output logic [FIFO_WIDTH-1:0] ingress_fifo_rdata [NUM_INGRESS_PE],
    output logic ingress_fifo_empty  [NUM_INGRESS_PE]
  );


  // Instantiate the SPM--> mesh fifo here
  logic phny_empty, phny_dequeue;
  logic [FIFO_WIDTH-1:0] phny_rdata;

  logic [FIFO_WIDTH-1:0] fifo_wdata;

  always_comb begin
    if (pid_sel) begin
      fifo_wdata = {wdata[31:28], {4{wdata[27]}}, wdata[27:0]};
    end else begin
      fifo_wdata = {pkt_id, wdata};
    end
  end

  fifo #(FIFO_DEPTH, FIFO_WIDTH) ingress_fifo  (
    .clk(clk),
    .rst(rst),
    .enqueue(enqueue),
    .wdata(fifo_wdata),
    .dequeue(phny_dequeue),
    .rdata(phny_rdata),
    .full(full),
    .empty(phny_empty)
    );

  // Mux which PE is the ingress point based on fifo_sel
  assign phny_dequeue = (fifo_sel)? ingress_dequeue[0]: ingress_dequeue[1];

  assign ingress_fifo_rdata[0] = (fifo_sel)? phny_rdata : '0;
  assign ingress_fifo_empty[0] = (fifo_sel)? phny_empty: '1;

  assign ingress_fifo_rdata[1] = (!fifo_sel)? phny_rdata : '0;
  assign ingress_fifo_empty[1] = (!fifo_sel)? phny_empty: '1;
endmodule
