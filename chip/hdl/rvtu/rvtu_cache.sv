module rvtu_cache (
    input logic          clk,
    input logic          rst,

    // cpu side signals, ufp -> upward facing port
    input logic [31:0]   ufp_addr,
    input logic          ufp_rmask,
    input logic [ 3:0]   ufp_wmask,
    output logic [31:0]  ufp_rdata,
    input logic [31:0]   ufp_wdata,
    output logic         ufp_resp,

    output logic [ 31:0] dfp_addr,
    output logic         dfp_read,
    output logic         dfp_write,
    input [127:0]        dfp_rdata,
    output logic [127:0] dfp_wdata,
    input                dfp_resp
);
  typedef enum logic [1:0] {
    CACHE_STATE_NONE = 2'b00,
    READ = 2'b01,
    WRITE = 2'b10,
    WRITE_STALL = 2'b11
  } cache_state_t;

  // Offset [3:0] (128 bit lines, 16 byte, 4 bits for offset)
  // SetIdx [10:4] (128 sets, 7 bits for set)
  // Tag    [31:11] (21 bits for tag), 22 for sram

  typedef struct packed {
    logic [31:0] addr;
    logic        rmask;
    logic [3:0]  wmask;
    logic [31:0] wdata;
  } cache_stage_t;

  // Control Signals
  logic hit;  // Comb-Driven Hit Control
  logic stall, hold_stall;  // Comb-Driven and Latched Stall Control
  logic wb_en, write_control;  // Comb-Driven Write Control

  cache_state_t       init_state;  // Comb-Driven "Next State"
  cache_state_t       hold_state;  // Latched Current State

  cache_stage_t       cache_init;  // Stage 1 Cache Request Driven from UFP
  cache_stage_t       cache_recv;  // Stage 2 Cache Request Driven from FF
  cache_stage_t       cache_next;  // Selected Cache Request to drive FF


  // Request Signals
  logic [3:0] off_b;  // Stage 2 Offset
  logic [6:0] set_a, set_w, set_b;  // Stage 1/Pre-Write/Stage 2 Set Index,
  logic [20:0] tag_b;  // Stage 2 Tag

  logic is_read, is_write, is_req;
  // SRAM Signals

  // Data Array

  logic [127:0] cache_rdata;
  logic [127:0] cache_wdata;
  logic [ 15:0] cache_wmask;

  logic         cache_web_data;  // Active High web

  // Tag Array

  logic [ 20:0] cache_r_tag;
  logic [ 20:0] cache_w_tag;
  logic         cache_r_dirty;
  logic         cache_w_dirty;

  logic         cache_web_tag;  // Active High web

  // Valid Array

  logic         cache_r_valid;
  logic         cache_w_valid;

  logic         cache_web_valid;  // Active High web


  assign write_control = hold_state == WRITE_STALL | wb_en;

  logic sram_en;

  /*
        STATE LOGIC
        -----------
        If we miss we raise comb-driven stall and write init_state
        hold_stall and hold_state are latched values to be handled by the ff block

        CACHE_STATE_NONE        - Idle or Lookup
        WRITE       - Holds a write request to dfp until dfp_resp
        READ        - Holds a read request to dfp until dfp_resp, updates cache for writing
        WRITE_STALL - A "do nothing" state entered after initiating a cache write, also causes the write-control mux select.

        CACHE_STATE_NONE -> READ -> WRITE_STALL -> CACHE_STATE_NONE          (miss)
        CACHE_STATE_NONE -> WRITE -> READ -> WRITE_STALL -> CACHE_STATE_NONE (evict + miss)
        CACHE_STATE_NONE -> WRITE_STALL -> CACHE_STATE_NONE                  (cache-write)
    */

  always_ff @(posedge clk) begin
    if (rst) begin
      cache_recv <= '0;
      hold_state <= CACHE_STATE_NONE;
      hold_stall <= 1'b0;
    end else begin
      // Update Shadow with next request
      if (hold_state != WRITE_STALL) begin
        cache_recv <= cache_next;
      end

      if (stall) begin
        hold_stall <= 1'b1;
        hold_state <= init_state;
      end else if (hold_state == WRITE && dfp_resp == 1) begin
        hold_state <= READ;
      end else if ((hold_state == READ && dfp_resp == 1) | (hold_state == CACHE_STATE_NONE && wb_en)) begin;
        hold_state <= WRITE_STALL;
      end else if (hold_state == WRITE_STALL) begin
        hold_state <= CACHE_STATE_NONE;
        hold_stall <= 1'b0;
      end
    end
  end

  /*
    *  Initiate Request + Mux Selection
    */

  always_comb begin
    // Assign the Initiate Struct
    cache_init.addr = ufp_addr;
    cache_init.rmask = ufp_rmask;
    cache_init.wmask = ufp_wmask;
    cache_init.wdata = ufp_wdata;

    // Update Cache Next with valid data
    cache_next = (stall | hold_stall | (hold_state == WRITE_STALL && !(stall | hold_stall))) ? cache_recv : cache_init;

    // set_w is the set index post-stall and post-write muxes
    set_w = (write_control) ? cache_recv.addr[10:4] : cache_next.addr[10:4];

    // set_a is the set index post-stall and pre-write muxes
    set_a = cache_next.addr[10:4];
  end


  // Receive Combinational Logic
  always_comb begin
    // Recover Address Info
    tag_b           = cache_recv.addr[31:11];
    set_b           = cache_recv.addr[10:4];
    off_b           = cache_recv.addr[3:0];
    // Reset Controls
    hit             = 1'b0;
    wb_en           = 1'b0;
    stall           = 1'b0;
    init_state      = CACHE_STATE_NONE;
    // Reset Outputs
    ufp_resp        = 1'b0;
    ufp_rdata       = 32'bx;
    dfp_addr        = 32'bx;
    dfp_read        = 1'b0;
    dfp_write       = 1'b0;
    dfp_wdata       = 128'bx;

    // Reset SRAM Update
    cache_wdata     = cache_rdata;
    cache_wmask     = 16'b0;
    cache_web_data  = 1'b0;

    cache_w_dirty   = cache_r_dirty;
    cache_w_tag     = cache_r_tag;
    cache_web_tag   = 1'b0;

    cache_w_valid   = cache_r_valid;
    cache_web_valid = 1'b0;

    is_read         = cache_recv.rmask;
    is_write        = |cache_recv.wmask;
    is_req          = is_read | is_write;

    case (hold_state)
      CACHE_STATE_NONE: begin
        // Lookup Detection
        if (cache_r_valid && cache_r_tag == tag_b && is_req) begin
          if (is_read) begin
            ufp_rdata = cache_rdata[(off_b)*8+:32];
          end
          if (is_write) begin
            cache_wdata[(off_b)*8+:32] = cache_recv.wdata;
            cache_wmask[off_b+:4] = cache_recv.wmask;
            cache_web_data = 1'b1;

            cache_w_dirty = 1'b1;
            cache_web_tag = 1'b1;
            wb_en = 1'b1;
          end
          hit = 1'b1;
        end
        ufp_resp = (hit) ? 1'b1 : 1'b0;
        if (!hit && (is_req)) begin
          // Stall b/c we need to do memory work
          stall = 1'b1;
          // Determine if we need to write-back the evicted way
          if (cache_r_valid && cache_r_dirty) begin
            init_state = WRITE;

            dfp_write  = 1'b1;
            dfp_wdata  = cache_rdata;
            dfp_addr   = {cache_r_tag, set_b, 4'b0};
          end else begin
            init_state = READ;

            dfp_read   = 1'b1;
            dfp_addr   = {tag_b, set_b, 4'b0};
          end
        end
      end
      WRITE: begin
        //Hold a write request to DFP
        dfp_write = 1'b1;
        dfp_wdata = cache_rdata;
        dfp_addr  = {cache_r_tag, set_b, 4'b0};
      end
      READ: begin
        //Hold a read request to DFP
        dfp_read = 1'b1;
        dfp_addr = {tag_b, set_b, 4'b0};

        if (dfp_resp) begin
          wb_en = 1'b1;
          cache_wdata = dfp_rdata;
          cache_web_data = 1'b1;
          cache_wmask = 16'hffff;

          cache_w_tag = tag_b;
          cache_web_tag = 1'b1;
          cache_w_dirty = (is_write) ? 1'b1 : 1'b0;  //redundant?

          cache_w_valid = 1'b1;
          cache_web_valid = 1'b1;
        end
      end
      default: begin
      end
    endcase
  end

  rvtu_data_array u_rvtu_data_array (
      .clk  (clk),
      .addr (set_w),
      .wdata(cache_wdata),
      .wen  (cache_web_data),
      .wmask(cache_wmask),
      .rdata(cache_rdata)
  );

  rvtu_tag_array u_rvtu_tag_array (
      .clk  (clk),
      .addr (set_w),
      .wdata({cache_w_dirty, cache_w_tag}),
      .wen  (cache_web_tag),
      .rdata({cache_r_dirty, cache_r_tag})
  );

  rvtu_valid_array u_rvtu_valid_array (
      .clk  (clk),
      .rst  (rst),
      .addr (set_w),
      .wdata(cache_w_valid),
      .wen  (cache_web_valid),
      .rdata(cache_r_valid)
  );
endmodule
