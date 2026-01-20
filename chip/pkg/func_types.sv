package func_types;

typedef enum logic [3:0] {
    alu_op_add     = 4'b0000,
    alu_op_sll     = 4'b0001,
    alu_op_sra     = 4'b0010,
    alu_op_sub     = 4'b0011,
    alu_op_xor     = 4'b0100,
    alu_op_srl     = 4'b0101,
    alu_op_or      = 4'b0110,
    alu_op_and     = 4'b0111,
    alu_op_slt     = 4'b1000,
    alu_op_sltu    = 4'b1001
} alu_ops;


typedef enum logic [2:0] {
    alu_pe_op_add     = 3'b000,
    alu_pe_op_sll     = 3'b001,
    alu_pe_op_sra     = 3'b010,
    alu_pe_op_sub     = 3'b011,
    alu_pe_op_xor     = 3'b100,
    alu_pe_op_srl     = 3'b101,
    alu_pe_op_or      = 3'b110,
    alu_pe_op_and     = 3'b111
} alu_pe_ops;

typedef enum logic [2:0] {
    mul_op      = 3'b000,
    mul_op_h    = 3'b001,
    mul_op_hsu  = 3'b010,
    mul_op_hu   = 3'b011
} mul_ops;

endpackage
