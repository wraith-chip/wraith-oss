module rvtu_tag_array
(
    input logic clk,

    input logic [6:0]   addr,
    input logic [21:0]  wdata,
    input logic         wen,

    output logic [21:0] rdata

);

logic [23:0] array_rdata;
assign rdata = array_rdata[21:0];

rvtu_tag_sram array (
    .Q(array_rdata),
    .CLK(clk),
    .CEN(1'b0), // Always Active
    .WEN(~wen), // Internally invert to active low
    .A(addr),
    .D({2'b0, wdata}),
    .EMA(3'b000),
    .RETN(1'b1)
);

endmodule

// Open Source Note:
// We are unable to provide the exact, cell-level model used for the SRAM
// We have provided a behaviorially equivalent model, although this uses flip-flops internally, and is not suited for synthesis.
module rvtu_tag_sram
(
    output logic [23:0] Q,
    input logic CLK,
    input logic CEN,
    input logic WEN,
    input logic [6:0] A,
    input logic [2:0] EMA,
    input logic RETN,
    input logic [23:0] D
);

    logic [23:0] internal_array [128];

    always_ff @(posedge CLK) begin
        if (!RETN) begin
            D <= 'x;
            for (int i = 0; i < 128; i++) begin
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
