module io_in (
    input  wire chipout,
    output wire chipin
);

`ifdef SYNTHESIS
  // Synthesis implementation
  BUFZ in_buf (
      .A (chipout),
      .OE(1'b1),
      .Y (chipin)
  );
`else
  // Behavioral model
  assign chipin = chipout;
`endif

endmodule

module io_out (
    output wire chipout,
    input  wire chipin
);

`ifdef SYNTHESIS
  logic buffered_chipin[2];

  BUFZ buffered_chipin_i_0 (
      .A (chipin),
      .OE(1'b1),
      .Y (buffered_chipin[0])
  );
  BUFZ buffered_chipin_i_1 (
      .A (buffered_chipin[0]),
      .OE(1'b1),
      .Y (buffered_chipin[1])
  );

  logic [3:0] inter_wire_o_out;

  BUFZ inter_wire_o_out_i_0 (
      .A (buffered_chipin[1]),
      .OE(1'b1),
      .Y (inter_wire_o_out[0])
  );
  BUFZ inter_wire_o_out_i_1 (
      .A (buffered_chipin[1]),
      .OE(1'b1),
      .Y (inter_wire_o_out[1])
  );
  BUFZ inter_wire_o_out_i_2 (
      .A (buffered_chipin[1]),
      .OE(1'b1),
      .Y (inter_wire_o_out[2])
  );
  BUFZ inter_wire_o_out_i_3 (
      .A (buffered_chipin[1]),
      .OE(1'b1),
      .Y (inter_wire_o_out[3])
  );

  BUFZ out_buf_0 (
      .A (inter_wire_o_out[0]),
      .OE(1'b1),
      .Y (chipout)
  );
  BUFZ out_buf_1 (
      .A (inter_wire_o_out[0]),
      .OE(1'b1),
      .Y (chipout)
  );
  BUFZ out_buf_2 (
      .A (inter_wire_o_out[0]),
      .OE(1'b1),
      .Y (chipout)
  );
  BUFZ out_buf_3 (
      .A (inter_wire_o_out[0]),
      .OE(1'b1),
      .Y (chipout)
  );

  BUFZ out_buf_4 (
      .A (inter_wire_o_out[1]),
      .OE(1'b1),
      .Y (chipout)
  );
  BUFZ out_buf_5 (
      .A (inter_wire_o_out[1]),
      .OE(1'b1),
      .Y (chipout)
  );
  BUFZ out_buf_6 (
      .A (inter_wire_o_out[1]),
      .OE(1'b1),
      .Y (chipout)
  );
  BUFZ out_buf_7 (
      .A (inter_wire_o_out[1]),
      .OE(1'b1),
      .Y (chipout)
  );

  BUFZ out_buf_8 (
      .A (inter_wire_o_out[2]),
      .OE(1'b1),
      .Y (chipout)
  );
  BUFZ out_buf_9 (
      .A (inter_wire_o_out[2]),
      .OE(1'b1),
      .Y (chipout)
  );
  BUFZ out_buf_a (
      .A (inter_wire_o_out[2]),
      .OE(1'b1),
      .Y (chipout)
  );
  BUFZ out_buf_b (
      .A (inter_wire_o_out[2]),
      .OE(1'b1),
      .Y (chipout)
  );

  BUFZ out_buf_c (
      .A (inter_wire_o_out[3]),
      .OE(1'b1),
      .Y (chipout)
  );
  BUFZ out_buf_d (
      .A (inter_wire_o_out[3]),
      .OE(1'b1),
      .Y (chipout)
  );
  BUFZ out_buf_e (
      .A (inter_wire_o_out[3]),
      .OE(1'b1),
      .Y (chipout)
  );
  BUFZ out_buf_f (
      .A (inter_wire_o_out[3]),
      .OE(1'b1),
      .Y (chipout)
  );
`else
  // NOTE(Ingi): I didn't test this
  assign chipout = chipin;
`endif

endmodule

module io_tri (
    inout  wire  chipout,
    output logic i,
    input  logic o,
    input  logic t
);

  io_in in_buf (
      .chipout(chipout),
      .chipin (i)
  );

`ifdef SYNTHESIS
  logic buffered_o[2];
  logic buffered_t[2];

  BUFZ buffered_o_i_0 (
      .A (o),
      .OE(1'b1),
      .Y (buffered_o[0])
  );
  BUFZ buffered_t_i_0 (
      .A (~t),
      .OE(1'b1),
      .Y (buffered_t[0])
  );

  BUFZ buffered_o_i_1 (
      .A (buffered_o[0]),
      .OE(1'b1),
      .Y (buffered_o[1])
  );
  BUFZ buffered_t_i_1 (
      .A (buffered_t[0]),
      .OE(1'b1),
      .Y (buffered_t[1])
  );

  logic [3:0] inter_wire_o_out;
  logic [3:0] inter_wire_o_tri;

  BUFZ inter_wire_o_out_i_0 (
      .A (buffered_o[1]),
      .OE(1'b1),
      .Y (inter_wire_o_out[0])
  );
  BUFZ inter_wire_o_out_i_1 (
      .A (buffered_o[1]),
      .OE(1'b1),
      .Y (inter_wire_o_out[1])
  );
  BUFZ inter_wire_o_out_i_2 (
      .A (buffered_o[1]),
      .OE(1'b1),
      .Y (inter_wire_o_out[2])
  );
  BUFZ inter_wire_o_out_i_3 (
      .A (buffered_o[1]),
      .OE(1'b1),
      .Y (inter_wire_o_out[3])
  );

  BUFZ inter_wire_o_tri_i_0 (
      .A (buffered_t[1]),
      .OE(1'b1),
      .Y (inter_wire_o_tri[0])
  );
  BUFZ inter_wire_o_tri_i_1 (
      .A (buffered_t[1]),
      .OE(1'b1),
      .Y (inter_wire_o_tri[1])
  );
  BUFZ inter_wire_o_tri_i_2 (
      .A (buffered_t[1]),
      .OE(1'b1),
      .Y (inter_wire_o_tri[2])
  );
  BUFZ inter_wire_o_tri_i_3 (
      .A (buffered_t[1]),
      .OE(1'b1),
      .Y (inter_wire_o_tri[3])
  );

  BUFZ out_buf_0 (
      .A (inter_wire_o_out[0]),
      .OE(inter_wire_o_tri[0]),
      .Y (chipout)
  );
  BUFZ out_buf_1 (
      .A (inter_wire_o_out[0]),
      .OE(inter_wire_o_tri[0]),
      .Y (chipout)
  );
  BUFZ out_buf_2 (
      .A (inter_wire_o_out[0]),
      .OE(inter_wire_o_tri[0]),
      .Y (chipout)
  );
  BUFZ out_buf_3 (
      .A (inter_wire_o_out[0]),
      .OE(inter_wire_o_tri[0]),
      .Y (chipout)
  );

  BUFZ out_buf_4 (
      .A (inter_wire_o_out[1]),
      .OE(inter_wire_o_tri[1]),
      .Y (chipout)
  );
  BUFZ out_buf_5 (
      .A (inter_wire_o_out[1]),
      .OE(inter_wire_o_tri[1]),
      .Y (chipout)
  );
  BUFZ out_buf_6 (
      .A (inter_wire_o_out[1]),
      .OE(inter_wire_o_tri[1]),
      .Y (chipout)
  );
  BUFZ out_buf_7 (
      .A (inter_wire_o_out[1]),
      .OE(inter_wire_o_tri[1]),
      .Y (chipout)
  );

  BUFZ out_buf_8 (
      .A (inter_wire_o_out[2]),
      .OE(inter_wire_o_tri[2]),
      .Y (chipout)
  );
  BUFZ out_buf_9 (
      .A (inter_wire_o_out[2]),
      .OE(inter_wire_o_tri[2]),
      .Y (chipout)
  );
  BUFZ out_buf_a (
      .A (inter_wire_o_out[2]),
      .OE(inter_wire_o_tri[2]),
      .Y (chipout)
  );
  BUFZ out_buf_b (
      .A (inter_wire_o_out[2]),
      .OE(inter_wire_o_tri[2]),
      .Y (chipout)
  );

  BUFZ out_buf_c (
      .A (inter_wire_o_out[3]),
      .OE(inter_wire_o_tri[3]),
      .Y (chipout)
  );
  BUFZ out_buf_d (
      .A (inter_wire_o_out[3]),
      .OE(inter_wire_o_tri[3]),
      .Y (chipout)
  );
  BUFZ out_buf_e (
      .A (inter_wire_o_out[3]),
      .OE(inter_wire_o_tri[3]),
      .Y (chipout)
  );
  BUFZ out_buf_f (
      .A (inter_wire_o_out[3]),
      .OE(inter_wire_o_tri[3]),
      .Y (chipout)
  );
`else
  assign chipout = ~t ? o : 1'bz;
`endif

endmodule

// Open Source Note:
// We are unable to provide the exact z-buffer cells we use when compiling this model for synthesis.
// You may assume that a standard cell of adequate drive strength is used where appropriate.
module BUFZ(input logic A, input logic OE, output logic Y);
    assign Y = (OE) ? 'z : A;
endmodule
