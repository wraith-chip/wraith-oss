logic [127:0] assoc_mem[logic [31:0]];
int rvtu_mem_fd;

initial begin
  rvtu_mem_fd = $fopen("mem_transaction.log", "w");
end

final begin
  $fclose(rvtu_mem_fd);
end

task automatic handle_cachemiss();
// Load in 2 diff memfiles
// rvtu_mem0_path
// rvtu_mem1_path are teh plusargs with the filepaths
// build one assoc array

// spawn lsn dbus task that listens for any cache miss requests

// when the listen guy returns, create a resp using dbus driver task
//
// loop forever
//
    logic [31:0] phony_data [1];
    logic [31:0] req_addr;
    int idx;
    logic [127:0] req_resp_line;
    logic [31:0] req_resp_data[4+1];
    logic [3:0] fake_wait;
    string rvtu_mem0_path, rvtu_mem1_path;

    // Get the file paths from plusargs
    if (!($value$plusargs("rvtu_mem0_path=%s", rvtu_mem0_path))) begin
        $fatal("Missing rvtu_mem0_path plusarg!");
    end
    if (!($value$plusargs("rvtu_mem1_path=%s", rvtu_mem1_path))) begin
        $fatal("Missing rvtu_mem1_path plusarg!");
    end

  // Load both memory files into the global associative array (simple merge)
  $readmemh(rvtu_mem0_path, assoc_mem);
  $readmemh(rvtu_mem1_path, assoc_mem);

  `wdisplay(assoc_mem);
  `wdisplay(assoc_mem);
    // spawn a dbus listener loop
  fork
    begin
      while (1) begin
        lsn_dbus_cacheline_rd(phony_data);
        req_addr = phony_data[0];

        if ($isunknown(req_addr)) begin
          `wdisplay("[err] unknown memory address @ %t", $time);
          $fatal;
        end

        idx = req_addr / 16;
        req_resp_line = assoc_mem[idx];
        for (int i =0; i <4; i++) begin
          req_resp_data[i+1] = req_resp_line[32*i +: 32];
        end
       req_resp_data[0] = req_addr;
       $fwrite(rvtu_mem_fd, "RD Addr: %8x, Data: %8x %8x %8x %8x\n",
               req_resp_data[0], req_resp_data[1], req_resp_data[2],
               req_resp_data[3], req_resp_data[4]);
        assert(std::randomize(fake_wait));
        repeat(fake_wait) @ (negedge clk);
        @(negedge clk); // drive on negedge
        drive_dbus(cacheline_rd_resp, req_resp_data, 5);

        @(posedge clk); // listen on a posedge
      end
    end
  join_none
endtask

task automatic handler_cachewb();
// spawn lsn dbus task that listens for any cache wb requests
  logic [31:0] flushed_data[5];
  logic [127:0] flushed_line;
  int idx;

// write back the data into asoc array
// output file to cache_wb_path
// rvtu_wb_path plusarg has the filepath
fork
  begin
    while(1) begin
      lsn_dbus_wb(flushed_data);
      $fwrite(rvtu_mem_fd, "WR Addr: %8x, Data: %8x %8x %8x %8x\n",
              flushed_data[0], flushed_data[1], flushed_data[2],
              flushed_data[3], flushed_data[4]);
      for (int i=0; i<4;i++) begin
        flushed_line[32*i +: 32] = flushed_data[i+1];
      end
      idx = flushed_data[0]/16;
      assoc_mem[idx] = flushed_line;
      @(posedge clk);
    end
  end
join_none
endtask

// badly placed block -- could be moved somewhere else
final begin
  automatic string wb_path;
  if (!($value$plusargs("rvtu_wb_path=%s", wb_path))) begin
    $fatal("Missing rvtu_wb_path plusarg!");
  end
  $writememh(wb_path,assoc_mem);
end
