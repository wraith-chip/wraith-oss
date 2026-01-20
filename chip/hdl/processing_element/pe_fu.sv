module pe_fu
    import pe_types::*;
#(
    parameter int IS_MUL = 0
) (
    input logic   [31:0] a,
    input logic   [31:0] b,
    input fu_func        op,

    output logic [31:0] f
);

    logic [31:0] func_out;

    generate
        if (IS_MUL) begin : gen_fu_MUL
            mul multi (
                .a(a),
                .b(b),
                .mulop(op),
                .f(func_out)
            );
        end else begin : gen_fu_ALU
            pe_alu arith (
                .a(a),
                .b(b),
                .aluop(op),
                .f(func_out)
            );
        end
    endgenerate

    assign f = func_out;
endmodule
