package rv_pkg;
  typedef enum logic [6:0] {
    // OP-RV32 Opcodes
    lui    = 7'b0110111,
    auipc  = 7'b0010111,
    jal    = 7'b1101111,
    jalr   = 7'b1100111,
    br     = 7'b1100011,
    ld     = 7'b0000011,
    st     = 7'b0100011,
    alu    = 7'b0110011,
    aluimm = 7'b0010011
  } rvOpcode_t;

  typedef union packed {
    logic [31:0] word;

    struct packed {
      logic [11:0] imm;
      logic [4:0]  rs1;
      logic [2:0]  funct3;
      logic [4:0]  rd;
      rvOpcode_t   opcode;
    } i;

    struct packed {
      logic [6:0]  funct7;
      logic [4:0]  rs2;
      logic [4:0]  rs1;
      logic [2:0]  funct3;
      logic [4:0]  rd;
      rvOpcode_t   opcode;
    } r;

    struct packed {
      logic [6:0] imm_top;
      logic [4:0]  rs2;
      logic [4:0]  rs1;
      logic [2:0]  funct3;
      logic [4:0]  imm_bot;
      rvOpcode_t   opcode;
    } s;

    struct packed {
      logic [19:0] imm;
      logic [4:0]   rd;
      rvOpcode_t    opcode;
    } j;
  } rvInstrFmt_u;

  typedef enum logic [2:0] {
    ctrl, mem, aluC, mul, div
  } rvOpclass_t;

  typedef enum logic [2:0] {
    beq  = 3'b000,
    bne  = 3'b001,
    blt  = 3'b100,
    bge  = 3'b101,
    bltu = 3'b110,
    bgeu = 3'b111
  } rvBrOp_t;

  typedef enum logic [2:0] {
    lb  = 3'b000,
    lh  = 3'b001,
    lw  = 3'b010,
    lbu = 3'b100,
    lhu = 3'b101
  } rvLdOp_t;

  function automatic logic [31:0] get_lddataproc(rvLdOp_t op, logic [31:0] rdata);
    case (op)
      lb:  return {{25{rdata[7]}}, rdata[6:0]};
      lh:  return {{17{rdata[15]}}, rdata[14:0]};
      lw:  return rdata;
      lbu: return 32'(rdata[7:0]);
      lhu: return 32'(rdata[15:0]);
      default: return 'x;
    endcase
  endfunction

  function automatic logic [3:0] get_ldbasemask(rvLdOp_t op);
    case (op)
      lb:  return 'b0001;
      lh:  return 'b0011;
      lw:  return 'b1111;
      lbu: return 'b0001;
      lhu: return 'b0011;
      default: return 'x;
    endcase
  endfunction

  typedef enum logic [2:0] {
    sb  = 3'b000,
    sh  = 3'b001,
    sw  = 3'b010
  } rvStOp_t;

  function automatic logic [3:0] get_basemask(rvStOp_t op);
    case (op)
      sb: return 4'b0001;
      sh: return 4'b0011;
      sw: return 4'b1111;
      default: return 'x;
    endcase
  endfunction

  typedef enum logic [2:0] {
    add   = 3'b000,
    sllOp = 3'b001,
    slt   = 3'b010,
    sltu  = 3'b011,
    xorOp = 3'b100,
    srlOp = 3'b101,
    orOp  = 3'b110,
    andOp = 3'b111
  } rvAluOp_t;

  typedef struct packed {
    logic [31:0]       iaddr;
    rvInstrFmt_u       idata;

    // Register Content
    logic              req_rs1;
    logic [31:0]       rs1_data;

    logic              req_rs2;
    logic [31:0]       rs2_data;

    logic              req_rd;

    // Steering Bits
    logic              use_pc;
    logic              use_imm;
    rvAluOp_t          fsel;
  } instrPkt_t;

  typedef struct packed {
    logic        req_rd;
    logic [4:0]  rd_addr;
    logic [31:0] ex_out;

    logic        mem;
    rvLdOp_t     fsel;
    logic [31:0] rs2;

    logic        is_halt;
  } exMemPkt_t;

  typedef struct packed {
    logic        req_rd;
    logic [4:0]  rd_addr;
    logic [31:0] rd_wdata;

    logic        is_halt;
  } memWbPkt_t;

  typedef struct packed {
    logic        req_rd;
    logic [4:0]  rd_addr;
    logic [31:0] rd_wdata;
  } skidPkt_t;

  typedef struct packed {
    logic             valid;
    logic [63:0]      ord;
    logic [31:0]      isn;
    logic             trap;
    logic             halt;
    logic             intr;
    logic [1:0]       mode;
    logic [4:0]       rs1;
    logic [4:0]       rs2;
    logic [31:0]      rs1_rdata;
    logic [31:0]      rs2_rdata;
    logic [4:0]       rd;
    logic [31:0]      rd_wdata;
    logic [31:0]      pc_rdata;
    logic [31:0]      pc_wdata;
    logic [31:0]      mem_addr;
    logic [3:0]       mem_rmask;
    logic [3:0]       mem_wmask;
    logic [31:0]      mem_rdata;
    logic [31:0]      mem_wdata;
    logic             mem_extamo;
  } rvfiPkt_t;

  typedef struct packed {
    logic [31:0]      isn;

    logic [4:0]       rs1;
    logic [4:0]       rs2;
    logic [31:0]      rs1_rdata;
    logic [31:0]      rs2_rdata;
    logic [4:0]       rd;
    logic [31:0]      rd_wdata;

    logic [31:0]      pc_rdata;
    logic [31:0]      pc_wdata;

    logic [31:0]      mem_addr;
    logic [31:0]      mem_rdata;
    logic [31:0]      mem_wdata;
 } pipeRvfiPkt_t;

  typedef struct packed {
    logic        valid;
    logic [4:0]  addr;
    logic [31:0] data;
  } fwd_t;

  // some helper functions for logic
  function automatic rvOpclass_t get_opclass(rvInstrFmt_u idata);
    case (rvOpcode_t'(idata[6:0]))
      lui:    return aluC;
      auipc:  return aluC;
      jal:    return ctrl;
      jalr:   return ctrl;
      br:     return ctrl;
      ld:     return mem;
      st:     return mem;
      alu:    return idata[25] ? (idata[14] ? div : mul) : aluC;
      aluimm: return aluC;
    endcase
  endfunction

  function automatic logic [31:0] get_imm(rvInstrFmt_u instr);
    case (rvOpcode_t'(instr[6:0]))
      alu:     return 'x;
      aluimm,
        ld,
        jalr:  return $unsigned(32'($signed(instr.i.imm)));
      st:      return $unsigned(32'($signed({instr.s.imm_top, instr.s.imm_bot})));
      br:      return $unsigned(32'($signed({instr.r.funct7[6], instr.r.rd[0],
                                   instr.r.funct7[5:0], instr.r.rd[4:1], 1'b0})));
      lui,
        auipc: return {instr.j.imm, 12'd0};
      jal:     return $unsigned(32'($signed({instr.j.imm[19], instr.j.imm[7:0],
                                   instr.j.imm[8], instr.j.imm[18:9], 1'b0})));
      default: return 'x;
    endcase
  endfunction
endpackage
