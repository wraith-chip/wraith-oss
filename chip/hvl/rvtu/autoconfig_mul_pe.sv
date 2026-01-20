module autoconfig_mul_pe
import pe_types::*;
(
  input               clk,
  input               rst,

  output logic        eg_empty,
  input logic         eg_deq,
  output logic [35:0] eg_pkt,

  input               ig_empty,
  output logic        ig_deq,
  input [35:0]        ig_pkt,

  output logic        init_done
);
  logic ingress_empty [5];
  packet_t ingress_rdata [5];
  logic ingress_deq [5];
  logic egress_deq [5];
  logic egress_empty [5];
  packet_t egress_rdata [5];

  //TB Ingress signals
  logic ingress_enq [5];
  packet_t ingress_wdata[5];
  logic ingress_full[5];

  task static send_pkt(input packet_t pkt, input port_dir_t dir);
    ingress_wdata[dir] <= pkt;
    ingress_enq[dir] <= '1;
    @(posedge clk);
    ingress_enq[dir] <= '0;
    @(posedge clk);
  endtask

  function automatic packet_t gen_config_pkt(
                                              input logic [3:0] pat_ind,
                                              input fu_func op,
                                              input rf_reg src,
                                              input egress_id dest,
                                              input pid_t response_pid,
                                              input rf_reg rd,
                                              input logic src_imm = '0,
                                              input logic rf_we = (|rd),
                                              input logic imm_we = '0
                                             );

    config_payload_t config_payload = '{padding: '0, x_coord: '0,
                                        y_coord: '0, pat_ind: pat_ind,
                                        pat_w_entry: '{ fu_op: op,
                                                        src: src,
                                                        dest: dest,
                                                        response_pid: response_pid,
                                                        rd: rd,
                                                        src_imm: src_imm,
                                                        rf_we: rf_we,
                                                        imm_we: imm_we }};

    return '{pid: '0, payload: config_payload};

  endfunction


  genvar ind;
  generate
    // modified to not generate the north ingress fifo, since the rvtu is providing that.
    for (ind = 1; ind < 5; ind++) begin : gen_ingress_fifo
      fifo #(.DEPTH(2), .WIDTH($bits(packet_t))) u_fifo (
                                                         .clk(clk),
                                                         .rst(rst),

                                                         .enqueue(ingress_enq[ind]),
                                                         .wdata(ingress_wdata[ind]),

                                                         .dequeue(ingress_deq[ind]),
                                                         .rdata(ingress_rdata[ind]),

                                                         .full(ingress_full[ind]),
                                                         .empty(ingress_empty[ind])
                                                         );
    end
  endgenerate

  logic         rf_we  [4];
  rf_reg        rd     [4];
  logic [31:0]  rd_v   [4];

  rf_reg        rs     [4];

  logic [31:0] rs_v   [4];


  pe #(
       .IS_MUL           (1),
       .PORTS            (5),
       .X_COORD          (2'b00),
       .Y_COORD          (2'b00)
       ) dut (
              .clk              (clk),
              .rst              (rst),
              .ingress_empty    (ingress_empty),
              .ingress_rdata    (ingress_rdata), // You would connect ingress_*[0] to the rvtu mul_eg
              .ingress_deq      (ingress_deq),
              .egress_deq       (egress_deq),
              .egress_empty     (egress_empty), // You would connect egress_*[0] to the rvtu mul_ing
              .egress_rdata     (egress_rdata),

              .rf_we            (rf_we[0]),
              .rd               (rd[0]),
              .rd_v             (rd_v[0]),
              .rs               (rs[0]),
              .rs_v             (rs_v[0])
              );

  pe_rf u_pe_rf (
                 .clk      (clk),
                 .rf_we    (rf_we),
                 .rd       (rd),
                 .rd_v     (rd_v),
                 .rs       (rs),
                 .rs_v     (rs_v)
                 );

  initial begin
    for (int i = 1; i < 5; i++) begin
      ingress_enq[i] = '0;
      egress_deq[i] = '0;
    end

    for (int i = 1; i < 4; i++) begin
      rf_we[i] = '0;
    end
  end

  assign eg_empty = egress_empty[0];
  assign egress_deq[0] = eg_deq;
  assign eg_pkt = egress_rdata[0];

  assign ingress_empty[0] = ig_empty;
  assign ig_deq = ingress_deq[0];
  assign ingress_rdata[0] = ig_pkt;

  initial begin
    init_done <= '0;
    @(posedge clk iff ~rst);

    send_pkt(gen_config_pkt(4'(11), fu_op_mul,     'd1,  3'b111, pid_t'(11), 5'd1, 'b1), EAST);
    send_pkt(gen_config_pkt(4'(12), fu_op_mul,     'd1, 3'b000, pid_t'(12), '0), EAST);
    send_pkt(gen_config_pkt(4'(13), fu_op_mul_h,   'd1, 3'b000, pid_t'(13), '0), EAST);
    send_pkt(gen_config_pkt(4'(14), fu_op_mul_hsu, 'd1, 3'b000, pid_t'(14), '0), EAST);
    send_pkt(gen_config_pkt(4'(15), fu_op_mul_hu,  'd1, 3'b000, pid_t'(15), '0), EAST);

    init_done <= '1;
    @(posedge clk);
  end
endmodule
