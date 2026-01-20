/*  The Processing Element (PE) holds the following modules:

    - The Arbiter to handle ingress packets
    - The Action Table to get context + data
    - A local Regfile
    - A functional unit

    The PE is connected to other PEs via an interface which *may* hold a FIFO. Each PE can have up to 6 connections:

    - N,S,E,W (4)
    - Diagonal (1)
    - RISC-V Regfile (1)

    We are only using 5 connections : in the format- '{north, west, south, diag, east}

*/

module pe
    import pe_types::*;
#(
    parameter int IS_MUL = 0,
    parameter int PORTS = 4,
    parameter logic [1:0] X_COORD = 2'b00,
    parameter logic [1:0] Y_COORD = 2'b00
) (
    input logic clk,
    input logic rst,

    input logic ingress_empty [PORTS],
    input packet_t ingress_rdata [PORTS],
    output logic ingress_deq   [PORTS],

    input  logic egress_deq   [PORTS],
    output logic egress_empty [PORTS],
    output packet_t egress_rdata [PORTS],

    // Shared Regfile
    output logic rf_we,
    output rf_reg rd,
    output logic [31:0] rd_v,
    output rf_reg rs,

    input logic [31:0] rs_v

);
    typedef struct packed {
        logic valid;
        action_table_entry_t pat_ent;
        logic [31:0] dat;
        logic        bypass;
    } pe_stage_t;

    // Global Stall Signal
    logic                       stall;

    // Internal wires for egress fifo
    logic                       egress_enq             [PORTS];
    packet_t                    egress_wdata           [PORTS];
    logic                       egress_full            [PORTS];

    // Stage 1: Arbiter Select:

    port_dir_t                  ingress_selector;
    logic                       ingress_valid;

    // Stage 2: Produced Packet + PAT
    packet_t                    ingress_pkt;

    // PE Action Table Index + Output
    pid_t                       pat_pid;
    action_table_entry_t        pat_entry;

    // PE Action Table Writing
    logic                       pat_write;
    action_table_entry_t        pat_w_entry;

    // Bypass Logic
    logic                       xmatch, ymatch;
    action_table_entry_t        spoofed_pat;

    logic                [ 2:0] pat_stage_bypass;
    action_table_entry_t        ex_stage_out_pat_entry;

    // Stage 3: Functional Unit + PRF Writeback
    pe_stage_t                  pat_stage_comb;
    pe_stage_t                  ex_stage;

    // FU Input
    logic                [31:0] rs_data;
    // FU Output
    logic                [31:0] fu_data;
    // Bypass or FU Output
    logic                [31:0] fu_stage_out_data;


    //Stage 4: Egress Writeout
    pe_stage_t                  egress_stage;
    /////////////////////////////////////////////////

    // Generate all of our egress FIFOs.
    genvar ind;
    generate
        for (ind = 0; ind < PORTS; ind++) begin : gen_PE_FIFOs
            fifo #(
                .DEPTH(1),
                .WIDTH($bits(packet_t))
            ) egress_fifo (
                .clk(clk),
                .rst(rst),

                .enqueue(egress_enq[ind]),
                .wdata  (egress_wdata[ind]),

                .dequeue(egress_deq[ind]),
                .rdata  (egress_rdata[ind]),

                .full (egress_full[ind]),
                .empty(egress_empty[ind])
            );
        end
    endgenerate

    // START OF STAGE 1
    pe_packet_arb #(
        .PORTS(PORTS)
    ) u_pe_packet_arb (
        .clk       (clk),
        .rst       (rst),
        .fifo_empty(ingress_empty),
        .stall     (stall),
        .selector  (ingress_selector),
        .valid     (ingress_valid)
    );

    always_comb begin
      ingress_deq = '{default: '0};
      ingress_deq[ingress_selector] = ~stall & ingress_valid;
      ingress_pkt = ingress_rdata[ingress_selector];
    end

    // START OF STAGE 2 (with the output of ingress_pkt and pkt_valid)
    assign xmatch     = ingress_pkt.payload.conf.x_coord == X_COORD;
    assign ymatch     = ingress_pkt.payload.conf.y_coord == Y_COORD;

    assign pat_write   = (ingress_valid) & (ingress_pkt.pid == '0) & xmatch & ymatch;

    assign spoofed_pat = '{
        default: '0,
        dest: xmatch ? (ymatch ? egress_id'(SINK) : egress_id'(SOUTH)) : egress_id'(EAST),
        response_pid: ingress_pkt.pid,
        rf_we: xmatch & ymatch & (ingress_pkt.pid == 'd1),
        rd: ingress_pkt.payload.cnst.rd
    };

    assign pat_w_entry = ingress_pkt.payload.conf.pat_w_entry;
    assign pat_pid = (pat_write) ? ingress_pkt.payload.conf.pat_ind : ingress_pkt.pid;

    pe_action_table u_pe_action_table (
        .clk     (clk),
        .write_en(pat_write),
        .w_entry (pat_w_entry),
        .pid     (pat_pid),
        .entry   (pat_entry)
    );

    assign ex_stage_out_pat_entry = (ingress_pkt.pid[PID_BITS-1:1] == '0) ? spoofed_pat : pat_entry;

    // If we write this config packet, then we don't let it go on.
    assign pat_stage_comb = '{
        valid: ingress_valid & !pat_write,
        pat_ent: ex_stage_out_pat_entry,
        dat: ingress_pkt.payload.data,
        bypass: (ingress_pkt.pid[PID_BITS-1:1] == '0)
    };

    // This regfile is now 1 cycle response, indexed equally with the stage reg
    const_payload_t exstage_config_dat;
    assign exstage_config_dat = const_payload_t'(ex_stage.dat);

    assign rf_we = ex_stage.valid & !stall & ex_stage.pat_ent.rf_we;
    assign rd    = ex_stage.pat_ent.rd;
    assign rd_v  = (ex_stage.bypass) ?
                   {{9{exstage_config_dat.imm[22]}},exstage_config_dat.imm} :
                   (ex_stage.pat_ent.imm_we ? ex_stage.dat : fu_data);
    assign rs    = (stall) ? ex_stage.pat_ent.src : pat_entry.src;

    // assign rs_data = rs_v;
    assign rs_data = rs_v;

    always_ff @(posedge clk) begin
        if (rst) begin
            ex_stage <= '{valid: '0, default: 'x};
        end else begin
            if (!stall) begin
                ex_stage <= pat_stage_comb;
            end
        end
    end

    // Generate the functional unit according to the parameter.
    logic forward, skid_vld;
    rf_reg skid_rd;
    logic [31:0] skid_val, src_ext;

    assign src_ext = {{27{ex_stage.pat_ent.src[4]}}, ex_stage.pat_ent.src};

    pe_fu #(
        .IS_MUL(IS_MUL)
    ) func_unit (
        .a (ex_stage.dat),
        .b (ex_stage.pat_ent.src_imm ? src_ext :
            forward ? skid_val : rs_data),
        .op(ex_stage.pat_ent.fu_op),
        .f (fu_data)
    );

    assign forward = skid_vld & (ex_stage.pat_ent.src == skid_rd);
    assign fu_stage_out_data = (ex_stage.bypass) ? ex_stage.dat : fu_data;

    assign egress_stage = '{
            valid: ex_stage.valid,
            pat_ent: ex_stage.pat_ent,
            dat: fu_stage_out_data,
            bypass: ex_stage.bypass
        };

    // skid buffer for forwarding
    always_ff @(posedge clk) begin
      if (rst) begin
        skid_vld <= '0;
      end else if (!stall) begin
        skid_vld <= egress_stage.valid & egress_stage.pat_ent.rf_we;

        if (egress_stage.valid) begin
          skid_rd  <= egress_stage.pat_ent.rd;
          skid_val <= rd_v;
        end
      end
    end

    port_dir_t eg_dir;
    logic eg_valid;

    assign eg_dir   = port_dir_t'(ex_stage.pat_ent.dest);
    assign eg_valid = eg_dir != SINK & ex_stage.valid;

    // Just assign the write data to all the output (egress) fifos
    assign egress_wdata = '{PORTS{'{pid: ex_stage.pat_ent.response_pid,
                                    payload: fu_stage_out_data}}};

    always_comb begin
        for (int i = 0; i < PORTS; i++) begin
            egress_enq[i] = '0;
        end

        egress_enq[eg_dir] = eg_valid & !egress_full[eg_dir];
    end

    assign stall = (eg_valid & egress_full[eg_dir]);
endmodule
