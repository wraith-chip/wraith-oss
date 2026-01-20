module spm_read_ctrl
import spm_types::*;
#(
  parameter int unsigned NUM_BANKS = 1,
  parameter int unsigned BANK_SIZE = 512, // 2kB
  parameter int unsigned SRAM_WORD_SIZE = 32,
  parameter int unsigned DBUS_WIDTH = 32,
  parameter int unsigned FIFO_WIDTH = 36,
  parameter int unsigned PKT_ID_WIDTH = 4
  )(
    input logic clk,
    input logic rst,

    // Facing the Bridge/ARB
    input  logic ack,
    output logic [DBUS_WIDTH-1:0] dbus_out,
    output logic dbus_valid,

    // CSRs
    input logic [$clog2(BANK_SIZE)-1:0] num_words,
    input logic wb_enable,
    output logic kernel_fin,

  // Interface with the egress FIFOs
    output logic dequeue,
    input  logic fifo_empty,
    input  logic [FIFO_WIDTH-1:0] fifo_rdata
  );
    localparam int unsigned NUM_CYC_CLSC = $ceil(SRAM_WORD_SIZE/DBUS_WIDTH);
    localparam int unsigned CLSC_CTR_WIDTH = (NUM_CYC_CLSC> 1) ? $clog2(NUM_CYC_CLSC) : 1; 
    localparam int unsigned NUM_DATA_CYCLES = BANK_SIZE * NUM_CYC_CLSC;

    localparam logic [31:0] MAGIC = 32'hECEBCAFE;

  logic clsc_valid, clsc_start;
  logic [CLSC_CTR_WIDTH-1:0] clsc_cntr;

  logic [PKT_ID_WIDTH-1:0] pkt_id;
  assign pkt_id = fifo_rdata[35:32];
  //  ------- FSM ----------
  spm_sram_read_fsm_t ssr_fsm;
  logic [$clog2(BANK_SIZE) -1:0] sram_wr_ctr, sram_rd_ctr;
  logic [$clog2(BANK_SIZE)-1:0] sram_wr_addr, sram_rd_addr;
  always_ff @(posedge clk) begin
    if (rst) begin
      ssr_fsm <= ssr_idle;
    end else begin
      unique case (ssr_fsm)
        (ssr_idle): begin
          ssr_fsm <= (fifo_empty)? ssr_idle: ssr_get_pkts; 
        end
        (ssr_get_pkts): begin
          ssr_fsm <= (sram_wr_ctr == '0)? ssr_wait_wb: ssr_get_pkts; 
        end
        (ssr_wait_wb): begin
          ssr_fsm <= (wb_enable)? ssr_magic: ssr_wait_wb; 
        end
        (ssr_magic): begin
          ssr_fsm <= ssr_wb;
        end
        (ssr_wb): begin
          ssr_fsm <= (sram_rd_ctr == '0)? ssr_idle: ssr_wb; 
        end
        default: begin
          ssr_fsm <= ssr_idle;
        end
      endcase
    end
  end
  
  
  always_ff @(posedge clk) begin
    if (ssr_fsm == ssr_wait_wb) begin
      kernel_fin <= '1;
    end else begin
      kernel_fin <= '0;
    end
    
  end
  logic ack_f, fake_ack;
  always_ff @( posedge clk) begin
    if (ssr_fsm == ssr_idle) begin
      ack_f <= '0;
    end else begin
      if (ack) begin
        ack_f <= '1;
      end
    end
  end
  assign fake_ack = ack_f; 



  always_ff @(posedge clk) begin
    if (ssr_fsm == ssr_idle) begin
      sram_rd_ctr <= num_words;
      sram_wr_ctr <= num_words;
      sram_rd_addr <= '0;
      sram_wr_addr <= '0;

    end else begin

      if (ssr_fsm == ssr_get_pkts) begin
        if (!fifo_empty) begin
          sram_wr_addr <= sram_wr_addr + 'd1;
          sram_wr_ctr <= sram_wr_ctr - 1;

        end
      end else if (ssr_fsm == ssr_wb) begin
        if (clsc_valid && fake_ack) begin
          sram_rd_addr <= sram_rd_addr + 'd1;
          sram_rd_ctr <= sram_rd_ctr-1;
        end
      end
    end
  end

  assign dequeue = (ssr_fsm == ssr_get_pkts) ? !fifo_empty : '0;
  // -------- Uncoalesce sram reads -------------
    logic [CLSC_CTR_WIDTH-1:0] clsc_cntr_rev;
    always_ff @(posedge clk) begin
      if (rst) begin
        clsc_cntr <= '0;
        clsc_cntr_rev <= '1;
      end else begin
        if (ssr_fsm == ssr_wb) begin
          clsc_cntr <= clsc_cntr+1;
          clsc_cntr_rev <= clsc_cntr_rev-1;
        end
      end
    end

    generate
    if (NUM_CYC_CLSC == 1) begin
      assign clsc_valid = '1;
      assign dbus_out = (ssr_fsm == ssr_magic) ? MAGIC : ctrl_if.rdata;
    end else begin
      assign clsc_valid = (clsc_cntr == '1);
    assign dbus_out = ctrl_if.rdata[(SRAM_WORD_SIZE-1) - ((clsc_cntr_rev) * DBUS_WIDTH) -: DBUS_WIDTH];
    end
    endgenerate

    assign clsc_start = (clsc_cntr == '0);

    assign dbus_valid = ctrl_if.rvalid;
  //  ------- Output bank ----------
  

  scratchpad_bank_if ctrl_if();
  assign ctrl_if.addr = (ssr_fsm == ssr_get_pkts) ? sram_wr_addr : sram_rd_addr ;
  assign ctrl_if.ren = (ssr_fsm == ssr_wb);
  assign ctrl_if.wen = (dequeue);
  assign ctrl_if.wdata = fifo_rdata [FIFO_WIDTH - PKT_ID_WIDTH -1 :0];
  spm_sram_wrapper input_spm(
    .clk(clk),
    .rst(rst),
    .ctrl_if(ctrl_if)
    );

  endmodule
