module transacted_memory #(
  parameter logic STALL = '0,
  parameter int MAXWAIT = 1,
  parameter int SEED = 'hECEB0000,
  parameter int BURSTS = 4
) (
  input               clk,
  input               rst,

  input               dfp_read,
  input               dfp_write,
  input [31:0]        dfp_wdata,
  output logic        dfp_ack,

  output logic        dfp_resp,
  output logic [31:0] dfp_rdata
);
  logic rd, wr;
  logic [31:0] addr;
  logic [31:0] mem [logic [31:2]];

  string       memfile0, memfile1;
  int          dummy;

  initial begin
    dummy = $urandom(SEED);
    mem.delete();

    $value$plusargs("SIM_MEMFILE0=%s", memfile0);
    $display("Loading out of %s", memfile0);
    $readmemh(memfile0, mem);

    $value$plusargs("SIM_MEMFILE1=%s", memfile1);
    $display("Loading out of %s", memfile1);
    $readmemh(memfile1, mem);

    dfp_ack <= '0;
    dfp_resp <= '0;
    dfp_rdata <= 'x;

    @(posedge clk iff ~rst);

    while (1) begin
      rd        <= '0;
      wr        <= '0;
      dfp_ack   <= '0;
      dfp_resp  <= '0;
      dfp_rdata <= 'x;

      @(posedge clk iff (dfp_read | dfp_write));

      rd <= dfp_read;
      wr <= dfp_write;

      if (dfp_read & dfp_write) begin
        $error("[err] simultaneous r/w @ %t", $time);
        $finish;
      end

      if (STALL) begin
        automatic int wait1 = $urandom_range(1, MAXWAIT);
        repeat (wait1) @(posedge clk);
      end

      dfp_ack <= '1;
      @(posedge clk);

      dfp_ack <= '0;

      fork
        begin
          while (1) begin
            @(posedge clk);
            if (dfp_read | dfp_write) begin
              $error("[err] IMP violation: rd/wr asserted after ack @ %0t", $time);
              $finish;
            end
          end
        end
      join_none

      @(posedge clk)

      addr <= dfp_wdata;


      if ($isunknown(dfp_wdata[31:2])) begin
        $error("[err] IMP violation: unknown memory address @ %0t", $time);
        $finish;
      end

      if (wr) begin
        repeat (BURSTS) begin
          @(posedge clk);
          mem[addr[31:2]] <= dfp_wdata;
          addr <= addr + 'd4;
        end
      end

      if (rd) begin
        @(posedge clk);
        if (STALL) begin
          automatic int wait2 = $urandom_range(1, MAXWAIT);
          repeat (wait2) @(posedge clk);
        end
        dfp_resp  <= 1;
        dfp_rdata <= addr;
        @(posedge clk);
        repeat (BURSTS) begin
          dfp_rdata <= mem[addr[31:2]];
          addr <= addr + 'd4;
          @(posedge clk);
        end
        dfp_resp <= '0;
      end

      disable fork;
    end
  end
endmodule
