import mmmu_types::*;
logic clk;
logic rst;

logic rst_f;

logic       [31:0] dbus_i;  // Input
logic       [31:0] dbus_o;  // Output the tb drives
logic       [31:0] dbus_o_f;  // actual Output
logic       [31:0] dbus_t;   // tristate toggle tb drives
logic       [31:0] dbus_t_f; // the actual tristate toggle (0 means drive)



logic       [31:0] rl_dbus_o;
logic       [31:0] rl_dbus_t;

dbus_pkt_cyc0_t cast_off, cast_off_r;

semaphore lock;
logic dbus_drv_lock;
initial lock = new(1);
initial dbus_drv_lock = 0;



bridge_state_t fsm, fsm_next, fsm_obs;
int         num_data_cycles;

logic winner;
dbus_meta_t req_type;

// We need to keep track of these CSRs so as to know when the bridge
// transitions
logic [8:0] spm_in_len, spm_out_len;


// Global assignments
assign clk = top_clk;
assign rst = top_reset;
assign cast_off = dbus_pkt_cyc0_t'(dbus_i);
assign fsm_obs = bridge_state_t'(test_mmmu_fsm);

always_ff @(posedge clk) cast_off_r <= cast_off;

always_ff @(negedge clk) begin
 fsm <= fsm_next;
 rst_f <= rst;
end

always_ff @(posedge clk) begin
  if (fsm == POLL) begin
    // NOTE: What if there is no off_chip req?
    req_type <= (cast_off.off_chip_req) ? cast_off.off_chip_meta : cast_off.on_chip_meta;
  end else begin
    if (fsm inside {SCLR, MCLR}) begin
      unique case (req_type)
        (SPMLEN_spm_write): begin
          num_data_cycles <= spm_in_len+1;
        end
        (SPMLEN_spm_wb): begin
          num_data_cycles <= spm_out_len+1;
        end
        (csr_write): begin
          num_data_cycles <= 1;
        end
        (csr_rd_req): begin
          num_data_cycles <= '0;
        end
        (csr_rd_resp): begin
          num_data_cycles <= 1;
        end
        (cacheline_rd_req): begin
          num_data_cycles <= '0;
        end
        (cacheline_rd_resp): begin
          num_data_cycles <= 4;
        end
        (cacheline_wb): begin
          num_data_cycles <= 4;
        end
        (no_meta) : begin
          `wdisplay("[error] FSM maintainer has latched no meta for state transition atr %t", $time);
          $fatal;
        end
        default: begin
          `wdisplay("[error] FSM maintainer has latched default for state transition atr %t", $time);
          // $fatal;
        end
      endcase
    end else if (fsm inside {SDATA, MDATA}) begin
      num_data_cycles <= num_data_cycles -1;
    end
  end
end

always_comb begin
 // Contention decider block
 // set the data length
 if (cast_off_r.on_chip_req && !cast_off_r.off_chip_req) begin
   winner = 0;
 end else if (!cast_off_r.on_chip_req && cast_off_r.off_chip_req) begin
   winner = 1;
 end else begin
   winner = 1; // NOTE: STATIC PRIORITY SCHEME
 end
end



always_ff @(negedge clk) begin
  if (rst) begin
    dbus_t_f <= 32'h0000ffff;
    dbus_o_f <= {1'b0, 31'bx};
  end else begin
    dbus_o_f <= dbus_drv_lock ? dbus_o : {1'b0, 31'b0};
    dbus_t_f <= dbus_t;
  end
end


assign rl_dbus_o = (rst||rst_f) ? '0 : dbus_o_f;
assign rl_dbus_t = (rst) ? '0 : dbus_t_f;

io_tri dbus_drvr_wrap[31:0] (
    .chipout(dbus_TRI), // this goes to the top level module - inout wire
    .i(dbus_i), // read from this
    .o(rl_dbus_o), // drive this
    .t(rl_dbus_t)  // toggle this
);

// Tasks
task automatic fsm_maintainer();
  // fsm_next <= POLL;
  @ (negedge clk);
  @ (negedge clk);
  if (rst!=1) begin
    `wdisplay("FSM Maintainer invoked outside of rst");
    $fatal;
  end
endtask

always_comb begin
  unique case (fsm)
    (POLL): begin
      if (rst) begin
        fsm_next = POLL;
        dbus_t = 'hFFFF;
      end else if (winner && cast_off_r.off_chip_req != no_meta) begin
        fsm_next = MCLR;
        dbus_t = '1;
      end else if(!winner && cast_off_r.on_chip_req != no_meta) begin
        fsm_next = SCLR;
        dbus_t = '1;
      end else begin
        fsm_next = POLL;
        dbus_t = 'hFFFF;
      end
    end
    (MCLR): begin
      fsm_next = MADDR;
      dbus_t = '0;
    end
    (MADDR): begin
      fsm_next = (num_data_cycles == 0) ? FCLR : MDATA;
      dbus_t = (num_data_cycles == 0) ? '1 : '0;
    end
    (MDATA): begin
      fsm_next = (num_data_cycles == 0) ? FCLR : MDATA;
      dbus_t   = (num_data_cycles == 0) ? '1 : '0;
    end
    (SCLR): begin
      fsm_next = SADDR;
      dbus_t = '1;
    end
    (SADDR): begin
      fsm_next = (num_data_cycles == 0) ? FCLR : SDATA;
      dbus_t = '1;
    end
    (SDATA): begin
      fsm_next = (num_data_cycles == 0) ? FCLR : SDATA;
      dbus_t = '1;
    end
    (FCLR): begin
      fsm_next = POLL;
      dbus_t = 'hFFFF;
    end
    default: begin
      if (rst) begin
        fsm_next = POLL;
      end else begin
        `wdisplay("Default experienced %t", $time);
        $fatal;
      end
    end
    endcase
end


task automatic drive_dbus (
   input dbus_meta_t trans_type,
   input logic [31:0] trans_data[], // addr goes inside this
   input int unsigned trans_len
);
    int log_tag;
    dbus_pkt_cyc0_t handshake_packet;
    assert(std::randomize(log_tag));
    `wdisplay("[%x] Acquiring semaphore for %s at %t", log_tag, trans_type.name(), $time);
    lock.get(1);
    `wdisplay("[%x] Acquired semaphore at %t", log_tag, $time);

    dbus_drv_lock <= '1;
    handshake_packet.off_chip_meta = trans_type;
    handshake_packet.off_chip_req  = '1;
    dbus_o <= handshake_packet;

    while (fsm_next != MCLR) @(negedge clk);
    // Now in MCLR
    dbus_o <= trans_data[0];

    @ (negedge clk);
    // Now in MADDR, we own the bus for the next trans_len cycles
    if (trans_len > 1) begin // go write data if there is any
      for (int i =0; i < trans_len-1; i++) begin
        dbus_o <= trans_data[i+1];
        @ (negedge clk);
      end
    end

    // next state is FCLR
    dbus_o <= 32'h00000000;
    @(negedge clk);

    // Next state is poll
    `wdisplay("[%x] Releasing semaphore at %t", log_tag, $time);
    dbus_drv_lock <= '0;
    lock.put(1);
endtask

task automatic lsn_dbus_wb(output logic [31:0] data[]);
  int log_tag;
  data = new [5];
  assert(std::randomize(log_tag));
  `wdisplay("[%x] DBUS listener for %s at %t", log_tag, "cacheline_wb", $time);

  while ((fsm != POLL) ||
         (!cast_off.on_chip_req) || (cast_off.off_chip_req) ||
         (cast_off.on_chip_meta != cacheline_wb))
    @(posedge clk);
  // FSM currently in POLL

  @(posedge clk);
  // FSM currently in m/s FCLR

  @(posedge clk)
    // FsM currently in m/s addr
    if (!(fsm inside {MADDR, SADDR})) begin
      `wdisplay("[%x] DBUS listener woke up in the wrong state at %t", log_tag, $time);
      $fatal;
    end
  data[0] = dbus_i; // pull out the addr

  // We get the currect match, fsm currently in m/SADDR
  @(posedge clk);
  // Now in data cycles
  for (int i =1; i < 5; i++) begin
    if (!(fsm inside {MDATA, SDATA})) begin
      `wdisplay("[%x] Listen DBUS called with trasnsaction length longer than supported %t", log_tag, $time);
      $fatal;
    end
    data[i] = dbus_i;
    @(posedge clk);
  end

  `wdisplay("[%x] DBUS listener for %s completed at %t", log_tag, "cacheline_wb", $time);
endtask

task automatic lsn_dbus_cacheline_rd(output logic [31:0] data[]);
  int log_tag;
  data = new [1];
  assert(std::randomize(log_tag));
  `wdisplay("[%x] DBUS listener for %s at %t", log_tag, "cacheline_req", $time);

  while ((fsm != POLL) ||
         (!cast_off.on_chip_req) || (cast_off.off_chip_req) ||
         (cast_off.on_chip_meta != cacheline_rd_req))
    @(posedge clk);
  // FSM currently in POLL

  @(posedge clk);
  // FSM currently in m/s FCLR

  @(posedge clk)
  // FsM currently in m/s addr
  if (!(fsm inside {MADDR, SADDR})) begin
    `wdisplay("[%x] DBUS listener woke up in the wrong state at %t", log_tag, $time);
    $fatal;
  end

  data[0] = dbus_i; // pull out the addr
  `wdisplay("[%x] DBUS listener for %s completed at %t", log_tag, "cacheline_rd", $time);
endtask

task automatic lsn_dbus(
  input dbus_meta_t req_type_snoop,
  input logic [31:0] addr,
  input int trans_len,
  output logic [31:0] data[]
  );

  int log_tag;
  data = new [trans_len];
  assert(std::randomize(log_tag));
  `wdisplay("[%x] DBUS listener for %s at %t", log_tag, req_type_snoop.name(), $time);

  while(1) begin
    while ((fsm != POLL) ||
           (!cast_off.on_chip_req) || (cast_off.off_chip_req) ||
           (cast_off.on_chip_meta != req_type_snoop))
      @(posedge clk);
    // FSM currently in POLL

    @(posedge clk);
    // FSM currently in m/s FCLR

    @(posedge clk)
    // FsM currently in m/s addr
    if (!(fsm inside {MADDR, SADDR})) begin
      `wdisplay("[%x] DBUS listener woke up in the wrong state at %t", log_tag, $time);
      $fatal;
    end
    if (dbus_i != addr) begin
      // Addr mismatch so this is not our request
      continue;
    end

    // We get the currect match, fsm currently in m/SADDR
    @(posedge clk);
    // Now in data cycles
    for (int i =0; i < trans_len; i++) begin
      if (!(fsm inside {MDATA, SDATA})) begin
        `wdisplay("[%x] Listen DBUS called with trasnsaction length longer than supported %t", log_tag, $time);
        $fatal;
      end
      data[i] = dbus_i;
      @(posedge clk);
    end
    break;
  end

  @(negedge clk);

  `wdisplay("[%x] DBUS listener for %s completed at %t", log_tag, req_type_snoop.name(), $time);
endtask

