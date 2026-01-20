//  SPDX-License-Identifier: MIT
//  rvtu_cacheline_adapter.sv — RVTU-to-M3U Arb Cacheline Adapter
//  Owner: Pradyun Narkadamilli

module rvtu_arb_adapter #(
    localparam integer unsigned CL_W    = 128,
    localparam integer unsigned ARB_W   = 32,
    localparam integer unsigned BURSTS  = CL_W / ARB_W,
    localparam integer unsigned BURST_W = $clog2(BURSTS)
) (
    input logic clk,
    input logic rst,

    input  logic [ 31:0] c_addr[2],
    input  logic         c_read[2],
    input  logic         c_write[2],
    output logic [127:0] c_rdata[2],
    input  logic [127:0] c_wdata[2],
    output logic         c_resp[2],

    rvtu_pair_arb_if.rvtu_pair arb_bus
);
  // arbiter state
  logic owner, owner_b, owner_en;
  logic active, active_read, active_write;
  logic [31:0] owner_addr;
  logic [127:0] owner_wdata;

  // serializer state
  logic arb_read_b, arb_write_b, arb_read_en, arb_write_en;

  logic state_en;
  enum logic [1:0] {
    REQ,
    RDADDR,
    RDBUF,
    WRBUF
  } state, state_b;

  logic ackflag, ackflag_b, ackflag_en;
  logic burst_ctr_en;
  logic [BURST_W-1:0] burst_ctr, burst_ctr_b;

  logic             arb_wdata_en;
  logic [ARB_W-1:0] arb_wdata_b;

  logic             resp, resp_b;
  logic [128:0]     rdata;

  logic             dfp_resp;
  assign dfp_resp = (state == RDBUF) & arb_bus.dfp_rdata_valid;

  // arbiter
  assign owner_b = ~rst & ~owner;
  assign owner_en = rst | resp | (owner ^ active);
  always_ff @(posedge clk) if (owner_en) owner <= owner_b;

  assign active = owner ^ (~c_read[owner] & ~c_write[owner]) & (c_read[~owner] | c_write[~owner]);
  assign active_read  = c_read[active];
  assign active_write = c_write[active];

  assign owner_addr  = c_addr[owner];
  assign owner_wdata = c_wdata[owner];

  assign c_resp[0] = ~owner & resp;
  assign c_resp[1] = owner & resp;

  assign c_rdata = '{default: rdata};

  always_ff @(posedge clk) begin
    if (rst)
      state <= REQ;
    else begin
      case (state)
        REQ: if (arb_bus.dfp_ack) state <= arb_bus.dfp_read ? RDADDR : WRBUF;
        RDADDR: if (arb_bus.dfp_rdata_valid) state <= RDBUF;
        RDBUF: if (&burst_ctr) state <= REQ;
        WRBUF: if (&burst_ctr) state <= REQ;
      endcase
    end
  end

  assign arb_read_en = rst | arb_bus.dfp_ack | ~arb_bus.dfp_read;
  assign arb_read_b  = ~rst & ~arb_bus.dfp_ack & ~resp & active_read & (state == REQ);
  always_ff @(posedge clk) if (arb_read_en) arb_bus.dfp_read <= arb_read_b;

  assign arb_write_en = rst | arb_bus.dfp_ack | ~arb_bus.dfp_write;
  assign arb_write_b  = ~rst & ~arb_bus.dfp_ack & ~resp & active_write & (state == REQ);
  always_ff @(posedge clk) if (arb_write_en) arb_bus.dfp_write <= arb_write_b;

  assign ackflag_en = rst | arb_bus.dfp_ack | (&burst_ctr);
  assign ackflag_b  = ~rst & arb_bus.dfp_ack & arb_bus.dfp_write;
  always_ff @(posedge clk) if (ackflag_en) ackflag <= ackflag_b;

  assign burst_ctr_en = rst | dfp_resp | ackflag;
  assign burst_ctr_b  = rst ? '0 : burst_ctr + 'd1;
  always_ff @(posedge clk) if (burst_ctr_en) burst_ctr <= burst_ctr_b;

  assign arb_wdata_en = ackflag | arb_bus.dfp_ack;
  assign arb_wdata_b  = (state == REQ) ? owner_addr : owner_wdata[ARB_W*burst_ctr+:ARB_W];
  always_ff @(posedge clk) if (arb_wdata_en) arb_bus.dfp_wdata <= arb_wdata_b;

  always_ff @(posedge clk) if (dfp_resp) rdata[ARB_W*burst_ctr+:ARB_W] <= arb_bus.dfp_rdata;

  assign resp_b = ~rst & (&burst_ctr);
  always_ff @(posedge clk) resp <= resp_b;
endmodule
