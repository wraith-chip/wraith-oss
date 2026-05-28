//  SPDX-License-Identifier: MIT
//  bridge.sv — Husk's bridge master to control WRAITH
//  Copyright (c) 2026 Pradyun Narkadamilli

import bridge_types::*;

module bridge (
  // Fabric/Dbus signals
  input                fabric_clk,
  input                fabric_rst,

  output logic [31:0]  dbus_dir,
  input [31:0]         dbus_i,
  output logic [31:0]  dbus_o,

  output logic         wraith_rst,
  output logic         rvtu_0_rst,
  output logic         rvtu_1_rst,

  output logic         spm_en,
  output logic [8:0]   spm_addr,
  output logic         spm_we,
  output logic [31:0]  spm_wdata,

  input [31:0]         spm_rdata,

  output logic         uram0_en,
  output logic [31:0]  uram0_addr,
  output logic         uram0_we,
  output logic [127:0] uram0_wdata,

  input [127:0]        uram0_rdata,

  output logic         uram1_en,
  output logic [31:0]  uram1_addr,
  output logic         uram1_we,
  output logic [127:0] uram1_wdata,

  input [127:0]        uram1_rdata,

  // AXI bus signals (post-adapter)
  input                axi_clk,
  input                axi_rst_n, // active LOW!!

  input [5:0]          axi_addr,  // bottom two bits *should* be 0
  // These are level signals indicating that the cache needs to take in rd/wr from axi-side
  input                axi_rd,
  input                axi_wr,
  input [3:0]          axi_wmask,
  input [31:0]         axi_wdata,

  output logic         axi_resp,
  output logic [31:0]  axi_rdata
);
  // AXI request signals
  logic req_parity, last_req_parity;
  logic new_req;
  logic axireq_vld;
  logic resp;
  dbus_axi_req_t axireq;

  logic [31:0] spm_csr_cached; // "hack" to handle weird packing bullshit
  logic [31:0] csrbuf;

  axireq_fsm_t axireq_state, axireq_state_b;

  logic [31:0] meta_csr;

  // DBUS manager signals
  logic [31:0] dbus_dir_b;
  logic [31:0] dbus_o_b;

  logic        release_now; // registers to control the majority of the bus with some more relaxed timing
  logic        drive_now;

  dbus_handshake_t handshake_i, handshake_o;
  dbus_fsm_t dbus_state, dbus_state_b;

  logic dbus_data_bypass;
  logic [9:0] dbus_data_ctr;

  logic axireq_sent, axireq_resp;

  dbus_meta_t dbus_active_meta, dbus_wraith_meta_q, dbus_husk_meta_q;

  logic         uram_wreq_vld[2];
  logic [31:0]  uram_wreq_addr[2];
  logic [127:0] uram_wreq_wdata[2];

  logic         uram_rreq_vld, uram_rreq_busy;
  logic [31:0]  uram_rreq_addr;
  logic [127:0] uram_rreq_rdata;

  logic [1:0]   cacheline_burst_ctr;

  // AXI request logic
  assign new_req = req_parity ^ last_req_parity;

  always_ff @(posedge fabric_clk)
    wraith_rst <= fabric_rst | ~meta_csr[0]; // also used as an "enable" bit for bridge

  always_ff @(posedge fabric_clk)
    rvtu_0_rst <= fabric_rst | ~meta_csr[1];

  always_ff @(posedge fabric_clk)
    rvtu_1_rst <= fabric_rst | ~meta_csr[2];

  always_ff @(posedge fabric_clk) begin
    if (fabric_rst) begin
      resp <= '0;
      axi_rdata <= '0;
      last_req_parity <= '0;
      spm_csr_cached <= '0;
      meta_csr <= '0;
    end else begin
      // i don't love this block but it SHOULD work
      resp <= '0;

      if (new_req) begin
        if (axi_addr[5:2] >= 4'd8) begin
          resp <= '1;
          last_req_parity <= req_parity;

          if (axi_rd) begin
            // TODO: replace hardocded 4'dX constants with parameters?
            if (axi_addr[5:2] == 4'd8) // busy-check
              // can be imprecise on edge-case where resp fires same cycle
              axi_rdata <= {31'b0, axireq_state == IDLE};
            if (axi_addr[5:2] == 4'd9) // CSR val read
              axi_rdata <= csrbuf;
            if (axi_addr[5:2] == 4'd10)
              axi_rdata <= meta_csr;
          end

          if (axi_wr &&
              axi_addr[5:2] == 4'd10) begin
            meta_csr <= axi_wdata;
          end
        end else
          case (axireq_state)
            IDLE: begin
              resp <= '1;
              last_req_parity <= req_parity;

              axi_rdata <= 32'd1;

              if ((axi_addr[5:2] == '0) && axi_wr) begin
                spm_csr_cached <= axi_wdata;
              end
            end

            default: begin
              if (axi_rd) begin
                resp <= '1;
                last_req_parity <= req_parity;
                axi_rdata <= 32'd0;
              end
            end
          endcase
      end
    end
  end

  always_ff @(posedge fabric_clk) begin
    if (fabric_rst) begin
      axireq_vld <= '0;
    end else begin
      case (axireq_state)
        IDLE: begin
          if (new_req && (axi_addr[5:2] < 4'd8)) begin
            axireq_vld <= '1;

            if (axi_addr[5:2] == 4'd7) begin
              if (axi_wr) begin
                axireq.rd <= '0;
                axireq.wr <= '1;
                axireq.spm <= '1;
              end else begin
                axireq.rd <= '0;
                axireq.wr <= '1;

                axireq.csr_idx <= 4'd0;
                axireq.wdata <= spm_csr_cached | 32'b100;
                axireq.spm <= '0;
              end
            end else begin
              // no input filtration -- bad reqs will go to WRAITH
              axireq.rd <= axi_rd;
              axireq.wr <= axi_wr;

              axireq.csr_idx <= axi_addr[4:2];
              axireq.wdata <= axi_wdata;
              axireq.spm <= '0;
            end
          end
        end

        BUSY: begin
          if (axireq_resp)
            axireq_vld <= '0;
        end

        SPMR_W1: begin
          if (axireq_resp) begin
            axireq.rd <= '1;
            axireq.wr <= '0;
            axireq.spm <= '1;
          end
        end

        SPMR_R: begin
          if (axireq_resp) begin
            axireq.rd <= '0;
            axireq.wr <= '1;

            axireq.csr_idx <= 4'd0;
            axireq.wdata <= spm_csr_cached & ~(32'b100);
            axireq.spm <= '0;
          end
        end

        default: ;
      endcase
    end
  end

  always_comb begin
    axireq_state_b = axireq_state;

    case (axireq_state)
      IDLE: begin
        if (new_req) begin
          if (axi_addr[5:2] == 4'd7 && axi_rd) begin
            axireq_state_b = SPMR_W1;
          end else if (axi_addr[5:2] < 4'd8) begin
            axireq_state_b = BUSY;
          end
        end
      end

      BUSY: begin
        if (axireq_resp)
          axireq_state_b = IDLE;
      end

      SPMR_W1: begin
        if (axireq_resp)
          axireq_state_b = SPMR_R;
      end

      SPMR_R: begin
        if (axireq_resp)
          axireq_state_b = BUSY;
      end

      default: ;
    endcase
  end

  always_ff @(posedge fabric_clk) begin
    if (fabric_rst) begin
      axireq_state <= IDLE;
    end else begin
      axireq_state <= axireq_state_b;
    end
  end

  // DBUS manager logic
  assign handshake_i = dbus_i;

  always_comb begin
    if (wraith_rst) begin
      dbus_state_b = POLL;
    end else begin
    case (dbus_state)
      POLL: begin
        if (handshake_i.husk_req)
          dbus_state_b = MCLR;
        else if (handshake_i.wraith_req)
          dbus_state_b = SCLR;
        else
          dbus_state_b = POLL;
      end

      SCLR: dbus_state_b = SADDR;

      SADDR: dbus_state_b = dbus_data_bypass ? FCLR : SDATA;

      SDATA: begin
        if (dbus_data_ctr == 0)
          dbus_state_b = FCLR;
        else
          dbus_state_b = SDATA;
      end

      MCLR: dbus_state_b = MADDR;

      MADDR: dbus_state_b = dbus_data_bypass ? FCLR : MDATA;

      MDATA: begin
        if (dbus_data_ctr == 0)
          dbus_state_b = FCLR;
        else
          dbus_state_b = MDATA;
      end

      FCLR: dbus_state_b = POLL;

      default: dbus_state_b = POLL;
    endcase
    end
  end

  always_ff @(posedge fabric_clk) begin
    if (fabric_rst) begin
      dbus_state <= POLL;
    end else begin
      dbus_state <= dbus_state_b;
    end
  end

  always_ff @(posedge fabric_clk) begin
    if (fabric_rst | ~meta_csr[0]) begin
      drive_now <= '0;
    end else begin
      drive_now <= dbus_state == POLL & dbus_o[31];
    end
  end

  assign release_now = ((dbus_state == MADDR) & dbus_data_bypass) |
                       ((dbus_state == MDATA) & (dbus_data_ctr == '0));

  logic wraith_won_req, wraith_is_done;
  always_ff @(negedge fabric_clk) begin
    if (fabric_rst) begin
      wraith_won_req <= '0;
    end else begin
      wraith_won_req <= (dbus_state == POLL) & ~dbus_o[31];
    end
  end

  assign wraith_is_done = dbus_state == FCLR;

  always_comb begin
    if (fabric_rst | ~meta_csr[0]) begin
      dbus_dir_b = {32{1'b1}};
    end else if (meta_csr[0] & wraith_rst) begin
      dbus_dir_b = {{6{1'b0}}, {26{1'b1}}};
    end else begin // separate into "fastpath" and "slowpath"
      dbus_dir_b[31:26] = (dbus_dir[31:26] & {6{~wraith_is_done}}) |
                          {6{wraith_won_req & handshake_i.wraith_req}};
      // everything else goes here. Much simpler logic.
      dbus_dir_b[25:0] = (dbus_dir[25:0] & {26{~drive_now}}) | {26{release_now}};
    end
  end

  always_comb begin
    handshake_o = 'x;

    if (fabric_rst | ~meta_csr[0]) begin
      dbus_o_b = '0;
    end else begin
      unique case (dbus_state)
        POLL, FCLR: begin
          handshake_o.husk_req = '0;

          // if (uram_rreq_vld & ~uram_rreq_busy) begin
          //   handshake_o.husk_req = '1;
          //   handshake_o.husk_meta = cacheline_rd_resp;
          // end else
          if (axireq_vld & ~axireq_sent) begin
            if (axireq.spm) begin
              if (axireq.wr) begin
                handshake_o.husk_req = '1;
                handshake_o.husk_meta = SPMLEN_spm_write;
              end
            end else begin
              handshake_o.husk_req = '1;
              handshake_o.husk_meta = axireq.rd ? csr_rd_req : csr_write;
            end
          end

          dbus_o_b = handshake_o;
        end

        SCLR, SADDR, SDATA: begin
          dbus_o_b = 'x;
        end

        MCLR: begin // about to go into addr
          case (dbus_husk_meta_q)
            csr_write, csr_rd_req:
              dbus_o_b = 32'(axireq.csr_idx);
            cacheline_rd_resp:
              dbus_o_b = uram_rreq_addr;
            default:
              dbus_o_b = 'x;
          endcase
        end

        MADDR, MDATA: begin // about to go into MDATA, probably. ok to double-drive
          case (dbus_active_meta)
            csr_write:
              dbus_o_b = axireq.wdata;
            SPMLEN_spm_write:
              dbus_o_b = spm_rdata;

            cacheline_rd_resp:
              dbus_o_b = uram_rreq_rdata[32*cacheline_burst_ctr +: 32];
            default:
              dbus_o_b = 'x;
          endcase
        end
      endcase
    end
  end

  (* IOB = "TRUE", max_fanout = 1 *) logic [31:0] dbus_dir_reg;
  assign dbus_dir = dbus_dir_reg;

  always_ff @(posedge fabric_clk) begin
    dbus_dir_reg <= dbus_dir_b;
    dbus_o <= dbus_o_b;
  end

  // always_ff @(negedge fabric_clk) begin
  //   dbus_dir[31:26] <= dbus_dir_b[31:26];
  // end

  always_ff @(posedge fabric_clk) begin
    if (dbus_state == POLL)
      cacheline_burst_ctr <= '0;
    else if (dbus_state == MADDR | dbus_state == MDATA)
      cacheline_burst_ctr <= cacheline_burst_ctr + 2'd1;
  end

  always_ff @(posedge fabric_clk) begin
    if (fabric_rst | (dbus_state == SDATA &
                      dbus_active_meta == csr_rd_resp))
      axireq_sent <= '0;
    else if (dbus_state == MADDR &
             dbus_active_meta == csr_rd_req)
      axireq_sent <= '1;
  end

  always_comb begin
    axireq_resp = '0;

    if (axireq_vld) begin
      if (axireq.spm & axireq.rd)
        axireq_resp = dbus_state == SDATA & (dbus_data_ctr == '0) &
                      dbus_active_meta == SPMLEN_spm_wb;
      else if (axireq.spm & axireq.wr)
        axireq_resp = dbus_state == MDATA & (dbus_data_ctr == '0) &
                      dbus_active_meta == SPMLEN_spm_write;
      else if (axireq.rd)
        axireq_resp = dbus_state == SDATA &
                      dbus_active_meta == csr_rd_resp;
      else if (axireq.wr)
        axireq_resp = dbus_state == MDATA &
                      dbus_active_meta == csr_write;
    end
  end

  // data/req capture logic
  logic whichcore;
  logic [3:0] uram_wreq_ctr[2];
  logic [3:0] uram_rreq_ctr;

  logic       csr_on_bus, cacheline_wb_addr_on_bus, cacheline_data_on_bus;
  logic [31:0] dbus_i_q;
  always_ff @(posedge fabric_clk) begin
    dbus_i_q <= dbus_i;

    if (fabric_rst) begin
      csr_on_bus <= '0;
      cacheline_wb_addr_on_bus <= '0;
      cacheline_data_on_bus <= '0;
    end else begin
      csr_on_bus <= (dbus_state == SDATA) &
                    (dbus_active_meta == csr_rd_resp);
      cacheline_wb_addr_on_bus <= (dbus_state == SADDR) &
                                  (dbus_active_meta == cacheline_wb);
      cacheline_data_on_bus <= (dbus_state == SDATA) &
                               (dbus_active_meta == cacheline_wb);
    end
  end

  always_ff @(posedge fabric_clk) begin
    if (csr_on_bus) begin
      csrbuf <= dbus_i_q;
    end

    if (cacheline_wb_addr_on_bus) begin
      uram_wreq_addr[dbus_i_q[31]] <= dbus_i_q;
      whichcore <= dbus_i_q[31];
    end

    if (cacheline_data_on_bus)
      uram_wreq_wdata[whichcore] <= {dbus_i_q, uram_wreq_wdata[whichcore][127:32]};

    if (dbus_state == FCLR &
        dbus_active_meta == cacheline_wb) begin
      uram_wreq_ctr[whichcore] <= 4'(URAM_LATENCY - 1);
    end

    for (int i=0; i < 2; i++) begin
      if (|uram_wreq_ctr[i])
        uram_wreq_ctr[i] <= uram_wreq_ctr[i] - 4'd1;
    end

    if (dbus_state == SADDR &
        dbus_active_meta == cacheline_rd_req) begin
      uram_rreq_busy <= '1;
      uram_rreq_addr <= dbus_i;

      uram_rreq_ctr <= 4'(URAM_LATENCY);
    end

    if (uram_rreq_ctr == '0) begin
      uram_rreq_busy <= '0;
    end
    if (|uram_rreq_ctr & ~uram_wreq_vld[uram_rreq_addr[31]]) begin
      uram_rreq_ctr <= uram_rreq_ctr - 4'd1;
    end
  end

  always_ff @(posedge fabric_clk) begin
    if (fabric_rst) begin
      uram_wreq_vld <= '{default: '0};
      uram_rreq_vld <= '0;
    end else begin
      if (dbus_state == FCLR &
          dbus_active_meta == cacheline_wb) begin
        uram_wreq_vld[whichcore] <= '1;
      end

      if (dbus_state == SADDR &
          dbus_active_meta == cacheline_rd_req) begin
        uram_rreq_vld <= '1;
      end

      if (dbus_state == FCLR &
          dbus_active_meta == cacheline_rd_resp) begin
        uram_rreq_vld <= '0;
      end

      for (int i=0; i < 2; i++) begin
        if (uram_wreq_ctr[i] == 0 & uram_wreq_vld[i])
          uram_wreq_vld[i] <= '0;
      end
    end
  end

  always_ff @(posedge fabric_clk) begin
    if (uram_rreq_ctr == '0 & uram_rreq_busy & uram_rreq_vld)
      uram_rreq_rdata <= uram_rreq_addr[31] ? uram1_rdata : uram0_rdata;
  end

  assign uram0_addr = uram_wreq_vld[0] ? uram_wreq_addr[0] : uram_rreq_addr;
  assign uram0_we = uram_wreq_vld[0];
  assign uram0_wdata = uram_wreq_wdata[0];

  assign uram0_en = uram_wreq_vld[0] | (|uram_rreq_ctr & uram_rreq_vld);

  assign uram1_addr = uram_wreq_vld[1] ? uram_wreq_addr[1] : uram_rreq_addr;
  assign uram1_we = uram_wreq_vld[1];
  assign uram1_wdata = uram_wreq_wdata[1];

  assign uram1_en = uram_wreq_vld[1] | (|uram_rreq_ctr & uram_rreq_vld);

  // SPM logic
  logic dbus_wb_spm_en;
  assign spm_en = dbus_wb_spm_en |
                  (dbus_husk_meta_q == SPMLEN_spm_write & dbus_state == MCLR) |
                  (dbus_active_meta == SPMLEN_spm_write &
                   (dbus_state inside {MADDR, MDATA}));

  always_ff @(posedge fabric_clk) begin
    if (fabric_rst | dbus_state == POLL)
      dbus_wb_spm_en <= '0;
    else
      dbus_wb_spm_en <= (dbus_active_meta == SPMLEN_spm_wb) &
                        (dbus_state == SDATA);
  end

  always_ff @(posedge fabric_clk)
    spm_we <= (dbus_state == SDATA) &
              (dbus_active_meta == SPMLEN_spm_wb);

  always_ff @(posedge fabric_clk)
    spm_wdata <= dbus_i;

  always_ff @(posedge fabric_clk) begin
    if (fabric_rst | dbus_state == POLL) begin
      spm_addr <= '0;
    end else if (spm_en) begin
      spm_addr <= spm_addr + 9'd1;
    end
  end

  // metadata for requests
  assign dbus_data_bypass = dbus_active_meta == csr_rd_req |
                            dbus_active_meta == cacheline_rd_req;

  always_ff @(posedge fabric_clk) begin
    dbus_wraith_meta_q <= handshake_i.wraith_meta;
    dbus_husk_meta_q <= handshake_i.husk_meta;

    if (meta_csr[0]) begin
      if (dbus_state == SCLR) begin
        dbus_active_meta <= dbus_wraith_meta_q;
      end else if (dbus_state == MCLR) begin
        dbus_active_meta <= dbus_husk_meta_q;
      end
    end
  end

  always_ff @(posedge fabric_clk) begin
    if (dbus_state == SCLR) begin
      case (dbus_wraith_meta_q)
        SPMLEN_spm_wb:
          dbus_data_ctr <= 10'(spm_csr_cached[25:17]);
        cacheline_wb:
          dbus_data_ctr <= 10'd3;
        default:
          dbus_data_ctr <= 10'd0;
      endcase
    end

    else if (dbus_state == MCLR) begin
      case (dbus_husk_meta_q)
        SPMLEN_spm_write:
          dbus_data_ctr <= 10'(spm_csr_cached[16:8]);
        cacheline_rd_resp:
          dbus_data_ctr <= 10'd3;
        default:
          dbus_data_ctr <= 10'd0;
      endcase
    end

    else if (dbus_state inside {MDATA, SDATA}) begin
      dbus_data_ctr <= dbus_data_ctr - 10'd1;
    end
  end


  // CDC logic
  // TODO: how to handle dual reset? for now, only looking at the reset on the
  // associated clock domain. could cause correctness failures ;-;
  logic axi_req_parity;
  (* ASYNC_REG = "TRUE" *) logic [1:0] req_chain;
  logic axi_rd_r, axi_wr_r;

  always_ff @(posedge axi_clk or
              negedge axi_rst_n) begin
    if (~axi_rst_n) begin
      axi_rd_r <= '0;
      axi_wr_r <= '0;

      axi_req_parity <= '0;
    end else begin
      axi_rd_r <= axi_rd;
      axi_wr_r <= axi_wr;

      axi_req_parity <= axi_req_parity ^ ((axi_rd & ~axi_rd_r) |
                                          (axi_wr & ~axi_wr_r));
    end
  end

  always_ff @(posedge fabric_clk or
              posedge fabric_rst) begin
    if (fabric_rst) begin
      req_chain <= '0;
    end else begin
      req_chain <= {req_chain[0], axi_req_parity};
    end
  end

  assign req_parity = req_chain[1];

  logic resp_level;
  (* ASYNC_REG = "TRUE" *) logic [2:0] axi_resp_chain;

  always_ff @(posedge fabric_clk or
              posedge fabric_rst) begin
    if (fabric_rst) begin
      resp_level <= '0;
    end else begin
      resp_level <= resp_level ^ resp;
    end
  end

  always_ff @(posedge axi_clk or
              negedge axi_rst_n) begin
    if (~axi_rst_n) begin
      axi_resp_chain <= '0;
    end else begin
      axi_resp_chain <= {axi_resp_chain[1:0], resp_level};
    end
  end

  assign axi_resp = axi_resp_chain[2] ^ axi_resp_chain[1];
endmodule
