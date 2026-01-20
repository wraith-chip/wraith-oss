module mmmu_bridge
  import mmmu_types::*;
  import glbl_pkg::*;
(
    input logic clk,
    input logic rst,

    // Data bus pins
    input  logic [31:0] dbus,
    output logic [31:0] dbus_wdata,
    output logic [1:0]  dbus_tri_en,

    // Arb request I/O
    input               arb_vld_i,
    input [31:0]        arb_pkt_i,
    output logic        arb_ack,

    output logic        arb_fin,

    // Arb response I/O
    output logic        arb_vld_o,
    output logic [31:0] arb_pkt_o,
    output dbus_meta_t  arb_type_o,

    output logic [31:0] rfile_rdata[NUM_RFILE],
    input  logic [31:0] wfile_wdata[NUM_WFILE],

    output logic [2:0]  test_mmmu_state
);
  bridge_state_t state, state_next;

  dbus_pkt_cyc0_t dbus_cast, dbus_wdata_next_cast;
  assign dbus_cast = dbus_pkt_cyc0_t'(dbus);

  dbus_meta_t active_meta;
  logic data_bypass;
  logic [DATA_CTR_WIDTH-1:0] data_ctr;

  logic [31:0]             dbus_wdata_next;
  logic [1:0]              dbus_tri_en_next;

  always_ff @(posedge clk) dbus_wdata <= dbus_wdata_next;
  always_ff @(posedge clk) dbus_tri_en <= dbus_tri_en_next;

  assign arb_pkt_o  = dbus;
  assign arb_type_o = active_meta;

  always_comb begin
    case (active_meta)
      SPMLEN_spm_write, SPMLEN_spm_wb:
        arb_vld_o = state == SDATA;
      cacheline_rd_resp:
        arb_vld_o = state inside{SADDR, SDATA};
      default: arb_vld_o = '0;
    endcase
  end

  logic [CSR_IDX_BITS-1:0] csr_addr;
  logic                    csr_wen;
  logic [31:0]             csr_dbus_rdata;

  logic                    outstanding_csr_rd;

  always_comb begin
    case (state)
      POLL: begin
        if (dbus_cast.off_chip_req)
          state_next = SCLR;
        else if (dbus_cast.on_chip_req)
          state_next = MCLR;
        else
          state_next = POLL;
      end

      SCLR: state_next = SADDR;

      SADDR: state_next = data_bypass ? FCLR : SDATA;

      SDATA: begin
        if (data_ctr == 0)
          state_next = FCLR;
        else
          state_next = SDATA;
      end

      MCLR: state_next = MADDR;

      MADDR: state_next = data_bypass ? FCLR : MDATA;

      MDATA: begin
        if (data_ctr == 0)
          state_next = FCLR;
        else
          state_next = MDATA;
      end

      FCLR: state_next = POLL;

      default: state_next = POLL;
    endcase
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      state <= POLL;
      test_mmmu_state <= POLL;
    end else begin
      state <= state_next;
      test_mmmu_state <= state_next;
    end
  end

  always_comb begin
    dbus_wdata_next_cast = 'x;
    if (rst) begin
      dbus_tri_en_next = 2'b10;
      dbus_wdata_next_cast.on_chip_req = '0;
      dbus_wdata_next = '0;
    end else begin
      unique case (state_next)
        POLL: begin
          dbus_tri_en_next = 2'b10;

          if (outstanding_csr_rd) begin
            dbus_wdata_next_cast.on_chip_req  = '1;
            dbus_wdata_next_cast.on_chip_meta = csr_rd_resp;
            dbus_wdata_next = dbus_wdata_next_cast;
          end
          else if (arb_vld_i)
            dbus_wdata_next = arb_pkt_i;
          else begin
            dbus_wdata_next_cast.on_chip_req = '0;
            dbus_wdata_next = dbus_wdata_next_cast;
          end
        end

        SCLR, MCLR, FCLR, SADDR, SDATA: begin
          dbus_tri_en_next = 2'b11;
          dbus_wdata_next = 'x;
        end

        MADDR: begin
          dbus_tri_en_next = 2'b00;

          if (outstanding_csr_rd)
            dbus_wdata_next = 32'(csr_addr) | 32'(1 << MMIO_CSR_SELECT_BITIDX);
          else
            dbus_wdata_next = arb_pkt_i;
        end

        MDATA: begin
          dbus_tri_en_next = 2'b00;

          if (outstanding_csr_rd)
            dbus_wdata_next = 32'(csr_dbus_rdata);
          else
            dbus_wdata_next = arb_pkt_i;
        end
      endcase
    end
  end

  assign arb_ack = (state_next == MCLR) &
                   ~outstanding_csr_rd;
  assign arb_fin = (state_next == FCLR);

  always_ff @(posedge clk) begin
    if (rst)
      data_ctr <= '0;
    else if (state inside {MCLR, SCLR}) begin
      case (active_meta)
        SPMLEN_spm_write:
          data_ctr <= rfile_rdata[SPMLEN_RFILE_IDX]
                      [SPMLEN_IN_BOT_IDX +: DATA_CTR_WIDTH];
        SPMLEN_spm_wb:
          data_ctr <= rfile_rdata[SPMLEN_RFILE_IDX]
                      [SPMLEN_OUT_BOT_IDX +: DATA_CTR_WIDTH];

        cacheline_rd_resp:
          data_ctr <= 'd3;

        cacheline_wb:
          data_ctr <= 'd3;

        default: data_ctr <= '0;
      endcase
    end
    else if (state inside {MDATA, SDATA})
      data_ctr <= data_ctr - 'd1;
  end

  assign data_bypass = active_meta inside {
    csr_rd_req, cacheline_rd_req
  };

  always_ff @(posedge clk) begin
    if (rst)
      active_meta <= no_meta;
    else if (state_next == SCLR)
      active_meta <= dbus_cast.off_chip_meta;
    else if (state_next == MCLR)
      active_meta <= dbus_cast.on_chip_meta;
  end

  csr_regfile csrfile (
    .clk,
    .rst,

    .off_chip_csr_addr      (csr_addr),
    .off_chip_rfile_wen     (csr_wen),
    .off_chip_rfile_wdata   (dbus),
    .off_chip_csrfile_rdata (csr_dbus_rdata),

    .rfile_rdata,
    .wfile_wdata
  );

  always_ff @(posedge clk) begin
    if ((state == SADDR) &
        (active_meta inside {csr_write, csr_rd_req}))
      csr_addr <= dbus[CSR_IDX_BITS-1:0];
  end

  assign csr_wen = (state == SDATA) &
                   (active_meta == csr_write);

  always_ff @(posedge clk) begin
    if (rst)
      outstanding_csr_rd <= '0;
    else if (state == SADDR &
             active_meta == csr_rd_req)
      outstanding_csr_rd <= '1;
    else if (state == MDATA)
      outstanding_csr_rd <= '0;
  end
endmodule
