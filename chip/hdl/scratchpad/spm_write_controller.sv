module spm_write_ctrl
import spm_types::*;
#(
  parameter int NUM_BANKS = 1,
  parameter int BANK_SIZE = 512, // 2kB
  parameter int SRAM_WORD_SIZE = 32, 
  parameter int DBUS_WIDTH = 32,
  parameter int FIFO_WIDTH = 36,
  parameter int PKT_ID_WIDTH = 4
  )(
    input logic clk,
    input logic rst,

    input logic req_in,
    input logic [DBUS_WIDTH-1:0] dbus_in,
    input logic [$clog2(BANK_SIZE)-1:0] num_words,

    output logic [SRAM_WORD_SIZE-1:0] fifo_wdata,
    output logic enqueue,
    input  logic fifo_full,

    output logic pkt_ingress_fin

  );

/*
 * I am going to shit out the expected bus transaction behaviour for 
 * the DMA writes coming from the off-chip into the SPM.
 * Cycle 0 - handshake / arbitration
 * 1K/512 cycles of data transmission
 */




  // -------------- DBUS coalescing logic ------
    localparam int NUM_CYC_CLSC = $ceil(SRAM_WORD_SIZE/DBUS_WIDTH);
    localparam int CLSC_CTR_WIDTH = (NUM_CYC_CLSC> 1) ? $clog2(NUM_CYC_CLSC) : 1; 
    localparam int NUM_SRAM_DATA_WORDS = NUM_BANKS * BANK_SIZE;
    localparam int NUM_DATA_CYCLES = NUM_SRAM_DATA_WORDS * NUM_CYC_CLSC;


  logic [CLSC_CTR_WIDTH-1:0] clsc_cntr;
  logic [SRAM_WORD_SIZE-1:0] clsc_buf;
  logic clsc_valid;
  logic req_in_f;
  logic [SRAM_WORD_SIZE-1:0] clsc_wrd;

  generate 
  if (NUM_CYC_CLSC == 1) begin
    assign clsc_valid = req_in_f;
  end else begin
    assign clsc_valid = (clsc_cntr == '1) && (req_in||req_in_f);
  end
  endgenerate

  // Coalesce counter logic
  always_ff @(posedge clk) begin
    req_in_f <= req_in;
    if (rst) begin
      clsc_cntr <= '0;
    end else begin
      if (req_in) begin
        clsc_cntr <= clsc_cntr + 1'b1;
      end
      else begin
        clsc_cntr <= '0;
      end
    end
  end


  // coalesce buffer logic
  generate
    if (NUM_CYC_CLSC == 1) begin
      always_ff @(posedge clk) begin
        if(rst) begin
          clsc_buf <= 'x;
        end else begin
          if (req_in) begin
              clsc_buf <= dbus_in;
          end
        end
      end
    end else begin
      always_ff @(posedge clk) begin
        if(rst) begin
          clsc_buf <= 'x;
        end else begin
          if (req_in) begin
              clsc_buf[SRAM_WORD_SIZE - (clsc_cntr + 1) * DBUS_WIDTH +: DBUS_WIDTH] <= dbus_in;
          end
        end
      end
    end
  endgenerate


  // -------------- FSM that handles incoming DMA Stream ----------------

  spm_sram_write_fsm_t ssw_fsm;
  logic [$clog2(NUM_SRAM_DATA_WORDS)-1:0] sram_wr_word_ctr, sram_rd_word_ctr;
  logic [SRAM_WORD_SIZE-1:0] sram_rdata;
  logic wen, ren, rvalid;
  logic [$clog2(BANK_SIZE)-1:0] sram_wr_addr, sram_rd_addr;
  logic mesh_write_fin;

  always_ff @(posedge clk) begin
    if (rst) begin
      ssw_fsm <= ssw_idle;
      pkt_ingress_fin <= '0;
    end else begin
      unique case (ssw_fsm)
        ssw_idle: begin
          if (req_in) begin
            ssw_fsm <= ssw_sram_wr;
            pkt_ingress_fin <= '0;
          end
        end
        ssw_sram_wr: begin
          if (sram_wr_word_ctr == '0 && clsc_valid) begin
            ssw_fsm <= ssw_write_mesh;
          end
        end
        ssw_write_mesh: begin
          if (sram_rd_word_ctr == '0) begin
            ssw_fsm <= ssw_idle;
            pkt_ingress_fin <= '1;
          end
        end
        default: begin
          ssw_fsm <= ssw_idle;
        end
      endcase
    end
  end

  // Other maintenance singals
  always_ff @(posedge clk) begin
    if (ssw_fsm == ssw_idle) begin
      sram_wr_word_ctr <= num_words; 
      sram_rd_word_ctr <= num_words; 
      sram_wr_addr <= '0;
      sram_rd_addr <= '0;
      enqueue <= '0;
    end else begin
      if (ssw_fsm==ssw_sram_wr) begin
        if (clsc_valid) begin
          sram_wr_word_ctr <= sram_wr_word_ctr -1;
          sram_wr_addr <= sram_wr_addr + 32'd1;
        end
      end else if (ssw_fsm == ssw_write_mesh) begin
        if (!fifo_full) begin
          sram_rd_addr <= sram_rd_addr + 32'd1;
          sram_rd_word_ctr <= sram_rd_word_ctr - 1;
          enqueue <= '1;
        end else begin
          enqueue <= '0;
        end
      end
    end
  end

  assign wen = clsc_valid && (ssw_fsm == ssw_sram_wr);
  assign ren = (ssw_fsm == ssw_write_mesh);

generate 
  if (NUM_CYC_CLSC == 1) begin
    assign clsc_wrd = clsc_buf;
  end else begin
    assign clsc_wrd = (clsc_valid && (ssw_fsm == ssw_sram_wr)) ? { clsc_buf[SRAM_WORD_SIZE-1 -: (NUM_CYC_CLSC - 1)*DBUS_WIDTH], dbus_in } : 'x;
  end
endgenerate 

  // ------------ Interfacing with the Input Bank ----------------

  logic [$clog2(BANK_SIZE)-1:0] addr;
  assign addr = (ssw_fsm == ssw_sram_wr) ? sram_wr_addr : sram_rd_addr;
  scratchpad_bank_if ctrl_if();
  assign ctrl_if.wen = wen;
  assign ctrl_if.wdata = clsc_wrd;
  assign ctrl_if.ren = ren;
  assign ctrl_if.addr = addr;
  assign rvalid = ctrl_if.rvalid;
  assign sram_rdata = ctrl_if.rdata;



 // Funny stall handling for the mesh-ingress FIFO
 // Basically - if first cycle of stall. Send same data
 // If second cycle of stall, use the latched data,
 // if stall ends, first cycle of stall low - use latched data
 // then resume using sram_rdata

  logic [31:0] sram_rdata_f;
  logic fifo_full_f;

  always_ff @(posedge clk) begin
    fifo_full_f <= fifo_full;

    if (fifo_full && !fifo_full_f) begin
      sram_rdata_f  <= sram_rdata;
    end 
  end

  always_comb begin
    if (fifo_full && !fifo_full_f) begin // first cycle of stall
      fifo_wdata = sram_rdata;
    end else if (fifo_full_f && ! fifo_full) begin // cycle after stall ends
      fifo_wdata = sram_rdata_f;
    end else if (fifo_full && fifo_full_f) begin // other cycles of stall
      fifo_wdata = sram_rdata_f;
    end else begin // non first cycle of non stall
      fifo_wdata = sram_rdata;
    end
    
  end

  // Instantiate the SRAM bank here
  spm_sram_wrapper input_spm(
    .clk(clk),
    .rst(rst),
    .ctrl_if(ctrl_if)
    );

endmodule
