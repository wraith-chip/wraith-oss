`define scyan $write("\033[38:5:33m")
`define sgreen $write("\033[38:5:10m")
`define sygre $write("\033[38:5:46m")
`define syellow $write("\033[38:5:172m")
`define sblue $write("\033[38:5:21m")
`define sclear $write("\033[0m")

module pe_tb;
    timeunit 1ps; timeprecision 1ps;
    import pe_types::*;
    logic           top_clk;
    logic           rst;

    logic           ingress_empty [ 4];
    packet_t        ingress_rdata [ 4];
    logic           ingress_deq   [ 4];
    logic           egress_deq    [ 4];
    logic           egress_empty  [ 4];
    packet_t        egress_rdata  [ 4];

    //TB Ingress signals
    logic           ingress_enq   [ 4];
    packet_t        ingress_wdata [ 4];
    logic           ingress_full  [ 4];

    // Regfile signals

    logic           rf_we         [ 4];
    rf_reg          rd            [ 4];
    logic    [31:0] rd_v          [ 4];

    rf_reg          rs            [ 4];

    logic    [31:0] rs_v          [ 4];


    packet_t        bringup_config[14];
    packet_t        bringup_const [30];

    initial begin
        // High Entropy Program :)
        bringup_config = '{
            gen_config_pkt(4'(2), fu_op_add, 5'd1, 3'b000, pid_t'(15), 5'd15),
            gen_config_pkt(4'(3), fu_op_sll, 5'd2, 3'b001, pid_t'(2), 5'd16),
            gen_config_pkt(4'(4), fu_op_sra, 5'd3, 3'b010, pid_t'(3), 5'd17),
            gen_config_pkt(4'(5), fu_op_sub, 5'd4, 3'b011, pid_t'(4), 5'd18),
            gen_config_pkt(4'(6), fu_op_xor, 5'd5, 3'b000, pid_t'(5), 5'd19),
            gen_config_pkt(4'(7), fu_op_srl, 5'd7, 3'b000, pid_t'(6), 5'd20),
            gen_config_pkt(4'(8), fu_op_or, 5'd8, 3'b001, pid_t'(7), 5'd21),
            gen_config_pkt(4'(9), fu_op_and, 5'd9, 3'b000, pid_t'(8), 5'd22),
            gen_config_pkt(4'(10), fu_op_add, 5'd10, 3'b001, pid_t'(9), 5'd23),
            gen_config_pkt(4'(11), fu_op_sra, 5'd11, 3'b010, pid_t'(10), 5'd24),
            gen_config_pkt(4'(12), fu_op_sub, 5'd12, 3'b011, pid_t'(11), 5'd25),
            gen_config_pkt(4'(13), fu_op_xor, 5'd13, 3'b000, pid_t'(12), 5'd26),
            gen_config_pkt(4'(14), fu_op_srl, 5'd14, 3'b000, pid_t'(13), 5'd27),
            gen_config_pkt(4'(15), fu_op_or, 5'd15, 3'b001, pid_t'(14), 5'd28)
        };

        // Generate some useful constants (some may be overwritten without read)
        for (logic [5:0] i = 'd2; i < 'd32; i++) begin
            bringup_const[i-'d2] = gen_const_pkt((5)'(i), (23)'('d2 * i));
        end
    end
    // Packet Generation Functions
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
    // Packet Sending Tasks

    // Send a single packet and lower the enq signal
    task automatic send_pkt(input packet_t pkt, input port_dir_t dir);
        ingress_wdata[dir] <= pkt;
        ingress_enq[dir]   <= '1;
        @(posedge top_clk);
        ingress_enq[dir] <= '0;
        @(posedge top_clk);
    endtask

    // Send a single packet, but don't lower the enq signal at the end, to chain them together.
    task automatic send_stream_pkt(input packet_t pkt, input port_dir_t dir);
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
    task automatic send_array_pkt(input packet_t pkts[], input port_dir_t dir,
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
    task automatic stop_stream(input port_dir_t dir);
        ingress_enq[dir] <= '0;
        @(posedge top_clk);
    endtask

    // Do Full Bringup (Tested separately below)
    task automatic bringup();
        packet_t config_pkt_stream[];
        packet_t const_pkt_stream [];


        config_pkt_stream = new[14];
        const_pkt_stream = new[7];

        // High Entropy Program :)
        config_pkt_stream = '{
            gen_config_pkt(4'(2), fu_op_add, 5'd1, 3'b000, pid_t'(15), 5'd15),
            gen_config_pkt(4'(3), fu_op_sll, 5'd2, 3'b001, pid_t'(2), 5'd16),
            gen_config_pkt(4'(4), fu_op_sra, 5'd3, 3'b010, pid_t'(3), 5'd17),
            gen_config_pkt(4'(5), fu_op_sub, 5'd4, 3'b011, pid_t'(4), 5'd18),
            gen_config_pkt(4'(6), fu_op_xor, 5'd5, 3'b000, pid_t'(5), 5'd19),
            gen_config_pkt(4'(7), fu_op_srl, 5'd7, 3'b000, pid_t'(6), 5'd20),
            gen_config_pkt(4'(8), fu_op_or, 5'd8, 3'b001, pid_t'(7), 5'd21),
            gen_config_pkt(4'(9), fu_op_and, 5'd9, 3'b000, pid_t'(8), 5'd22),
            gen_config_pkt(4'(10), fu_op_add, 5'd10, 3'b001, pid_t'(9), 5'd23),
            gen_config_pkt(4'(11), fu_op_sra, 5'd11, 3'b010, pid_t'(10), 5'd24),
            gen_config_pkt(4'(12), fu_op_sub, 5'd12, 3'b011, pid_t'(11), 5'd25),
            gen_config_pkt(4'(13), fu_op_xor, 5'd13, 3'b000, pid_t'(12), 5'd26),
            gen_config_pkt(4'(14), fu_op_srl, 5'd14, 3'b000, pid_t'(13), 5'd27),
            gen_config_pkt(4'(15), fu_op_or, 5'd15, 3'b001, pid_t'(14), 5'd28)
        };

        // Generate some useful constants (some may be overwritten without read)
        for (logic [5:0] i = 'd1; i < 'd8; i++) begin
            const_pkt_stream[i-'d1] = gen_const_pkt((5)'(i), (23)'('d2 * i));
        end

        send_array_pkt(config_pkt_stream, WEST);
        send_array_pkt(const_pkt_stream, WEST);
        repeat (10) @(posedge top_clk);
    endtask

    // Force a reset.
    task static do_reset();
        rst = '1;
        repeat (2) @(posedge top_clk);
        rst = '0;
    endtask

    // Monitoring

    task static monitor_egress();
        forever
            @(posedge top_clk) begin
                for (int i = 0; i < 4; i++) begin
                    port_dir_t e;
                    e = port_dir_t'(i);
                    if (!egress_empty[i]) begin
                        egress_deq[i] = '1;
                        $write("Packet Dequed from side: ");

                        $write("%s", e.name);
                        $write(" with packet ");
                        $display("%p", egress_rdata[i]);
                    end else begin
                        egress_deq[i] = '0;
                    end
                end
            end
    endtask


    // Test Cases

    task automatic test_config_bypass();
        packet_t pkt_stream[];
        `syellow;
        $display(
            "Test: Config Bypass\nThis test sends 15 packets of all non-zero coords to see if the configuration bypass is handled correctly.");
        `sclear;
        do_reset();
        pkt_stream = new[15];
        for (logic [4:0] i = 'd1; i < 'd16; i++) begin
            pkt_stream[i-1] =
                gen_config_pkt(4'(6), fu_op_add, 'd6, 3'b111, pid_t'(11), 5'd31, i[1:0], i[3:2]);
        end

        fork
            begin
                send_array_pkt(pkt_stream, NORTH);
                repeat (10) @(posedge top_clk);
            end
            begin
                int j = 0;
                forever
                @(posedge top_clk) begin
                    for (int i = 0; i < 4; i++) begin
                        port_dir_t e;
                        e = port_dir_t'(i);
                        if (!egress_empty[i]) begin
                            egress_deq[i] = '1;
                            `scyan;
                            $write("Packet Dequed from side: ");

                            $write("%s", e.name);
                            $write(" with packet ");
                            $write("coord of %1d,%1d. ", egress_rdata[i].payload.conf.x_coord,
                                   egress_rdata[i].payload.conf.y_coord);
                            `sclear;
                            assert (egress_rdata[i] == pkt_stream[j]) `sgreen;
                            $write("Packet %1d Matches ", j);
                            `sclear;
                            assert ((pkt_stream[j].payload.conf.x_coord == 2'b0) ? i==SOUTH : i==EAST)
                                `sgreen;
                            $display("& Correct Egress Direction");
                            `sclear;
                            j = j + 1;
                        end else begin
                            egress_deq[i] = '0;
                        end
                    end
                end
            end
        join_any
        disable fork;
        `sygre;
        $display("Test: Config Bypass PASSED");
        `sclear;
    endtask


    task automatic test_const_bypass();
        packet_t pkt_stream[];
        `syellow;
        $display(
            "Test: Const Bypass\nThis test sends 15 packets of all non-zero coords to see if the constant writing bypass is handled correctly.");
        `sclear;
        do_reset();
        pkt_stream = new[15];
        for (logic [4:0] i = 'd1; i < 'd16; i++) begin
            pkt_stream[i-1] = gen_const_pkt(5'd31, 23'habcde, i[1:0], i[3:2]);
        end

        fork
            begin
                send_array_pkt(pkt_stream, NORTH);
                repeat (10) @(posedge top_clk);
            end
            begin
                int j = 0;
                forever
                @(posedge top_clk) begin
                    for (int i = 0; i < 4; i++) begin
                        port_dir_t e;
                        e = port_dir_t'(i);
                        if (!egress_empty[i]) begin
                            egress_deq[i] = '1;
                            `scyan;
                            $write("Packet Dequed from side: ");

                            $write("%s", e.name);
                            $write(" with packet ");
                            $write("coord of %1d,%1d. ", egress_rdata[i].payload.conf.x_coord,
                                   egress_rdata[i].payload.conf.y_coord);
                            `sclear;
                            assert (egress_rdata[i] == pkt_stream[j]) `sgreen;
                            $write("Packet %1d Matches ", j);
                            `sclear;
                            assert ((pkt_stream[j].payload.conf.x_coord == 2'b0) ? i==SOUTH : i==EAST)
                                `sgreen;
                            $display("& Correct Egress Direction");
                            `sclear;
                            j = j + 1;
                        end else begin
                            egress_deq[i] = '0;
                        end
                    end
                end
            end
        join_any
        disable fork;
        `sygre;
        $display("Test: Const Bypass PASSED");
        `sclear;
    endtask

    task automatic test_config_write();
        packet_t pkt_stream[];
        `syellow;
        $display(
            "Test: Config Write. This test sends 14 packets to the PE and checks that all entries get written.");
        `sclear;


        do_reset();
        pkt_stream = new[14];
        for (logic [4:0] i = 'd2; i < 'd16; i++) begin
            pkt_stream[i-2] = gen_config_pkt(i, fu_op_add, 'd6, 3'b111, i, 5'd31, 2'd0, 2'd0);
        end
        send_array_pkt(pkt_stream, NORTH);
        repeat (10) @(posedge top_clk);

        for (logic [4:0] i = 'd2; i < 'd16; i++) begin
            `sgreen;
            assert (dut.u_pe_action_table.entries[i] == pkt_stream[i-2].payload.conf.pat_w_entry)
                $display("PAT Entry %1d matches packet payload", i);
            `sclear;
        end
        `sygre;
        $display("Test: Config Write PASSED");
        `sclear;
    endtask

    task automatic test_const_write();
        packet_t pkt_stream[];
        `syellow;
        $display(
            "Test: Const Write. This test sends 7 packets to the PE and checks that all entries get written except positions 0 and 1");
        `sclear;

        do_reset();
        pkt_stream = new[7];
        for (logic [5:0] i = 'd0; i < 'd7; i++) begin
            pkt_stream[i] = gen_const_pkt((5)'(i+1), {18'habcd, (5)'(i)}, 2'd0, 2'd0);
        end
        send_array_pkt(pkt_stream, NORTH);
        repeat (10) @(posedge top_clk);

        for (logic [3:0] i = 'd1; i < 'd8; i++) begin
            `sgreen;
            assert (u_pe_rf.data[0][i] == pkt_stream[i-1].payload.cnst.imm)
                $display("RF Entry %1d matches packet payload", i);
            `sclear;
        end

        `sygre;
        $display("Test: Const Write PASSED");
        `sclear;
    endtask

    task automatic test_bringup();
        packet_t config_pkt_stream[];
        packet_t const_pkt_stream [];
        `syellow;
        $display(
            "Test: Bringup. This test sends 14 config and 30 const packets to prime a PE for a useful program");
        `sclear;
        do_reset();

        config_pkt_stream = new[14];
        const_pkt_stream = new[7];

        // High Entropy Program :)
        config_pkt_stream = '{
            gen_config_pkt(4'(2), fu_op_add, 5'd1, 3'b000, pid_t'(15), 5'd15),
            gen_config_pkt(4'(3), fu_op_sll, 5'd2, 3'b001, pid_t'(2), 5'd16),
            gen_config_pkt(4'(4), fu_op_sra, 5'd3, 3'b010, pid_t'(3), 5'd17),
            gen_config_pkt(4'(5), fu_op_sub, 5'd4, 3'b011, pid_t'(4), 5'd18),
            gen_config_pkt(4'(6), fu_op_xor, 5'd5, 3'b000, pid_t'(5), 5'd19),
            gen_config_pkt(4'(7), fu_op_srl, 5'd7, 3'b000, pid_t'(6), 5'd20),
            gen_config_pkt(4'(8), fu_op_or, 5'd8, 3'b001, pid_t'(7), 5'd21),
            gen_config_pkt(4'(9), fu_op_and, 5'd9, 3'b000, pid_t'(8), 5'd22),
            gen_config_pkt(4'(10), fu_op_add, 5'd10, 3'b001, pid_t'(9), 5'd23),
            gen_config_pkt(4'(11), fu_op_sra, 5'd11, 3'b010, pid_t'(10), 5'd24),
            gen_config_pkt(4'(12), fu_op_sub, 5'd12, 3'b011, pid_t'(11), 5'd25),
            gen_config_pkt(4'(13), fu_op_xor, 5'd13, 3'b000, pid_t'(12), 5'd26),
            gen_config_pkt(4'(14), fu_op_srl, 5'd14, 3'b000, pid_t'(13), 5'd27),
            gen_config_pkt(4'(15), fu_op_or, 5'd15, 3'b001, pid_t'(14), 5'd28)
        };

        // Generate some useful constants (some may be overwritten without read)
        for (logic [5:0] i = 'd1; i < 'd8; i++) begin
            const_pkt_stream[i-'d1] = gen_const_pkt((5)'(i), (23)'('d2 * i));
        end

        send_array_pkt(config_pkt_stream, WEST);
        send_array_pkt(const_pkt_stream, WEST);
        repeat (10) @(posedge top_clk);

        `scyan;
        $display("Confirming Regfile Writes");
        `sclear;
        for (logic [5:0] i = 'd1; i < 'd8; i++) begin
            `sgreen;
            assert (u_pe_rf.data[0][5'(i)] == const_pkt_stream[5'(i-'d1)].payload.cnst.imm)
                $display("RF Entry %1d matches packet payload", i);
            else $fatal(1, "\033[38:5:172mAssert Failed, entry %d\033[0m", i);
            `sclear;
        end
        `scyan;
        $display("Confirming Pat Entry Writes");
        `sclear;
        for (logic [4:0] i = 'd2; i < 'd16; i++) begin
            `sgreen;
            assert (dut.u_pe_action_table.entries[i] == config_pkt_stream[i-2].payload.conf.pat_w_entry)
                $display("PAT Entry %1d matches packet payload", i);
            else $fatal(1, "\033[38:5:172mAssert Failed, entry %d.\033[0m", i);
            `sclear;
        end

        `sygre;
        $display("Test: Bringup PASSED");
        `sclear;
    endtask

    task automatic test_basic_traffic();
        `syellow;
        $display(
            "Test: Basic Traffic. Runs a bringup, then ensures packets leave the PE with correct data + direction");
        `sclear;
        do_reset();
        bringup();
        `scyan;
        $display("Bringup Complete.");
        `sclear;

        fork
            begin
                send_stream_pkt('{pid: 'd2, payload: 'hab}, NORTH);
                send_stream_pkt('{pid: 'd3, payload: 'hcd}, NORTH);
                send_stream_pkt('{pid: 'd4, payload: 'hef}, NORTH);
                send_stream_pkt('{pid: 'd5, payload: 'habcd}, NORTH);
                send_stream_pkt('{pid: 'd6, payload: 'hefef}, NORTH);
                send_stream_pkt('{pid: 'd7, payload: 'h1234}, NORTH);
                send_stream_pkt('{pid: 'd2, payload: 'h5678}, NORTH);
                send_stream_pkt('{pid: 'd3, payload: 'h1337_abcd}, NORTH);
                send_stream_pkt('{pid: 'd4, payload: 'habcd_efac}, NORTH);
                send_stream_pkt('{pid: 'd5, payload: 'habcd_efac}, NORTH);
                send_stream_pkt('{pid: 'd6, payload: 'habcd_efac}, NORTH);
                send_stream_pkt('{pid: 'd7, payload: 'habcd_efac}, NORTH);
                send_stream_pkt('{pid: 'd2, payload: 'habcd_efac}, NORTH);
                send_stream_pkt('{pid: 'd3, payload: 'habcd_efac}, NORTH);
                stop_stream(NORTH);
                repeat (10) @(posedge top_clk);
            end
            begin
                forever
                @(posedge top_clk) begin
                    for (int i = 0; i < 4; i++) begin
                        port_dir_t e;
                        e = port_dir_t'(i);
                        if (!egress_empty[i]) begin
                            egress_deq[i] = '1;
                            `scyan;
                            $write("Packet Dequed from side: ");

                            $write("%s", e.name);
                            $display(" with packet data %h", egress_rdata[i].payload.data);
                            `sclear;
                        end else begin
                            egress_deq[i] = '0;
                        end
                    end
                end
            end
        join_any
        disable fork;

        `sygre;
        $display("Test: Basic Traffic PASSED");
        `sclear;
    endtask

    task automatic test_stall();
        int pkt_ct = 0;
        `syellow;
        $display(
            "Test: Stall. Runs a bringup, Then sends a series of packets until the egress is forced to stall.");
        $display(
            "Part 1 uses a single operation to make sure all packets get sent out. Part 2 uses mixed operations to ensure that the regfile read data isn't clobbered on stall.");
        `sclear;
        do_reset();
        bringup();
        `scyan;
        $display("Bringup Complete.");
        `sclear;

        fork
            begin
                fork
                    send_pkt('{pid: 'd2, payload: 'h11}, NORTH);
                    send_pkt('{pid: 'd2, payload: 'h14}, WEST);
                    send_pkt('{pid: 'd2, payload: 'h1a}, SOUTH);
                    send_pkt('{pid: 'd2, payload: 'h4a}, EAST);
                join
                fork
                    send_pkt('{pid: 'd2, payload: 'h4b}, NORTH);
                    send_pkt('{pid: 'd2, payload: 'h4c}, WEST);
                    send_pkt('{pid: 'd2, payload: 'h9a}, SOUTH);
                    send_pkt('{pid: 'd2, payload: 'hab}, EAST);
                join
                // stop_stream(NORTH);
                repeat (35) @(posedge top_clk);
            end
            begin
                // j = 0;
                repeat (14) @(posedge top_clk);
                forever
                @(posedge top_clk) begin
                    for (int i = 0; i < 4; i++) begin
                        port_dir_t e;
                        e = port_dir_t'(i);
                        if (!egress_empty[i]) begin
                            egress_deq[i] = '1;
                            `scyan;
                            $write("Packet Dequed from side: ");

                            $write("%s", e.name);
                            $display(" with packet data %h", egress_rdata[i].payload.data);
                            `sclear;
                            pkt_ct = pkt_ct + 1;
                        end else begin
                            egress_deq[i] = '0;
                        end
                    end
                end
            end
        join_any
        disable fork;

        `syellow;
        assert (pkt_ct == 8)
        else $fatal(1, "Incorrect Number of packets recieved.\033[0m");
        `sclear;
        `sgreen;
        $display("Same PID Stall passed.");
        `sclear;
        // Forwarding/Difference Logic
        fork
            begin
                fork
                    send_pkt('{pid: 'd2, payload: 'h11}, NORTH);
                    send_pkt('{pid: 'd7, payload: 'h14}, WEST);
                    send_pkt('{pid: 'd6, payload: 'h1a}, SOUTH);
                    send_pkt('{pid: 'd2, payload: 'h4a}, EAST);
                join
                fork
                    send_pkt('{pid: 'd2, payload: 'h4b}, NORTH);
                    send_pkt('{pid: 'd7, payload: 'h4c}, WEST);
                    send_pkt('{pid: 'd6, payload: 'h9a}, SOUTH);
                    send_pkt('{pid: 'd7, payload: 'hab}, EAST);
                join
                // stop_stream(NORTH);
                repeat (35) @(posedge top_clk);
            end
            begin
                // j = 0;
                repeat (14) @(posedge top_clk);
                forever
                @(posedge top_clk) begin
                    for (int i = 0; i < 4; i++) begin
                        port_dir_t e;
                        e = port_dir_t'(i);
                        if (!egress_empty[i]) begin
                            egress_deq[i] = '1;
                            `scyan;
                            $write("Packet Dequed from side: ");

                            $write("%s", e.name);
                            $display(" with pid %1d, with packet data %h", egress_rdata[i].pid,
                                     egress_rdata[i].payload.data);
                            `sclear;
                            pkt_ct = pkt_ct + 1;
                        end else begin
                            egress_deq[i] = '0;
                        end
                    end
                end
            end
        join_any
        disable fork;

        // I verified the results manually but it if someone wants to write the asserts you would need to:
        // - write all the packets I sent into an array
        // - index that array by the result from the first 5 packets
        // - compare the constant with the op + const reg result
        // - repeat for next 5
        `sgreen;
        $display("Mixed RS source test passed.");
        `sclear;

        `sygre;
        $display("Test: Stall PASSED");
        `sclear;
    endtask

    int service_counters[4];
    task automatic test_mixed_traffic();

        `syellow;
        $display("Test: Mixed traffic. Runs a bringup, Then sends many packets on some ingresses.");
        $display(
            "The goal of this test is to ensure that no one ingress is starved for more than 5 cycles, rather than correctness.");
        `sclear;
        do_reset();
        bringup();
        `scyan;
        $display("Bringup Complete.");
        `sclear;

        fork
            begin
                repeat (20) begin
                    fork
                        send_pkt('{pid: 'd2, payload: 'h11}, NORTH);
                        send_pkt('{pid: 'd2, payload: 'h14}, WEST);
                        send_pkt('{pid: 'd2, payload: 'h1a}, SOUTH);
                        send_pkt('{pid: 'd2, payload: 'h4a}, EAST);
                    join
                    fork
                        send_pkt('{pid: 'd2, payload: 'h4b}, NORTH);
                        send_pkt('{pid: 'd2, payload: 'h4c}, WEST);
                        send_pkt('{pid: 'd2, payload: 'h9a}, SOUTH);
                        send_pkt('{pid: 'd2, payload: 'hab}, EAST);
                    join
                    fork
                        send_pkt('{pid: 'd2, payload: 'h4b}, NORTH);
                        send_pkt('{pid: 'd2, payload: 'h4c}, WEST);
                        send_pkt('{pid: 'd2, payload: 'h9a}, SOUTH);
                        send_pkt('{pid: 'd2, payload: 'hab}, EAST);
                    join
                    // stop_stream(NORTH);
                    repeat (10) @(posedge top_clk);
                end
            end
            begin
                forever
                @(posedge top_clk) begin
                    for (int i = 0; i < 4; i++) begin
                        port_dir_t e;
                        e = port_dir_t'(i);
                        if (!egress_empty[i]) begin
                            egress_deq[i] = '1;
                            // `scyan;
                            // $write("Packet Dequed from side: ");

                            // $write("%s", e.name);
                            // $display(" with packet data %h", egress_rdata[i].payload.data);
                            // `sclear;
                        end else begin
                            egress_deq[i] = '0;
                        end
                    end

                    for (int i = 0; i < 4; i++) begin
                        if (ingress_empty[i]) begin
                            service_counters[i] = 0;
                        end else begin
                            if (ingress_deq[i]) begin
                                service_counters[i] = 0;
                            end else begin
                                service_counters[i] += 1;
                            end
                        end
                    end

                    for (int i = 0; i < 4; i++) begin
                        assert (service_counters[i] < 5)
                        else $fatal(1, "Failed to service %p.", port_dir_t'(i));
                    end
                end
            end
        join_any
        disable fork;

        `sygre;
        $display("Test: Mixed Traffic PASSED");
        `sclear;
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
        for (int i = 0; i < 4; i++) begin
            ingress_enq[i] = '0;
            egress_deq[i]  = '0;
        end
        for (int i = 1; i < 4; i++) begin
            rf_we[i] = '0;
            rs[i] = '0;
            rd[i] = '0;
        end
    end

    // Make some driving FIFOs
    genvar ind;
    generate
        for (ind = 0; ind < 4; ind++) begin : gen_ingress_fifo
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




    pe #(
        .IS_MUL (0),
        .PORTS  (4),
        .X_COORD(2'b00),
        .Y_COORD(2'b00)
    ) dut (
        .clk          (top_clk),
        .rst          (rst),
        .ingress_empty(ingress_empty),
        .ingress_rdata(ingress_rdata),
        .ingress_deq  (ingress_deq),
        .egress_deq   (egress_deq),
        .egress_empty (egress_empty),
        .egress_rdata (egress_rdata),

        .rf_we(rf_we[0]),
        .rd   (rd[0]),
        .rd_v (rd_v[0]),
        .rs   (rs[0]),
        .rs_v (rs_v[0])
    );

    pe_rf u_pe_rf (
        .clk  (top_clk),
        .rf_we(rf_we),
        .rd   (rd),
        .rd_v (rd_v),
        .rs   (rs),
        .rs_v (rs_v)
    );

    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, "+all");
        repeat (2) @(posedge top_clk);
        rst = 1'b0;

        test_config_bypass();
        test_const_bypass();
        test_config_write();
        test_const_write();
        test_bringup();
        test_basic_traffic();
        test_stall();
        test_mixed_traffic();

        repeat (5) @(posedge top_clk);
        $finish();
    end

endmodule
