// This wraps a 1 KiB SRAM, for now (which has writethrough)

module scratchpad_sram_wrapper (
  input logic clk,
  rst,
  scratchpad_bank_if.bank ctrl_if
);
  // SRAM inputs/outputs
  logic CEN;
  logic WEN;
  logic [7:0] A;
  logic [31:0] D, Q;
  logic RETN;
  logic [2:0] EMA;

  basic_1k_sram sram(
    .CLK(clk),
    .WEN(WEN),
    .CEN(CEN),
    .A(A),
    .D(D),
    .Q(Q),
    .RETN(RETN),
    .EMA(EMA)
  );

  logic creq, creq_last;

  assign creq = ctrl_if.ren | ctrl_if.wen;
  always_ff @(posedge clk) begin
    if (rst) creq_last <= '0;
    else creq_last <= creq;
  end

  assign CEN = '0;
  assign WEN = ~ctrl_if.wen;
  assign A = ctrl_if.addr;

  assign RETN = ~rst;
  assign EMA = 3'h0;

  // Drive iface outputs
  assign ctrl_if.rdata = Q;
  assign ctrl_if.rvalid = creq_last; // read is interesting after write, since writethrough

endmodule

// Open Source Note:
// We are unable to provide the exact, cell-level model used for the SRAM
// We have provided a behaviorially equivalent model, although this uses flip-flops internally, and is not suited for synthesis.
module basic_1k_sram
(
    output logic [31:0] Q,
    input logic CLK,
    input logic CEN,
    input logic WEN,
    input logic [7:0] A,
    input logic [2:0] EMA,
    input logic RETN,
    input logic [31:0] D
);

    logic [31:0] internal_array [256];

    always_ff @(posedge CLK) begin
        if (!RETN) begin
            D <= 'x;
            for (int i = 0; i < 256; i++) begin
                internal_array[i] <= 'x;
            end
        end else begin
            if (!CEN) begin
                if (!WEN) begin
                    internal_array[A] <= D;
                end
                D <= internal_array[A];
            end
        end
    end

endmodule
