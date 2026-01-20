module pe_mesh_tb;
    timeunit 1ps; timeprecision 1ps;
    import pe_types::*;
    logic top_clk;
    logic rst;

    localparam int SIDES = 8;

    // Mesh Dequeuing Signal to recv packets
    logic    mesh_in_deq   [8];

    // Mesh FIFO Broadcasting
    logic    mesh_out_empty[8];
    packet_t mesh_out_rdata[8];

    // Mesh Dequeuing SIgnal to recv packets
    logic    smem_in_deq   [4];

    // Mesh FIFO Broadcasting
    logic    smem_out_empty[4];
    packet_t smem_out_rdata[4];

    //TB Inputs

    // TB FIFO Broadcasting
    logic    mesh_in_empty [8];
    packet_t mesh_in_rdata [8];
    // TB to pull out from mesh
    logic    mesh_out_deq  [8];

    // SMEM+TB Fifo Broadcasting
    logic    smem_in_empty [4];
    packet_t smem_in_rdata [4];

    // TB to pull out from mesh
    logic    smem_out_deq  [4];



    // Local TB Signals
    logic mesh_in_full [8];
    packet_t mesh_in_wdata [8];
    logic mesh_in_enq [8];


    logic smem_in_full [4];
    packet_t smem_in_wdata [4];
    logic smem_in_enq [4];


    // function automatic packet_t gen_config_pkt(input logic [3:0] pat_ind, input fu_func op,
    //                                            input prf_reg src, input egress_id dest,
    //                                            input pid_t response_pid, input prf_reg rd);

    //     config_payload_t config_payload = '{
    //         padding: '0,
    //         x_coord: '0,
    //         y_coord: '0,
    //         pat_ind: pat_ind,
    //         pat_w_entry: '{
    //             fu_op: op,
    //             src: src,
    //             dest: dest,
    //             response_pid: response_pid,
    //             rd: rd
    //         }
    //     };

    //     return '{pid: '0, payload: config_payload};

    // endfunction

    task automatic send_packet_stream(input packet_t pkts[]);
        smem_in_enq[0] <= '1;
        foreach (pkts[i]) begin
            if ($isunknown(pkts[i])) begin
                break;
            end
            smem_in_wdata[0] <= pkts[i];
            @(posedge top_clk);
        end
        smem_in_enq[0] <= '0;
        @(posedge top_clk);
    endtask
    int clock_half_period_ps;
    longint timeout;
    initial begin
        clock_half_period_ps = 200;
        timeout = 1000000;
    end

    task automatic send_pkt(input packet_t pkt);
        smem_in_wdata[0] <= pkt;
        smem_in_enq[0]   <= '1;
        @(posedge top_clk);
        smem_in_enq[0] <= '0;
        @(posedge top_clk);
    endtask

    initial top_clk = 1'b0;
    always #(clock_half_period_ps) top_clk = ~top_clk;

    initial rst = 1'b1;

    genvar ind;
    generate
        for (ind = 0; ind < SIDES; ind++) begin : gen_ingress_fifo
            fifo #(
                .DEPTH(2),
                .WIDTH($bits(packet_t))
            ) u_fifo (
                .clk(top_clk),
                .rst(rst),

                .enqueue(mesh_in_enq[ind]),
                .wdata  (mesh_in_wdata[ind]),

                .dequeue(mesh_in_deq[ind]),
                .rdata  (mesh_in_rdata[ind]),

                .full (mesh_in_full[ind]),
                .empty(mesh_in_empty[ind])
            );
        end
    endgenerate

    genvar indb;
    generate
        for (indb = 0; indb < 4; indb++) begin : gen_smem_fifo
            fifo #(
                .DEPTH(2),
                .WIDTH($bits(packet_t))
            ) u_fifo (
                .clk(top_clk),
                .rst(rst),

                .enqueue(smem_in_enq[indb]),
                .wdata  (smem_in_wdata[indb]),

                .dequeue(smem_in_deq[indb]),
                .rdata  (smem_in_rdata[indb]),

                .full (smem_in_full[indb]),
                .empty(smem_in_empty[indb])
            );
        end
    endgenerate


    // Initialize all the fifos
    initial begin
        for (int i = 0; i < 4; i++) begin
            smem_in_enq[i]  = '0;
            smem_out_deq[i] = '0;
        end
        for (int i = 0; i < 8; i++) begin
            mesh_in_enq[i]  = '0;
            mesh_out_deq[i] = '0;
        end
    end

    pe_mesh u_pe_mesh (
        .clk           (top_clk),
        .rst           (rst),
        .mesh_in_deq   (mesh_in_deq),
        .mesh_in_empty (mesh_in_empty),
        .mesh_in_rdata (mesh_in_rdata),
        .mesh_out_deq  (mesh_out_deq),
        .mesh_out_empty(mesh_out_empty),
        .mesh_out_rdata(mesh_out_rdata),
        .smem_in_deq   (smem_in_deq),
        .smem_in_empty (smem_in_empty),
        .smem_in_rdata (smem_in_rdata),
        .smem_out_deq  (smem_out_deq),
        .smem_out_empty(smem_out_empty),
        .smem_out_rdata(smem_out_rdata)
    );

    packet_t packet_stream[512];
    initial begin

        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, "+all");
        $readmemh("../pe_mesh_testcases/right_snake.hex", packet_stream);
        // $display("%p", packet_stream);
        repeat (2) @(posedge top_clk);
        rst = 1'b0;

        send_packet_stream(packet_stream);
        repeat (30) @(posedge top_clk);
        send_pkt('{pid: 'd2, payload: 'hab0});
        repeat (90) @(posedge top_clk);
        $finish();
    end

endmodule
