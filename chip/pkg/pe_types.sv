package pe_types;

    // Magic Number Parameters

    localparam int RF_SIZE = 32;
    localparam int RF_BITS = $clog2(RF_SIZE);

    // PE Action Table Size
    localparam int PAT_SIZE = 16;

    // Process ID
    localparam int PID_BITS = 4;


    // This acts as a method to access the ports by name.
    // If our architecture doesn't change then, the most likely port to not exist on any one PE is the East direction
    typedef enum logic [2:0] {
        NORTH = 3'b000,
        WEST  = 3'b001,
        SOUTH = 3'b010,
        EAST  = 3'b011,
        SINK  = 3'b111,
        UDEF  = 'x
    } port_dir_t;

    // Typed Packets or values
    typedef logic [2:0] egress_id;  // No more than 8 destinations?
    typedef logic [PID_BITS-1:0] pid_t;

    typedef logic [RF_BITS-1:0] rf_reg;

    typedef enum logic [2:0] {
        // ALU 1:1
        fu_op_add = 3'b000,
        fu_op_sll = 3'b001,
        fu_op_sra = 3'b010,
        fu_op_sub = 3'b011,
        fu_op_xor = 3'b100,
        fu_op_srl = 3'b101,
        fu_op_or  = 3'b110,
        fu_op_and = 3'b111
    } fu_alu_func;

    // These are kept at the same bitdepth
    typedef enum logic [2:0] {
        fu_op_mul     = 3'b000,
        fu_op_mul_h   = 3'b001,
        fu_op_mul_hsu = 3'b010,
        fu_op_mul_hu  = 3'b011
    } fu_mul_func;

    typedef union packed {
        fu_alu_func alu_op;
        fu_mul_func mul_op;
        // fu_div_func div_op;
    } fu_func;

    typedef struct packed {
        logic src_imm;

        pid_t response_pid;  //4

        logic imm_we;
        logic rf_we;
        rf_reg rd;  //5
        egress_id dest;  //3
        rf_reg src;  //5
        fu_func fu_op;  //3
    } action_table_entry_t;

    typedef struct packed {
        logic                padding;
        action_table_entry_t pat_w_entry;
        logic [3:0]          pat_ind;
        logic [1:0]          y_coord;
        logic [1:0]          x_coord;
    } config_payload_t;

    typedef struct packed {
        logic [22:0] imm;
        rf_reg       rd;
        logic [1:0]  y_coord;
        logic [1:0]  x_coord;
    } const_payload_t;

    typedef union packed {
        config_payload_t conf;
        const_payload_t  cnst;
        logic [31:0]     data;
    } packet_payload_t;

    typedef struct packed {
        pid_t pid;
        packet_payload_t payload;
    } packet_t;
endpackage
