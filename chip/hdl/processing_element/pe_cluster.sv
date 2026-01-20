/* The PE Cluster is a 2x2 matrix of PEs

We will follow this naming scheme:

A --- B
| \ / |
| / \ |
C --- D

MAPPING: [7, 6, 5, 4, 3, 2, 1, 0]

The placement of the ports is such that we can reuse the module def for pe_cluster_edge
while ignoring Y and Z by hardsetting them to 0


                    NON-EDGE                    EDGE
            +-------------------+      +-------------------+
            |                   |      |                   |
            |       2   3       |      |       2   3       |
            |       |   |       |      |       |   |       |
            |   5---A---B---6   |      |   5---A---B       |
            |       | X |       |      |       | X |       |
            |   4---C---D---7   |      |   4---C---D       |
            |       |   |       |      |       |   |       |
            |       1   0       |      |       1   0       |
            |                   |      |                   |
            +-------------------+      +-------------------+

The ingress and egress arrays are organized in the format- '{north, west, south, diag, east}
                                                            {0    , 1   , 2    , 3   , 4   }

*/

module pe_cluster
    import pe_types::*;
#(
    parameter int PORTS = 4,
    parameter int EDGE = 0,
    parameter int MULS[4] = '{1, 0, 1, 0},
    parameter logic [1:0] X_COORDS[4] = '{2'b00, 2'b01, 2'b00, 2'b01},
    parameter logic [1:0] Y_COORDS[4] = '{2'b00, 2'b00, 2'b01, 2'b01}
) (
    input logic clk,
    input logic rst,

    output logic    ingress_deq  [8-EDGE-EDGE],
    input  logic    ingress_empty[8-EDGE-EDGE],
    input  packet_t ingress_rdata[8-EDGE-EDGE],

    input  logic    egress_deq  [8-EDGE-EDGE],
    output logic    egress_empty[8-EDGE-EDGE],
    output packet_t egress_rdata[8-EDGE-EDGE]
);

    // Internal Pairs (inside the cluster)

    // A Signals

    logic    a_in_empty [PORTS];
    logic    a_in_deq   [PORTS];
    logic    a_out_empty[PORTS];
    logic    a_out_deq  [PORTS];
    packet_t a_out_rdata[PORTS];
    packet_t a_in_rdata [PORTS];

    // B Signals
    logic    b_in_empty [PORTS-EDGE];
    logic    b_in_deq   [PORTS-EDGE];
    logic    b_out_empty[PORTS-EDGE];
    logic    b_out_deq  [PORTS-EDGE];
    packet_t b_out_rdata[PORTS-EDGE];
    packet_t b_in_rdata [PORTS-EDGE];

    // C Signals
    logic    c_in_empty [PORTS];
    logic    c_in_deq   [PORTS];
    logic    c_out_empty[PORTS];
    logic    c_out_deq  [PORTS];
    packet_t c_out_rdata[PORTS];
    packet_t c_in_rdata [PORTS];

    // D Signals
    logic    d_in_empty [PORTS-EDGE];
    logic    d_in_deq   [PORTS-EDGE];
    logic    d_out_empty[PORTS-EDGE];
    logic    d_out_deq  [PORTS-EDGE];
    packet_t d_out_rdata[PORTS-EDGE];
    packet_t d_in_rdata [PORTS-EDGE];

    // Shared Regfile
    logic           rf_we      [     4];
    rf_reg          rd         [     4];
    logic    [31:0] rd_v       [     4];
    rf_reg          rs         [     4];
    logic    [31:0] rs_v       [     4];

    // Connections to I/O of Cluster
    if (EDGE == 1) begin : gen_io_edge
        assign egress_empty = '{
                d_out_empty[2],
                c_out_empty[2],
                a_out_empty[0],
                b_out_empty[0],
                c_out_empty[1],
                a_out_empty[1]
            };
        assign egress_rdata = '{
                d_out_rdata[2],
                c_out_rdata[2],
                a_out_rdata[0],
                b_out_rdata[0],
                c_out_rdata[1],
                a_out_rdata[1]
            };
        assign ingress_deq = '{
                d_out_deq[2],
                c_out_deq[2],
                a_out_deq[0],
                b_out_deq[0],
                c_out_deq[1],
                a_out_deq[1]
            };
    end else begin : gen_io_full
        assign egress_empty = '{
                d_out_empty[2],
                c_out_empty[2],
                a_out_empty[0],
                b_out_empty[0],
                c_out_empty[1],
                a_out_empty[1],
                b_out_empty[3],
                d_out_empty[3]
            };
        assign egress_rdata = '{
                d_out_rdata[2],
                c_out_rdata[2],
                a_out_rdata[0],
                b_out_rdata[0],
                c_out_rdata[1],
                a_out_rdata[1],
                b_out_rdata[3],
                d_out_rdata[3]
            };
        assign ingress_deq = '{
                d_out_deq[2],
                c_out_deq[2],
                a_out_deq[0],
                b_out_deq[0],
                c_out_deq[1],
                a_out_deq[1],
                b_out_deq[3],
                d_out_deq[3]
            };
    end

    // A Bundles
    assign a_in_empty = '{ingress_empty[2], ingress_empty[5], c_out_empty[0], b_out_empty[1]};
    assign a_in_rdata = '{ingress_rdata[2], ingress_rdata[5], c_out_rdata[0], b_out_rdata[1]};
    assign a_in_deq   = '{egress_deq[2], egress_deq[5], c_out_deq[0], b_out_deq[1]};

    // B Bundles
    if (EDGE == 1) begin : gen_b_cluster_4
        assign b_in_empty = '{ingress_empty[3], a_out_empty[3], d_out_empty[0]};
        assign b_in_rdata = '{ingress_rdata[3], a_out_rdata[3], d_out_rdata[0]};
        assign b_in_deq   = '{egress_deq[3], a_out_deq[3], d_out_deq[0]};
    end else begin : gen_b_cluster_5
        assign b_in_empty = '{ingress_empty[3], a_out_empty[3], d_out_empty[0], ingress_empty[6]};
        assign b_in_rdata = '{ingress_rdata[3], a_out_rdata[3], d_out_rdata[0], ingress_rdata[6]};
        assign b_in_deq   = '{egress_deq[3], a_out_deq[3], d_out_deq[0], egress_deq[6]};
    end

    // C Bundles
    assign c_in_empty = '{a_out_empty[2], ingress_empty[4], ingress_empty[1], d_out_empty[1]};
    assign c_in_rdata = '{a_out_rdata[2], ingress_rdata[4], ingress_rdata[1], d_out_rdata[1]};
    assign c_in_deq   = '{a_out_deq[2], egress_deq[4], egress_deq[1], d_out_deq[1]};

    // D Bundles
    if (EDGE == 1) begin : gen_d_cluster_3
        assign d_in_empty = '{b_out_empty[2], c_out_empty[3], ingress_empty[0]};
        assign d_in_rdata = '{b_out_rdata[2], c_out_rdata[3], ingress_rdata[0]};
        assign d_in_deq   = '{b_out_deq[2], c_out_deq[3], egress_deq[0]};
    end else begin : gen_d_cluster_4
        assign d_in_empty = '{b_out_empty[2], c_out_empty[3], ingress_empty[0], ingress_empty[7]};
        assign d_in_rdata = '{b_out_rdata[2], c_out_rdata[3], ingress_rdata[0], ingress_rdata[7]};
        assign d_in_deq   = '{b_out_deq[2], c_out_deq[3], egress_deq[0], egress_deq[7]};
    end

    pe #(
        .IS_MUL (MULS[0]),
        .PORTS  (PORTS),
        .X_COORD(X_COORDS[0]),
        .Y_COORD(Y_COORDS[0])
    ) pe_a (
        .clk          (clk),
        .rst          (rst),
        .ingress_empty(a_in_empty),
        .ingress_rdata(a_in_rdata),
        .ingress_deq  (a_out_deq),
        .egress_empty (a_out_empty),
        .egress_rdata (a_out_rdata),
        .egress_deq   (a_in_deq),

        .rf_we(rf_we[0]),
        .rd   (rd[0]),
        .rd_v (rd_v[0]),
        .rs   (rs[0]),
        .rs_v (rs_v[0])
    );

    pe #(
        .IS_MUL (MULS[1]),
        .PORTS  (PORTS - EDGE),
        .X_COORD(X_COORDS[1]),
        .Y_COORD(Y_COORDS[1])
    ) pe_b (
        .clk          (clk),
        .rst          (rst),
        .ingress_empty(b_in_empty),
        .ingress_rdata(b_in_rdata),
        .ingress_deq  (b_out_deq),
        .egress_empty (b_out_empty),
        .egress_rdata (b_out_rdata),
        .egress_deq   (b_in_deq),

        .rf_we(rf_we[1]),
        .rd   (rd[1]),
        .rd_v (rd_v[1]),
        .rs   (rs[1]),
        .rs_v (rs_v[1])
    );

    pe #(
        .IS_MUL (MULS[2]),
        .PORTS  (PORTS),
        .X_COORD(X_COORDS[2]),
        .Y_COORD(Y_COORDS[2])
    ) pe_c (
        .clk          (clk),
        .rst          (rst),
        .ingress_empty(c_in_empty),
        .ingress_rdata(c_in_rdata),
        .ingress_deq  (c_out_deq),
        .egress_empty (c_out_empty),
        .egress_rdata (c_out_rdata),
        .egress_deq   (c_in_deq),

        .rf_we(rf_we[2]),
        .rd   (rd[2]),
        .rd_v (rd_v[2]),
        .rs   (rs[2]),
        .rs_v (rs_v[2])
    );

    pe #(
        .IS_MUL (MULS[3]),
        .PORTS  (PORTS - EDGE),
        .X_COORD(X_COORDS[3]),
        .Y_COORD(Y_COORDS[3])
    ) pe_d (
        .clk          (clk),
        .rst          (rst),
        .ingress_empty(d_in_empty),
        .ingress_rdata(d_in_rdata),
        .ingress_deq  (d_out_deq),
        .egress_empty (d_out_empty),
        .egress_rdata (d_out_rdata),
        .egress_deq   (d_in_deq),

        .rf_we(rf_we[3]),
        .rd   (rd[3]),
        .rd_v (rd_v[3]),
        .rs   (rs[3]),
        .rs_v (rs_v[3])
    );

    pe_rf u_pe_rf (
        .clk  (clk),
        .rf_we(rf_we),
        .rd   (rd),
        .rd_v (rd_v),
        .rs   (rs),
        .rs_v (rs_v)
    );

endmodule
