// Owner: Prakhar, Ingi
// This module basically arbit access to the MMMU's inout dbus
// between the SPM and RVTUs (RVTU Pairs, actually)

// The arbiter is also responsible for "formatting"
// the requests going to the bridge.


module mmmu_arb
  import mmmu_types::*;
#(
    parameter integer unsigned NUM_RVTUS = 2,
    parameter integer unsigned BRIDGE_WIDTH = 32
) (
    input logic clk,
    input logic rst,

    scratchpad_controller_if.mmmu_arb spm,
    rvtu_pair_arb_if.mmmu_arb rvtu,

    input logic [BRIDGE_WIDTH-1:0] recv_data,  // received data from the MMMU BRIDGE
    input logic recv_data_vld,  // received data is valid (in "passenger" state)
    // bridge can handle us)
    input logic bridge_ack,
    // bridge finished handling our request
    input logic bridge_fin,
    // type of current transaction on the bridge
    input dbus_meta_t bridge_type,

    output logic                    arb_vld,
    output logic [BRIDGE_WIDTH-1:0] arb_pkt
);

  logic [1:0] mem_req_vlds_i, mem_acks_o;

  // Which banks have active read requests. Bit zero is never asserted.
  logic [1:0] mem_reads_i;
  logic [1:0] dormant_banks, dormant_banks_next;

  // This vector is either all zeroes or onehot, and indicates which bank is ACTIVE. An ACTIVE
  // bank is one whose data this module translates and then passes along via the I/O bus.
  //
  // In the event that active_bank is all zeros, the input `mem_req_vld` should be "checked".
  // The cycle after a bit in active_bank_next is asserted, the MMMU ARBITRATOR should signal (through the MMMU BRIDGE)
  // that WRAITH has a request to services.
  //
  // An ACK is sent to the bank originating the request once the bridge sends BRIDGE_ACK, saying that it's ok
  // for the on-chip to use the bus now.
  //
  // `active_bank` should then stay effectively-latched, until the full relevant contents have been transmitted
  // on behalf of the bank.
  // Due to the cooperative nature of the memory system, no FIN signal needs to be sent to the SPM/RVTU.
  logic [1:0] active_bank, active_bank_next;

  // The on-chip holds bridge priority, and thus the arb should be supplying addr/data, not handshake data.
  logic own_bridge_reg;
  logic read_request_reg;

  // The data, propagated from on-chip source, to send
  logic [BRIDGE_WIDTH-1:0] onchip_wdata;

  // The request, driven ~> DATA BUS
  // This is only sent on cycles without bus control
  logic [BRIDGE_WIDTH-1:0] try_handshake_bus_wdata;
  dbus_pkt_cyc0_t handshake_pkt;
  assign try_handshake_bus_wdata = handshake_pkt;
  // If there is no onchip request, send a "no request" frame
  dbus_pkt_cyc0_t no_request_pkt;

  typedef struct packed {
    logic spm;   // 1 if ScratchpadController, 0 if RVTU
    logic read;  // 1 if read, 0 if write
  } active_bank_meta_t;
  active_bank_meta_t active_bank_meta, active_bank_meta_next;

  // Determine if memory requests are valid
  assign mem_req_vlds_i[0] = spm.req_out;
  assign mem_req_vlds_i[1] = rvtu.dfp_read | rvtu.dfp_write;

  // Assign read signals
  assign mem_reads_i[0] = 1'b0;
  assign mem_reads_i[1] = rvtu.dfp_read;

  always_comb begin
    active_bank_next = active_bank;
    active_bank_meta_next = active_bank_meta;

    for (integer unsigned i = 0; i < 2; i++) begin : for_update_active_bank_next
      // Only allow a read request if there's nothing outstanding
      // Only allow any kind of request if not already handling one)
      if (~|active_bank && !(|dormant_banks && mem_reads_i[i]) && mem_req_vlds_i[i]) begin
        // just because we are setting active_bank_next does not mean that we should ACK that bank yet
        // That should happen only once we've received the bridge_ack signal
        active_bank_next[i] = 1'b1;
        active_bank_meta_next.spm = (i == 0);
        active_bank_meta_next.read = mem_reads_i[i];
        break;
      end
    end

    if (bridge_fin & own_bridge_reg) active_bank_next = '0;
  end

  // The bridge just finished response to one of our outstanding read requests
  logic cacheline_read_responding;
  assign cacheline_read_responding = bridge_type == cacheline_rd_resp;

  logic last_cycle_fin_read_resp;
  always_ff @(posedge clk) begin
    if (rst) begin
      last_cycle_fin_read_resp <= '0;
    end else begin
      last_cycle_fin_read_resp <= bridge_fin && cacheline_read_responding;
    end
  end

  always_comb begin
    // We never need to calculate this, because the SPM does not issue read requests.
    dormant_banks_next[0] = 1'b0;

    dormant_banks_next[1] = (dormant_banks[1] && !last_cycle_fin_read_resp)
      | (active_bank[1] & bridge_fin & own_bridge_reg & read_request_reg);
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      dormant_banks <= '0;
      active_bank <= '0;
      active_bank_meta <= '{default: '0};
    end else begin
      dormant_banks    <= dormant_banks_next;
      active_bank      <= active_bank_next;
      active_bank_meta <= active_bank_meta_next;
    end
  end
  // Logic to decide when ARB own bus
  always_ff @(posedge clk) begin
    if (rst) begin
      own_bridge_reg   <= '0;
      read_request_reg <= '0;
    end else begin
      if (bridge_ack) begin
        own_bridge_reg   <= 1'b1;
        read_request_reg <= |(active_bank_next & mem_reads_i);
      end
      // If we were driving bridge and receive fin, then now, we do not own bridge
      if (bridge_fin & own_bridge_reg) begin
        own_bridge_reg   <= 1'b0;
        read_request_reg <= 1'b0;
      end
    end
  end

  // Assign mem_acks, with some extra care given to be sure that we NEVER
  // ack more than one internal block.
  always_comb begin
    mem_acks_o = '0;
    for (integer unsigned i = 0; i < 2; i++) begin
      if (active_bank[i]) begin
        mem_acks_o[i] = bridge_ack;
        break;
      end
    end
  end

  // ACK devices, tell them they have bus ctrl
  assign spm.bus_own_ack = mem_acks_o[0];
  assign rvtu.dfp_ack    = mem_acks_o[1];

  always_comb begin
    onchip_wdata = 'x;

    if (active_bank[0]) begin
      onchip_wdata = spm.dbus_out;
    end else if (active_bank[1]) begin
      onchip_wdata = rvtu.dfp_wdata;
    end
  end

  always_comb begin : drive_handshake_pkt
    handshake_pkt = 32'h0;
    handshake_pkt.on_chip_req = |active_bank;

    if (active_bank_meta.spm) begin
      handshake_pkt.on_chip_meta = SPMLEN_spm_wb;
    end else begin
      handshake_pkt.on_chip_meta = (active_bank_meta.read) ? cacheline_rd_req : cacheline_wb;
    end
  end

  assign no_request_pkt = '0;

  // One cycle delayed bridge_fin
  logic bridge_fin_r;
  always_ff @(posedge clk) begin
    if (rst) bridge_fin_r <= 1'b0;
    else bridge_fin_r <= bridge_fin;
  end

  logic recv_spm_data;
  assign recv_spm_data = (bridge_type == SPMLEN_spm_write);

  assign spm.req_in = recv_data_vld & recv_spm_data;
  assign rvtu.dfp_rdata_valid = recv_data_vld & cacheline_read_responding;

  assign spm.dbus_in = ~recv_spm_data ? 'x : recv_data;
  assign rvtu.dfp_rdata = ~dormant_banks[1] ? 'x : recv_data;

  // We need to tag the correct request type here,
  // that is, if active_bank is not garbage, we place the correct `cyc0_t`
  // information into arb_out corresponding to the kind of memory request
  // we've set as the one we want to perform (by asserting its bit in active_bank)
  assign arb_vld = |active_bank;
  assign arb_pkt = ((own_bridge_reg) ? onchip_wdata : try_handshake_bus_wdata);
endmodule
