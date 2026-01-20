/*
    This is the main 4x4 mesh made up of 4 2x2 clusters


                    MESH(WIMP) DIAGRAM          |                       CLUSTER DIAGRAM
                                                |
                                                |
                        MESH_IN/OUT             |
                       [3] [2] [1] [0]          |
                        |   |   |   |           |               NON-EDGE                    EDGE
                    +-----------------+         |       +-------------------+      +-------------------+
SMEM_IN/OUT [0]-----|                 |         |       |                   |      |                   |
                    |    A------B     |         |       |       2   3       |      |       2   3       |
SMEM_IN/OUT [1]-----|    |      |     |         |       |       |   |       |      |       |   |       |
                    |    |      |     |         |       |   5---A---B---6   |      |   5---A---B       |
SMEM_IN/OUT [2]-----|    |      |     |         |       |       | X |       |      |       | X |       |
                    |    C------D     |         |       |   4---C---D---7   |      |   4---C---D       |
SMEM_IN/OUT [3]-----|                 |         |       |       |   |       |      |       |   |       |
                    +-----------------+         |       |       1   0       |      |       1   0       |
                        |   |   |   |           |       |                   |      |                   |
                       [7] [6] [5] [4]          |       +-------------------+      +-------------------+
                        MESH_IN/OUT             |



MESH parameters are set up as so: A = 0-3, B = 4-7, C = 8-11, D = 12-15

CLUSTER MAPPING: [7, 6, 5, 4, 3, 2, 1, 0]

*/


module pe_mesh
    import pe_types::*;
#(
    parameter int MULS[16] = '{0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0},
    parameter logic [1:0] X_COORDS[16] = '{
        2'b00,
        2'b01,
        2'b00,
        2'b01,
        2'b10,
        2'b11,
        2'b10,
        2'b11,
        2'b00,
        2'b01,
        2'b00,
        2'b01,
        2'b10,
        2'b11,
        2'b10,
        2'b11
    },
    parameter logic [1:0] Y_COORDS[16] = '{
        2'b00,
        2'b00,
        2'b01,
        2'b01,
        2'b00,
        2'b00,
        2'b01,
        2'b01,
        2'b10,
        2'b10,
        2'b11,
        2'b11,
        2'b10,
        2'b10,
        2'b11,
        2'b11
    }
) (
    input logic clk,
    input logic rst,

    // PE Mesh outputs 1 when it can take IN a packet from OUTSIDE
    output logic    mesh_in_deq  [8],
    input  logic    mesh_in_empty[8],
    input  packet_t mesh_in_rdata[8],

    // Input 1 = PE Mesh can publish its packet to OUTSIDE consumer
    input  logic    mesh_out_deq  [8],
    output logic    mesh_out_empty[8],
    output packet_t mesh_out_rdata[8],

    output logic    smem_in_deq  [4],
    input  logic    smem_in_empty[4],
    input  packet_t smem_in_rdata[4],

    input  logic    smem_out_deq  [4],
    output logic    smem_out_empty[4],
    output packet_t smem_out_rdata[4]
);

    logic a_in_empty[8], a_in_deq[8], a_eg_empty[8], a_eg_deq[8];
    packet_t a_eg_rdata[8], a_in_rdata[8];
    logic c_in_empty[8], c_in_deq[8], c_eg_empty[8], c_eg_deq[8];
    packet_t c_eg_rdata[8], c_in_rdata[8];
    logic b_in_empty[6], b_in_deq[6], b_eg_empty[6], b_eg_deq[6];
    packet_t b_eg_rdata[6], b_in_rdata[6];
    logic d_in_empty[6], d_in_deq[6], d_eg_empty[6], d_eg_deq[6];
    packet_t d_eg_rdata[6], d_in_rdata[6];

    assign mesh_in_deq = '{
            b_in_deq[3],
            b_in_deq[2],
            a_in_deq[3],
            a_in_deq[2],
            d_in_deq[0],
            d_in_deq[1],
            c_in_deq[0],
            c_in_deq[1]
        };
    assign mesh_out_empty = '{
            b_eg_empty[3],
            b_eg_empty[2],
            a_eg_empty[3],
            a_eg_empty[2],
            d_eg_empty[0],
            d_eg_empty[1],
            c_eg_empty[0],
            c_eg_empty[1]
        };
    assign mesh_out_rdata = '{
            b_eg_rdata[3],
            b_eg_rdata[2],
            a_eg_rdata[3],
            a_eg_rdata[2],
            d_eg_rdata[0],
            d_eg_rdata[1],
            c_eg_rdata[0],
            c_eg_rdata[1]
        };

    assign smem_in_deq = '{a_in_deq[5], a_in_deq[4], c_in_deq[5], c_in_deq[4]};
    assign smem_out_empty = '{a_eg_empty[5], a_eg_empty[4], c_eg_empty[5], c_eg_empty[4]};
    assign smem_out_rdata = '{a_eg_rdata[5], a_eg_rdata[4], c_eg_rdata[5], c_eg_rdata[4]};


    assign a_eg_deq = '{
            c_in_deq[3],
            c_in_deq[2],
            mesh_out_deq[3],
            mesh_out_deq[2],
            smem_out_deq[1],
            smem_out_deq[0],
            b_in_deq[5],
            b_in_deq[4]
        };
    assign a_in_empty = '{
            c_eg_empty[3],
            c_eg_empty[2],
            mesh_in_empty[3],
            mesh_in_empty[2],
            smem_in_empty[1],
            smem_in_empty[0],
            b_eg_empty[5],
            b_eg_empty[4]
        };
    assign a_in_rdata = '{
            c_eg_rdata[3],
            c_eg_rdata[2],
            mesh_in_rdata[3],
            mesh_in_rdata[2],
            smem_in_rdata[1],
            smem_in_rdata[0],
            b_eg_rdata[5],
            b_eg_rdata[4]
        };

    pe_cluster #(
        .EDGE    (0),
        .MULS    ('{MULS[0], MULS[1], MULS[2], MULS[3]}),
        .X_COORDS('{X_COORDS[0], X_COORDS[1], X_COORDS[2], X_COORDS[3]}),
        .Y_COORDS('{Y_COORDS[0], Y_COORDS[1], Y_COORDS[2], Y_COORDS[3]})
    ) cluster_a (
        .clk          (clk),
        .rst          (rst),
        .ingress_deq  (a_in_deq),
        .ingress_empty(a_in_empty),
        .ingress_rdata(a_in_rdata),
        .egress_deq   (a_eg_deq),
        .egress_empty (a_eg_empty),
        .egress_rdata (a_eg_rdata)
    );

    assign b_eg_deq = '{
            d_in_deq[3],
            d_in_deq[2],
            mesh_out_deq[1],
            mesh_out_deq[0],
            a_in_deq[7],
            a_in_deq[6]
        };
    assign b_in_empty = '{
            d_eg_empty[3],
            d_eg_empty[2],
            mesh_in_empty[1],
            mesh_in_empty[0],
            a_eg_empty[7],
            a_eg_empty[6]
        };
    assign b_in_rdata = '{
            d_eg_rdata[3],
            d_eg_rdata[2],
            mesh_in_rdata[1],
            mesh_in_rdata[0],
            a_eg_rdata[7],
            a_eg_rdata[6]
        };

    pe_cluster #(
        .EDGE    (1),
        .MULS    ('{MULS[4], MULS[5], MULS[6], MULS[7]}),
        .X_COORDS('{X_COORDS[4], X_COORDS[5], X_COORDS[6], X_COORDS[7]}),
        .Y_COORDS('{Y_COORDS[4], Y_COORDS[5], Y_COORDS[6], Y_COORDS[7]})
    ) cluster_b (
        .clk          (clk),
        .rst          (rst),
        .ingress_deq  (b_in_deq),
        .ingress_empty(b_in_empty),
        .ingress_rdata(b_in_rdata),
        .egress_deq   (b_eg_deq),
        .egress_empty (b_eg_empty),
        .egress_rdata (b_eg_rdata)
    );

    assign c_eg_deq = '{
            mesh_out_deq[6],
            mesh_out_deq[7],
            a_in_deq[1],
            a_in_deq[0],
            smem_out_deq[3],
            smem_out_deq[2],
            d_in_deq[5],
            d_in_deq[4]
        };
    assign c_in_empty = '{
            mesh_in_empty[6],
            mesh_in_empty[7],
            a_eg_empty[1],
            a_eg_empty[0],
            smem_in_empty[3],
            smem_in_empty[2],
            d_eg_empty[5],
            d_eg_empty[4]
        };
    assign c_in_rdata = '{
            mesh_in_rdata[6],
            mesh_in_rdata[7],
            a_eg_rdata[1],
            a_eg_rdata[0],
            smem_in_rdata[3],
            smem_in_rdata[2],
            d_eg_rdata[5],
            d_eg_rdata[4]
        };

    pe_cluster #(
        .EDGE    (0),
        .MULS    ('{MULS[8], MULS[9], MULS[10], MULS[11]}),
        .X_COORDS('{X_COORDS[8], X_COORDS[9], X_COORDS[10], X_COORDS[11]}),
        .Y_COORDS('{Y_COORDS[8], Y_COORDS[9], Y_COORDS[10], Y_COORDS[11]})
    ) cluster_c (
        .clk          (clk),
        .rst          (rst),
        .ingress_deq  (c_in_deq),
        .ingress_empty(c_in_empty),
        .ingress_rdata(c_in_rdata),
        .egress_deq   (c_eg_deq),
        .egress_empty (c_eg_empty),
        .egress_rdata (c_eg_rdata)
    );

    assign d_eg_deq = '{
            mesh_out_deq[4],
            mesh_out_deq[5],
            b_in_deq[1],
            b_in_deq[0],
            c_in_deq[7],
            c_in_deq[6]
        };
    assign d_in_empty = '{
            mesh_in_empty[4],
            mesh_in_empty[5],
            b_eg_empty[1],
            b_eg_empty[0],
            c_eg_empty[7],
            c_eg_empty[6]
        };
    assign d_in_rdata = '{
            mesh_in_rdata[4],
            mesh_in_rdata[5],
            b_eg_rdata[1],
            b_eg_rdata[0],
            c_eg_rdata[7],
            c_eg_rdata[6]
        };

    pe_cluster #(
        .EDGE    (1),
        .MULS    ('{MULS[12], MULS[13], MULS[14], MULS[15]}),
        .X_COORDS('{X_COORDS[12], X_COORDS[13], X_COORDS[14], X_COORDS[15]}),
        .Y_COORDS('{Y_COORDS[12], Y_COORDS[13], Y_COORDS[14], Y_COORDS[15]})
    ) cluster_d (
        .clk          (clk),
        .rst          (rst),
        .ingress_deq  (d_in_deq),
        .ingress_empty(d_in_empty),
        .ingress_rdata(d_in_rdata),
        .egress_deq   (d_eg_deq),
        .egress_empty (d_eg_empty),
        .egress_rdata (d_eg_rdata)
    );

endmodule
