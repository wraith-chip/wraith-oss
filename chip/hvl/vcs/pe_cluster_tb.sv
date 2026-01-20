`define scyan $write("\033[38:5:33m")
`define sgreen $write("\033[38:5:10m")
`define sygre $write("\033[38:5:46m")
`define syellow $write("\033[38:5:172m")
`define sblue $write("\033[38:5:21m")
`define sclear $write("\033[0m")

module pe_cluster_tb;
    timeunit 1ps; timeprecision 1ps;
    import pe_types::*;
    logic top_clk;
    logic rst;

    typedef enum logic [2:0] {
        SR,
        SL,
        NR,
        NL,
        WL,
        WR,
        EL,
        ER
    } cluster_port_t;

    localparam int SIDES = 8;

    logic ingress_empty[SIDES];
    packet_t ingress_rdata[SIDES];
    logic ingress_deq[SIDES];
    logic egress_deq[SIDES];
    logic egress_empty[SIDES];
    packet_t egress_rdata[SIDES];

    //TB Ingress signals
    logic ingress_enq[SIDES];
    packet_t ingress_wdata[SIDES];
    logic ingress_full[SIDES];

    function automatic packet_t gen_config_pkt(
        input logic [3:0] pat_ind, input fu_func op, input rf_reg src, input egress_id dest,
        input pid_t response_pid, input rf_reg rd, input logic [1:0] x_coord = 2'b00,
        input logic [1:0] y_coord = 2'b00);

        config_payload_t config_payload = '{
            x_coord: x_coord,
            y_coord: y_coord,
            pat_ind: pat_ind,
            pat_w_entry: '{
                default: '0,
                fu_op: op,
                src: src,
                dest: dest,
                response_pid: response_pid,
                rd: rd
            },
            padding: '0
        };

        return '{pid: '0, payload: config_payload};

    endfunction


    function automatic packet_t gen_const_pkt(input rf_reg rd, input logic [22:0] imm,
                                              input logic [1:0] x_coord = 2'b00,
                                              input logic [1:0] y_coord = 2'b00);

        const_payload_t const_payload = '{x_coord: x_coord, y_coord: y_coord, rd: rd, imm: imm};

        return '{pid: 'd1, payload: const_payload};

    endfunction

    // Send a single packet and lower the enq signal
    task automatic send_pkt(input packet_t pkt, input cluster_port_t dir);
        ingress_wdata[dir] <= pkt;
        ingress_enq[dir]   <= '1;
        @(posedge top_clk);
        ingress_enq[dir] <= '0;
        @(posedge top_clk);
    endtask

    // Send a single packet, but don't lower the enq signal at the end, to chain them together.
    task automatic send_stream_pkt(input packet_t pkt, input cluster_port_t dir);
        // Block the stream until it empties.
        while (ingress_full[dir]) begin
            // ingress_enq[dir] <= '0;
            @(posedge top_clk);
        end
        ingress_wdata[dir] <= pkt;
        ingress_enq[dir]   <= '1;
        @(posedge top_clk);
    endtask

    // Send an array of packets, optionally as part of a full stream.
    task automatic send_array_pkt(input packet_t pkts[], input cluster_port_t dir,
                                  input int isStream = 0);
        ingress_enq[dir] <= '1;
        foreach (pkts[i]) begin
            ingress_wdata[dir] <= pkts[i];
            @(posedge top_clk);
        end
        if (isStream == 0) begin
            ingress_enq[dir] <= '0;
            @(posedge top_clk);
        end
    endtask

    // Lower enqueue signal
    task automatic stop_stream(input cluster_port_t dir);
        ingress_enq[dir] <= '0;
        @(posedge top_clk);
    endtask

    int clock_half_period_ps;
    longint timeout;
    initial begin
        clock_half_period_ps = 200;
        timeout = 1000000;
    end

    initial top_clk = 1'b0;
    always #(clock_half_period_ps) top_clk = ~top_clk;

    initial rst = 1'b1;

    initial begin
        for (int i = 0; i < SIDES; i++) begin
            ingress_enq[i] = '0;
            egress_deq[i]  = '0;
        end
    end

    // Make some driving FIFOs
    genvar ind;
    generate
        for (ind = 0; ind < SIDES; ind++) begin : gen_ingress_fifo
            fifo #(
                .DEPTH(2),
                .WIDTH($bits(packet_t))
            ) u_fifo (
                .clk(top_clk),
                .rst(rst),

                .enqueue(ingress_enq[ind]),
                .wdata  (ingress_wdata[ind]),

                .dequeue(ingress_deq[ind]),
                .rdata  (ingress_rdata[ind]),

                .full (ingress_full[ind]),
                .empty(ingress_empty[ind])
            );
        end
    endgenerate

    pe_cluster #(
        .EDGE(0),
        .MULS('{0, 1, 0, 1})
    ) dut (
        .clk          (top_clk),
        .rst          (rst),
        .ingress_deq  (ingress_deq),
        .ingress_empty(ingress_empty),
        .ingress_rdata(ingress_rdata),
        .egress_deq   (egress_deq),
        .egress_empty (egress_empty),
        .egress_rdata (egress_rdata)
    );

    initial begin
        packet_t initial_config[];
        initial_config = new[56];
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, "+all");
        repeat (2) @(posedge top_clk);
        rst = '0;



        initial_config = '{
            gen_config_pkt(pid_t'(2), fu_op_add, 5'd1, EAST, pid_t'(2), 5'd0, 2'd0, 2'd0),
            gen_config_pkt(pid_t'(3), fu_op_add, 5'd1, EAST, pid_t'(2), 5'd0, 2'd0, 2'd0),
            gen_config_pkt(pid_t'(4), fu_op_add, 5'd1, EAST, pid_t'(2), 5'd0, 2'd0, 2'd0),
            gen_config_pkt(pid_t'(5), fu_op_add, 5'd1, EAST, pid_t'(2), 5'd0, 2'd0, 2'd0),
            gen_config_pkt(pid_t'(6), fu_op_add, 5'd1, EAST, pid_t'(2), 5'd0, 2'd0, 2'd0),
            gen_config_pkt(pid_t'(7), fu_op_add, 5'd1, EAST, pid_t'(2), 5'd0, 2'd0, 2'd0),
            gen_config_pkt(pid_t'(8), fu_op_add, 5'd1, EAST, pid_t'(2), 5'd0, 2'd0, 2'd0),
            gen_config_pkt(pid_t'(9), fu_op_add, 5'd1, EAST, pid_t'(2), 5'd0, 2'd0, 2'd0),
            gen_config_pkt(pid_t'(10), fu_op_add, 5'd1, EAST, pid_t'(2), 5'd0, 2'd0, 2'd0),
            gen_config_pkt(pid_t'(11), fu_op_add, 5'd1, EAST, pid_t'(2), 5'd0, 2'd0, 2'd0),
            gen_config_pkt(pid_t'(12), fu_op_add, 5'd1, EAST, pid_t'(2), 5'd0, 2'd0, 2'd0),
            gen_config_pkt(pid_t'(13), fu_op_add, 5'd1, EAST, pid_t'(2), 5'd0, 2'd0, 2'd0),
            gen_config_pkt(pid_t'(14), fu_op_add, 5'd1, EAST, pid_t'(2), 5'd0, 2'd0, 2'd0),
            gen_config_pkt(pid_t'(15), fu_op_add, 5'd1, EAST, pid_t'(2), 5'd0, 2'd0, 2'd0),

            gen_config_pkt(pid_t'(2), fu_op_mul, 5'd1, SOUTH, pid_t'(2), 5'd0, 2'd1, 2'd0),
            gen_config_pkt(pid_t'(3), fu_op_mul, 5'd1, SOUTH, pid_t'(2), 5'd0, 2'd1, 2'd0),
            gen_config_pkt(pid_t'(4), fu_op_mul, 5'd1, SOUTH, pid_t'(2), 5'd0, 2'd1, 2'd0),
            gen_config_pkt(pid_t'(5), fu_op_mul, 5'd1, SOUTH, pid_t'(2), 5'd0, 2'd1, 2'd0),
            gen_config_pkt(pid_t'(6), fu_op_mul, 5'd1, SOUTH, pid_t'(2), 5'd0, 2'd1, 2'd0),
            gen_config_pkt(pid_t'(7), fu_op_mul, 5'd1, SOUTH, pid_t'(2), 5'd0, 2'd1, 2'd0),
            gen_config_pkt(pid_t'(8), fu_op_mul, 5'd1, SOUTH, pid_t'(2), 5'd0, 2'd1, 2'd0),
            gen_config_pkt(pid_t'(9), fu_op_mul, 5'd1, SOUTH, pid_t'(2), 5'd0, 2'd1, 2'd0),
            gen_config_pkt(pid_t'(10), fu_op_mul, 5'd1, SOUTH, pid_t'(2), 5'd0, 2'd1, 2'd0),
            gen_config_pkt(pid_t'(11), fu_op_mul, 5'd1, SOUTH, pid_t'(2), 5'd0, 2'd1, 2'd0),
            gen_config_pkt(pid_t'(12), fu_op_mul, 5'd1, SOUTH, pid_t'(2), 5'd0, 2'd1, 2'd0),
            gen_config_pkt(pid_t'(13), fu_op_mul, 5'd1, SOUTH, pid_t'(2), 5'd0, 2'd1, 2'd0),
            gen_config_pkt(pid_t'(14), fu_op_mul, 5'd1, SOUTH, pid_t'(2), 5'd0, 2'd1, 2'd0),
            gen_config_pkt(pid_t'(15), fu_op_mul, 5'd1, SOUTH, pid_t'(2), 5'd0, 2'd1, 2'd0),

            gen_config_pkt(pid_t'(2), fu_op_add, 5'd1, WEST, pid_t'(2), 5'd0, 2'd1, 2'd1),
            gen_config_pkt(pid_t'(3), fu_op_add, 5'd1, WEST, pid_t'(2), 5'd0, 2'd1, 2'd1),
            gen_config_pkt(pid_t'(4), fu_op_add, 5'd1, WEST, pid_t'(2), 5'd0, 2'd1, 2'd1),
            gen_config_pkt(pid_t'(5), fu_op_add, 5'd1, WEST, pid_t'(2), 5'd0, 2'd1, 2'd1),
            gen_config_pkt(pid_t'(6), fu_op_add, 5'd1, WEST, pid_t'(2), 5'd0, 2'd1, 2'd1),
            gen_config_pkt(pid_t'(7), fu_op_add, 5'd1, WEST, pid_t'(2), 5'd0, 2'd1, 2'd1),
            gen_config_pkt(pid_t'(8), fu_op_add, 5'd1, WEST, pid_t'(2), 5'd0, 2'd1, 2'd1),
            gen_config_pkt(pid_t'(9), fu_op_add, 5'd1, WEST, pid_t'(2), 5'd0, 2'd1, 2'd1),
            gen_config_pkt(pid_t'(10), fu_op_add, 5'd1, WEST, pid_t'(2), 5'd0, 2'd1, 2'd1),
            gen_config_pkt(pid_t'(11), fu_op_add, 5'd1, WEST, pid_t'(2), 5'd0, 2'd1, 2'd1),
            gen_config_pkt(pid_t'(12), fu_op_add, 5'd1, WEST, pid_t'(2), 5'd0, 2'd1, 2'd1),
            gen_config_pkt(pid_t'(13), fu_op_add, 5'd1, WEST, pid_t'(2), 5'd0, 2'd1, 2'd1),
            gen_config_pkt(pid_t'(14), fu_op_add, 5'd1, WEST, pid_t'(2), 5'd0, 2'd1, 2'd1),
            gen_config_pkt(pid_t'(15), fu_op_add, 5'd1, WEST, pid_t'(2), 5'd0, 2'd1, 2'd1),

            gen_config_pkt(pid_t'(2), fu_op_mul, 5'd1, WEST, pid_t'(2), 5'd0, 2'd0, 2'd1),
            gen_config_pkt(pid_t'(3), fu_op_mul, 5'd1, WEST, pid_t'(2), 5'd0, 2'd0, 2'd1),
            gen_config_pkt(pid_t'(4), fu_op_mul, 5'd1, WEST, pid_t'(2), 5'd0, 2'd0, 2'd1),
            gen_config_pkt(pid_t'(5), fu_op_mul, 5'd1, WEST, pid_t'(2), 5'd0, 2'd0, 2'd1),
            gen_config_pkt(pid_t'(6), fu_op_mul, 5'd1, WEST, pid_t'(2), 5'd0, 2'd0, 2'd1),
            gen_config_pkt(pid_t'(7), fu_op_mul, 5'd1, WEST, pid_t'(2), 5'd0, 2'd0, 2'd1),
            gen_config_pkt(pid_t'(8), fu_op_mul, 5'd1, WEST, pid_t'(2), 5'd0, 2'd0, 2'd1),
            gen_config_pkt(pid_t'(9), fu_op_mul, 5'd1, WEST, pid_t'(2), 5'd0, 2'd0, 2'd1),
            gen_config_pkt(pid_t'(10), fu_op_mul, 5'd1, WEST, pid_t'(2), 5'd0, 2'd0, 2'd1),
            gen_config_pkt(pid_t'(11), fu_op_mul, 5'd1, WEST, pid_t'(2), 5'd0, 2'd0, 2'd1),
            gen_config_pkt(pid_t'(12), fu_op_mul, 5'd1, WEST, pid_t'(2), 5'd0, 2'd0, 2'd1),
            gen_config_pkt(pid_t'(13), fu_op_mul, 5'd1, WEST, pid_t'(2), 5'd0, 2'd0, 2'd1),
            gen_config_pkt(pid_t'(14), fu_op_mul, 5'd1, WEST, pid_t'(2), 5'd0, 2'd0, 2'd1),
            gen_config_pkt(pid_t'(15), fu_op_mul, 5'd1, WEST, pid_t'(2), 5'd0, 2'd0, 2'd1)
        };

        send_array_pkt(initial_config, WR);
        repeat (50) @(posedge top_clk);

        send_pkt('{'d2, 'ha0}, WR);
        repeat (25) @(posedge top_clk);
        $finish();
    end

endmodule
