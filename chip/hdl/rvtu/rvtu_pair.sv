module rvtu_pair
  import rv_pkg::*;
  import pe_types::*;
#(
    parameter logic [31:0] pcs[2] = '{'h40000000, 'h80000000},
    parameter logic DEBUG = '0
) (
    input logic clk,
    input logic rst,

    input logic rvtu_rst_a,
    input logic rvtu_rst_b,
    // Mesh Side Signals
    output logic    mul_eg_empty[2],
    output packet_t mul_eg_rdata[2],
    // MEANING: 1 == PE mesh is taking in a multiply packet
    input  logic    mul_eg_deq  [2],

    input  logic    mul_ig_empty[2],
    input  packet_t mul_ig_rdata[2],
    // MEANING: I assign 1 when I am ready to dequeue a multiply result
    // that the mesh has computed for me.
    output logic    mul_ig_deq  [2],

    // MMMU Arb Side Signals
    rvtu_pair_arb_if.rvtu_pair arb_bus,

    // CSR exports
    output logic    halt [2]
);


  // Divider Signals
  logic a_div_req, b_div_req;
  logic [31:0] a_div_src1, a_div_src2, b_div_src1, b_div_src2;
  logic [1:0] a_div_fsel, b_div_fsel;
  logic a_div_resp, b_div_resp;
  logic [31:0] a_div_out, b_div_out;

  // Cache Signals
  logic [31:0] a_ufp_addr, b_ufp_addr;
  logic a_ufp_rmask, b_ufp_rmask;
  logic [3:0] a_ufp_wmask, b_ufp_wmask;
  logic [31:0] a_ufp_rdata, b_ufp_rdata;
  logic [31:0] a_ufp_wdata, b_ufp_wdata;
  logic a_ufp_resp, b_ufp_resp;

  // these are undriven potentially, which is fine. Just need it for debug.
  logic err[2];

  generate
    if (DEBUG) begin
      rvtu_harness #(
          .pc_init  (pcs[0]),
          .dumpfile ("rvtu0_commit.log")
      ) u_rvtu_a (
          .clk      (clk),
          .rst      (rst | rvtu_rst_a),

          .halt     (halt[0]),
          .err      (err[0]),

          // cache port
          .maddr    (a_ufp_addr),
          .mrd      (a_ufp_rmask),
          .mwr      (a_ufp_wmask),
          .mwdata   (a_ufp_wdata),
          .mresp    (a_ufp_resp),
          .mrdata   (a_ufp_rdata),
          // mul egress port
          .eg_empty (mul_eg_empty[0]),
          .eg_deq   (mul_eg_deq[0]),
          .eg_pkt   (mul_eg_rdata[0]),
          // mul ingress port
          .ig_empty (mul_ig_empty[0]),
          .ig_deq   (mul_ig_deq[0]),
          .ig_pkt   (mul_ig_rdata[0]),
          // div arbiter port
          .div_req  (a_div_req),
          .div_src1 (a_div_src1),
          .div_src2 (a_div_src2),
          .div_fsel (a_div_fsel),
          .div_resp (a_div_resp),
          .div_out  (a_div_out)
      );

      rvtu_harness #(
          .pc_init  (pcs[1]),
          .dumpfile ("rvtu1_commit.log")
      ) u_rvtu_b (
          .clk      (clk),
          .rst      (rst | rvtu_rst_b),

          .halt     (halt[1]),
          .err      (err[1]),

          // cache port
          .maddr    (b_ufp_addr),
          .mrd      (b_ufp_rmask),
          .mwr      (b_ufp_wmask),
          .mwdata   (b_ufp_wdata),
          .mresp    (b_ufp_resp),
          .mrdata   (b_ufp_rdata),
          // mul egress port
          .eg_empty (mul_eg_empty[1]),
          .eg_deq   (mul_eg_deq[1]),
          .eg_pkt   (mul_eg_rdata[1]),
          // mul ingress port
          .ig_empty (mul_ig_empty[1]),
          .ig_deq   (mul_ig_deq[1]),
          .ig_pkt   (mul_ig_rdata[1]),
          // div arbiter port
          .div_req  (b_div_req),
          .div_src1 (b_div_src1),
          .div_src2 (b_div_src2),
          .div_fsel (b_div_fsel),
          .div_resp (b_div_resp),
          .div_out  (b_div_out)
      );
    end else begin
      rvtu #(
          .pc_init(pcs[0])
      ) u_rvtu_a (
          .clk(clk),
          .rst(rst | rvtu_rst_a),

          // cache port
          .maddr   (a_ufp_addr),
          .mrd     (a_ufp_rmask),
          .mwr     (a_ufp_wmask),
          .mwdata  (a_ufp_wdata),
          .mresp   (a_ufp_resp),
          .mrdata  (a_ufp_rdata),
          // mul egress port
          .eg_empty(mul_eg_empty[0]),
          .eg_deq  (mul_eg_deq[0]),
          .eg_pkt  (mul_eg_rdata[0]),
          // mul ingress port
          .ig_empty(mul_ig_empty[0]),
          .ig_deq  (mul_ig_deq[0]),
          .ig_pkt  (mul_ig_rdata[0]),
          // div arbiter port
          .div_req (a_div_req),
          .div_src1(a_div_src1),
          .div_src2(a_div_src2),
          .div_fsel(a_div_fsel),
          .div_resp(a_div_resp),
          .div_out (a_div_out),

          .halt     (halt[0])
      );

      rvtu #(
          .pc_init(pcs[1])
      ) u_rvtu_b (
          .clk(clk),
          .rst(rst | rvtu_rst_b),

          // cache port
          .maddr   (b_ufp_addr),
          .mrd     (b_ufp_rmask),
          .mwr     (b_ufp_wmask),
          .mwdata  (b_ufp_wdata),
          .mresp   (b_ufp_resp),
          .mrdata  (b_ufp_rdata),
          // mul egress port
          .eg_empty(mul_eg_empty[1]),
          .eg_deq  (mul_eg_deq[1]),
          .eg_pkt  (mul_eg_rdata[1]),
          // mul ingress port
          .ig_empty(mul_ig_empty[1]),
          .ig_deq  (mul_ig_deq[1]),
          .ig_pkt  (mul_ig_rdata[1]),
          // div arbiter port
          .div_req (b_div_req),
          .div_src1(b_div_src1),
          .div_src2(b_div_src2),
          .div_fsel(b_div_fsel),
          .div_resp(b_div_resp),
          .div_out (b_div_out),

          .halt     (halt[1])
      );
    end
  endgenerate


  // Divider Arb
  rvtu_div_arb u_rvtu_div_arb (
      .clk(clk),
      .rst(rst),

      .a_req (a_div_req),
      .a_src1(a_div_src1),
      .a_src2(a_div_src2),
      .a_fsel(a_div_fsel),
      .a_resp(a_div_resp),
      .a_out (a_div_out),

      .b_req (b_div_req),
      .b_src1(b_div_src1),
      .b_src2(b_div_src2),
      .b_fsel(b_div_fsel),
      .b_resp(b_div_resp),
      .b_out (b_div_out)
  );

  logic dfp_read[2], dfp_write[2], dfp_resp[2];
  logic [31:0] dfp_addr[2];
  logic [127:0] dfp_rdata[2], dfp_wdata[2];

  rvtu_cache a_rvtu_cache (
      .clk(clk),
      .rst(rst),

      .ufp_addr (a_ufp_addr),
      .ufp_rmask(a_ufp_rmask),
      .ufp_wmask(a_ufp_wmask),
      .ufp_rdata(a_ufp_rdata),
      .ufp_wdata(a_ufp_wdata),
      .ufp_resp (a_ufp_resp),

      .dfp_read (dfp_read[0]),
      .dfp_addr (dfp_addr[0]),
      .dfp_write(dfp_write[0]),
      .dfp_rdata(dfp_rdata[0]),
      .dfp_wdata(dfp_wdata[0]),
      .dfp_resp (dfp_resp[0])
  );

  rvtu_cache b_rvtu_cache (
      .clk(clk),
      .rst(rst),

      .ufp_addr (b_ufp_addr),
      .ufp_rmask(b_ufp_rmask),
      .ufp_wmask(b_ufp_wmask),
      .ufp_rdata(b_ufp_rdata),
      .ufp_wdata(b_ufp_wdata),
      .ufp_resp (b_ufp_resp),

      .dfp_read (dfp_read[1]),
      .dfp_addr (dfp_addr[1]),
      .dfp_write(dfp_write[1]),
      .dfp_rdata(dfp_rdata[1]),
      .dfp_wdata(dfp_wdata[1]),
      .dfp_resp (dfp_resp[1])
  );

  rvtu_arb_adapter serde (
    .clk,
    .rst,

    .c_read (dfp_read),
    .c_addr (dfp_addr),
    .c_write(dfp_write),
    .c_rdata(dfp_rdata),
    .c_wdata(dfp_wdata),
    .c_resp (dfp_resp),

    .arb_bus
  );
endmodule : rvtu_pair
