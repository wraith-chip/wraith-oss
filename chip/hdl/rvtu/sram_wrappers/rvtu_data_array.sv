module rvtu_data_array
(
    input logic clk,

    input logic [6:0]   addr,
    input logic [127:0] wdata,
    input logic         wen,
    input logic [15:0]  wmask,

    output logic [127:0] rdata

);


rvtu_data_sram array (
    .Q(rdata),
    .CLK(clk),
    .CEN(1'b0), // Always Active
    .WEN(~wmask), // Internally invert to active low
    .A(addr),
    .D(wdata),
    .EMA(3'b000),
    .GWEN(~wen), // Internally invert to active low
    .RETN(1'b1)
);

endmodule

// Open Source Note:
// We are unable to provide the exact, cell-level model used for the SRAM
// We have provided a behaviorially equivalent model, although this uses flip-flops internally, and is not suited for synthesis.
module rvtu_data_sram
(
    output logic [127:0] Q,
    input logic CLK,
    input logic CEN,
    input logic [15:0] WEN,
    input logic [6:0] A,
    input logic [2:0] EMA,
    input logic GWEN,
    input logic RETN,
    input logic [127:0] D
);

    logic [127:0] internal_array [128];

    always_ff @(posedge CLK) begin
        if (!RETN) begin
            Q <= 'x;
            for (int i = 0; i < 128; i++) begin
                internal_array[i] <= 'x;
            end
        end else begin
            if (!CEN) begin
                if (!GWEN) begin
                    for (int i = 0; i < 16; i++) begin
                        if (!WEN[i]) begin
                            internal_array[A][i +:8] <= D[i +:8];
                        end
                    end
                end
                Q <= internal_array[A];
            end
        end
    end

endmodule
