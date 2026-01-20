module rvtu_valid_array
(
    input logic clk,
    input logic rst,

    input logic [6:0]   addr,
    input logic         wdata,
    input logic         wen,

    output logic       rdata

);

logic internal_array [128];

logic [6:0] addr_reg;

always_ff @(posedge clk) begin
    if (rst) begin
        addr_reg <= 'x;
        for (int i = 0; i < 128; i++) begin
            internal_array[i] <= '0;
        end
    end else begin
        if (wen) begin
            internal_array[addr] <= wdata;
        end
        addr_reg <= addr;
    end
end

assign rdata = internal_array[addr_reg];

endmodule
