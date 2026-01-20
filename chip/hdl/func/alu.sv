module alu
    import func_types::*;

(
    input  logic [ 3:0] aluop,
    input  logic [31:0] a,
    b,
    output logic [31:0] f
);

    logic signed   [31:0] as;
    logic signed   [31:0] bs;
    logic unsigned [31:0] au;
    logic unsigned [31:0] bu;

    assign as = signed'(a);
    assign bs = signed'(b);
    assign au = unsigned'(a);
    assign bu = unsigned'(b);

    always_comb begin
        unique case (aluop)
            alu_op_add: f = au + bu;
            alu_op_sll: f = au << bu[4:0];
            alu_op_sra: f = unsigned'(as >>> bu[4:0]);
            alu_op_sub: f = au - bu;
            alu_op_xor: f = au ^ bu;
            alu_op_srl: f = au >> bu[4:0];
            alu_op_or: f = au | bu;
            alu_op_and: f = au & bu;
            alu_op_slt: f = as < bs ? 32'd1 : 32'b0;
            alu_op_sltu: f = au < bu ? 32'd1 : 32'b0;
            default: f = 'x;
        endcase
    end
endmodule

module alu_shiftless
    import func_types::*;

(
    input  logic [ 3:0] aluop,
    input  logic [31:0] a,
    b,
    output logic [31:0] f
);

    logic signed   [31:0] as;
    logic signed   [31:0] bs;
    logic unsigned [31:0] au;
    logic unsigned [31:0] bu;

    assign as = signed'(a);
    assign bs = signed'(b);
    assign au = unsigned'(a);
    assign bu = unsigned'(b);

    always_comb begin
        unique case (aluop)
            alu_op_add: f = au + bu;
            alu_op_sll: f = 'x;
            alu_op_sra: f = 'x;
            alu_op_sub: f = au - bu;
            alu_op_xor: f = au ^ bu;
            alu_op_srl: f = 'x;
            alu_op_or: f = au | bu;
            alu_op_and: f = au & bu;
            alu_op_slt: f = as < bs ? 32'd1 : 32'b0;
            alu_op_sltu: f = au < bu ? 32'd1 : 32'b0;
            default: f = 'x;
        endcase
    end
endmodule

module pe_alu
    import func_types::*;
(
    input  logic [ 2:0] aluop,
    input  logic [31:0] a,
    b,
    output logic [31:0] f
);

    logic signed   [31:0] as;
    logic unsigned [31:0] au;
    logic unsigned [31:0] bu;

    assign as = signed'(a);
    assign au = unsigned'(a);
    assign bu = unsigned'(b);

    always_comb begin
        unique case (aluop)
            alu_pe_op_add: f = au + bu;
            alu_pe_op_sll: f = au << bu[4:0];
            alu_pe_op_sra: f = unsigned'(as >>> bu[4:0]);
            alu_pe_op_sub: f = au - bu;
            alu_pe_op_xor: f = au ^ bu;
            alu_pe_op_srl: f = bu;
            alu_pe_op_or: f  = au | bu;
            alu_pe_op_and: f = au & bu;
            default: f = 'x;
        endcase
    end
endmodule

module pe_alu_shiftless
    import func_types::*;
(
    input  logic [ 2:0] aluop,
    input  logic [31:0] a,
    b,
    output logic [31:0] f
);

    logic unsigned [31:0] au;
    logic unsigned [31:0] bu;

    assign au = unsigned'(a);
    assign bu = unsigned'(b);

    always_comb begin
        unique case (aluop)
            alu_pe_op_add: f = au + bu;
            alu_pe_op_sll: f = 'x;
            alu_pe_op_sra: f = 'x;
            alu_pe_op_sub: f = au - bu;
            alu_pe_op_xor: f = au ^ bu;
            alu_pe_op_srl: f = 'x;
            alu_pe_op_or: f = au | bu;
            alu_pe_op_and: f = au & bu;
            default: f = 'x;
        endcase
    end
endmodule
