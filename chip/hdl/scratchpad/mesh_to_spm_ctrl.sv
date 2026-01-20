module mesh_to_spm_ctrl #(
    parameter int FIFO_WIDTH = 36,
    parameter int FIFO_DEPTH = 2,
    parameter int NUM_EGRESS_PE = 2
) (
    input logic fifo_sel,

    // SPM Facing Ports
    output logic empty,
    output logic [FIFO_WIDTH-1:0] rdata,
    input logic dequeue,

    // Mesh Facing ports
    input logic egress_empty[NUM_EGRESS_PE],
    input logic [FIFO_WIDTH-1:0] egress_rdata[NUM_EGRESS_PE],
    output logic egress_dequeue[NUM_EGRESS_PE]
);

  assign egress_dequeue[0] = (fifo_sel) ? dequeue : '0;
  assign egress_dequeue[1] = (!fifo_sel) ? dequeue : '0;

  assign rdata = (fifo_sel) ? egress_rdata[0] : egress_rdata[1];
  assign empty = (fifo_sel) ? egress_empty[0] : egress_empty[1];

endmodule
