module pe_rf
    import pe_types::*;
(
    input logic clk,

    input logic         rf_we[4],
    input rf_reg        rd   [4],
    input logic  [31:0] rd_v [4],

    input rf_reg rs[4],

    output logic [31:0] rs_v[4]
);

    logic [31:0] data[4][8];

    always_ff @(posedge clk) begin
        // I know for loops exist but since I'm relying on DC to do the work here I'm being explicit.
        if (rf_we[0]) begin
            data[0][rd[0][2:0]] <= rd_v[0];
        end
        if (rf_we[1]) begin
            data[1][rd[1][2:0]] <= rd_v[1];
        end
        if (rf_we[2]) begin
            data[2][rd[2][2:0]] <= rd_v[2];
        end
        if (rf_we[3]) begin
            data[3][rd[3][2:0]] <= rd_v[3];
        end

        for (int i = 0; i < 4; i++) begin
            rs_v[i] <= data[rs[i][4:3]][rs[i][2:0]];
        end
    end

endmodule
