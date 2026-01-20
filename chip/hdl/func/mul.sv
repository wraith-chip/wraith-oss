module mul
    import func_types::*;
(
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic [ 2:0] mulop,
    output logic [31:0] f
);

    logic signed_mul;
    assign signed_mul = (mulop != mul_op);

    logic signed [32:0] op_a;
    logic signed [32:0] op_b;
    logic signed [63:0] result;

    always_comb begin
        case (mulop)
            mul_op_hu: begin
                op_a = signed'({1'b0, a});
                op_b = signed'({1'b0, b});
            end
            mul_op_hsu: begin
                op_a = signed'({a[31], a});
                op_b = signed'({1'b0, b});
            end
            default: begin
                op_a = signed'({a[31], a});
                op_b = signed'({b[31], b});
            end
        endcase

        result = 64'(op_a * op_b);
    end

    logic [63:0] uf;
    assign uf = $unsigned(result);
    assign f  = (mulop == mul_op) ? uf[31:0] : uf[63:32];

endmodule : mul
