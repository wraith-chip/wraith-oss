module fallback
import fallback_types::*;
#(
  parameter int unsigned SRAM_WORD_SIZE = 32,
  parameter int unsigned FIFO_WIDTH = 36,
  parameter int unsigned COUNTER_WIDTH = $clog2(FIFO_WIDTH-1)
  )
(
  input logic clk,
  input logic rst,

  input logic fb_en,
  input logic fb_d_in_vld,
  input logic fb_d_in,
  output logic fb_d_clsc,
  output logic fb_d_out,
  output logic fb_d_out_vld,

  input logic fb_spm_mesh_full,
  output logic fb_spm_mesh_enqueue,
  output logic [SRAM_WORD_SIZE-1:0] fb_spm_mesh_wdata,

  input logic fb_mesh_spm_empty,
  output logic fb_mesh_spm_dequeue,
  input logic [FIFO_WIDTH-1:0] fb_mesh_spm_rdata
  );

  logic fb_en_f;
  logic fb_d_in_vld_f;
  logic fb_d_in_f;

  logic fb_d_clsc_f;
  logic fb_d_out_f;
  logic fb_d_out_vld_f;

  always_ff @(posedge clk) begin
    if (rst) begin
      fb_en_f <= '0;
      fb_d_in_vld_f <= '0;
      fb_d_in_f <= '0;

      fb_d_clsc <= '0;
      fb_d_out <='0;
      fb_d_out_vld <='0;
    end else begin
      fb_en_f <= fb_en;
      fb_d_in_vld_f <= fb_d_in_vld;
      fb_d_in_f <= fb_d_in;

      fb_d_clsc <= fb_d_clsc_f;
      fb_d_out <= fb_d_out_f;
      fb_d_out_vld <= fb_d_out_vld_f;
    end
  end


  logic [COUNTER_WIDTH-1:0] data_in_ctr;
  logic [COUNTER_WIDTH-1:0] data_out_ctr;

  logic [35:0] packet_in;
  logic [35:0] packet_out;


  // For the input handler.
  // Everytime 36 bits have been given to us
  // enqueue into fifo if not full
  // raise clsc signal after enqueing and accept next set of bits

  // states are
  // idle
  // ingest bitstream
  // wait for fifo_spot
  // enqueue

  fb_fsm_in_t in_fsm;
  always_ff @(posedge clk) begin 
    if (rst) begin
      in_fsm <= in_idle;
    end else begin
      if (fb_en_f) begin
        unique case (in_fsm)
          (in_idle): begin
            in_fsm <= (fb_d_in_vld_f) ? in_eat_bits: in_idle;  
          end

          (in_eat_bits): begin
            in_fsm <= (data_in_ctr == '0) ? in_enqueue : in_eat_bits;  
          end

          (in_enqueue): begin
            in_fsm <= (!fb_spm_mesh_full) ? in_idle : in_enqueue;
          end

          default: begin
            in_fsm <= in_idle;
          end

        endcase
      end
    end
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      data_in_ctr <= FIFO_WIDTH-1;
    end else begin
      if (fb_en_f) begin
        if (in_fsm == in_enqueue) begin
          data_in_ctr <= FIFO_WIDTH-1;
        end else if (fb_d_in_vld_f) begin
          if (data_in_ctr == 0) begin
            data_in_ctr <= FIFO_WIDTH-1;
          end else begin
            data_in_ctr <= data_in_ctr-1;
          end
        end
      end
    end
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      packet_in <= '0;
    end else begin
      if (fb_en_f && fb_d_in_vld_f) begin
      packet_in[data_in_ctr] <= fb_d_in_f;
      end
    end
  end


  assign fb_spm_mesh_wdata = packet_in;
  assign fb_spm_mesh_enqueue = (in_fsm == in_enqueue) && (!fb_spm_mesh_full);
  assign fb_d_clsc_f = (in_fsm == in_enqueue) && (!fb_spm_mesh_full);

  // For the output handler
  // everytime the output fifo goes non empty
  // dequeue into buffer
  // shit out the bits from MSB to LSB.
  // repeat
  


  // states are 
  // dequeue
  // cast bitstream
  // idle

  fb_fsm_out_t out_fsm;
  always_ff @(posedge clk) begin 
    if (rst) begin
      out_fsm <= out_idle;
    end else begin
      if (fb_en_f) begin
        unique case (out_fsm)
          (out_idle): begin
            out_fsm <= (!fb_mesh_spm_empty) ? out_dequeue: out_idle;  
          end

          (out_dequeue): begin
            out_fsm <= out_w_bits;  
          end

          (out_w_bits): begin
            out_fsm <= (data_out_ctr == '0) ? out_idle : out_w_bits;
          end

          default: begin
            out_fsm <= out_idle;
          end
        endcase
      end
    end
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      packet_out <= '0;
    end else begin
      if (fb_en_f) begin
        if (out_fsm == out_dequeue) begin
          packet_out <= fb_mesh_spm_rdata;
        end
      end
    end 
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      data_out_ctr <= FIFO_WIDTH-1;
    end else begin
      if (fb_en_f) begin
        if (out_fsm == out_idle) begin
          data_out_ctr <= FIFO_WIDTH-1;
        end else if (out_fsm == out_w_bits) begin
          data_out_ctr <= data_out_ctr-1;
        end
      end
    end
  end

  assign fb_d_out_f = packet_out[data_out_ctr];
  assign fb_mesh_spm_dequeue = (out_fsm == out_dequeue) && fb_en_f;

  assign fb_d_out_vld_f = (out_fsm == out_w_bits) && fb_en_f;

endmodule
