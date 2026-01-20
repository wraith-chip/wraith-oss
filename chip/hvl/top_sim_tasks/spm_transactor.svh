import "DPI-C" function string getenv(input string env_name);
// import glbl_pkg::*;
// import mmmu_types::*;


logic [31:0] cnfg_buf[int];
logic [31:0] cnst_buf[int];
logic [31:0] data_buf[int];
task automatic spm_write_singleton(
  input logic [31:0] dbuf[],
  input logic [9:0] strm_len,
  input logic _fifo_sel_in,
  input logic _fifo_sel_out,
  input logic _pid_sel,
  input logic [3:0] _pkt_id
  );

  // Do CSR writes here
  fifo_in_sel = _fifo_sel_in;
  fifo_out_sel = _fifo_sel_out;
  pid_sel = _pid_sel;
  pkt_id = _pkt_id;

  `wdisplay("[info] SPM Write Singleton invoked \n");
  @(negedge clk);
  csr_program_spm_in_len(strm_len-2); // Do this because strm len is actually num pkts +1

  while (1) begin
    repeat (70) @ (negedge clk);
    csr_read_spm_in_len(spm_in_len);
    if (spm_in_len == strm_len-2) break;
  end

  `wdisplay("[info] SPM Write Singleton CSR Writes complete");
  `wdisplay("[info] SPM Write Singleton - attempting SPM write of length %4d \n", strm_len-1);
  sfin =0;

  @(negedge clk);
  drive_dbus(SPMLEN_spm_write, dbuf, strm_len);

  while (sfin == 0) begin
    repeat (10) @ (negedge clk);
    csr_read_spm_pkt_strm_fin(sfin);
  end

  if (sfin !='1) begin
    `wdisplay("[error] Fork-join completed before packet stream completed \n");
    $fatal;
  end
endtask




task automatic spm_wait_wb();
// This task is what defines top level completion.
// We basically poll the kernel finished CSR.
//
// Once it goes high, we write to wb_enable CSR,
// process incoming DMA stream, and then write that to a buffer
// in memory, and then compare that to the expected memory we expect to see
  string str_path;
  logic [31:0] spm_data [] = new [spm_out_len];
  if (!$value$plusargs("spm_wb_path=%s", str_path)) begin
    `wdisplay("[error] spm_wb_path is not set.");
    $fatal;
  end

  while(kfin == 0) begin
    repeat (20) @ (negedge clk);
    csr_read_spm_kernel_fin(kfin);
  end

  if (kfin !='1) begin
    `wdisplay("[error] Broke out of poll loop before kernel finished\n");
    $fatal;
  end


  `wdisplay("WRITEBACK IS READY AT %t", $time);
  csr_program_spm_wb_en(1);

  // we wait for the wb
  @(posedge clk);
  lsn_dbus(SPMLEN_spm_wb, 32'bx, spm_out_len+1, spm_data);

  // call store file here
  store_file(spm_data, spm_out_len+1, str_path); 
  `wdisplay("[info] Completed Processing SPM_WB. Stream in %s", str_path);
endtask

task automatic mesh_setup();
  string cnfg_path, cnst_path;
  integer cnfg_len, cnst_len, spm_out_len;
  logic [31:0] fr_cnfg_buf[];
  logic [31:0] fr_cnst_buf[];
  // Read plusargs
  if (!$value$plusargs("cnfg_path=%s", cnfg_path)) begin
    `wdisplay("[error] cnfg_path is not set.");
    $fatal;
  end
  if (!$value$plusargs("cnst_path=%s", cnst_path)) begin
    `wdisplay("[error] cnst_path is not set.");
    $fatal;
  end

  $readmemh(cnfg_path, cnfg_buf);
  $readmemh(cnst_path, cnst_buf);
  cnfg_len = cnfg_buf.size();
  cnst_len = cnst_buf.size();
  `wdisplay("[debug] Loaded arrays of size %0d %0d", cnfg_len, cnst_len);

  fr_cnfg_buf = new [cnfg_len+1];
  fr_cnst_buf = new [cnst_len+1];

  for (int i =0; i < cnfg_len; i++) begin
    fr_cnfg_buf[i+1] = cnfg_buf[i];
  end
  for (int i =0; i < cnst_len; i++) begin
    fr_cnst_buf[i+1] = cnst_buf[i];
  end

  spm_write_singleton(fr_cnfg_buf, cnfg_len+1, 0, 1, '0, '0);
  spm_write_singleton(fr_cnst_buf, cnst_len+1, 0, 1, '0, 4'b0001);

  csr_read_spm_in_len(spm_out_len);
endtask

task automatic run_kernel();
  string data_path;
  integer data_len;
  logic [31:0] fr_data_buf[];

  if (!$value$plusargs("data_path=%s", data_path)) begin
    `wdisplay("[error] data_path is not set.");
    $fatal;
  end

  $readmemh(data_path, data_buf);
  data_len = data_buf.size();
  `wdisplay("[debug] Loaded data array of size %0d", data_len);

  fr_data_buf = new [data_len+1];
  for (int i =0; i < data_len; i++) begin
    fr_data_buf[i+1] = data_buf[i];
  end

  spm_out_len = data_len-1;
  // pid_sel = '1;
  spm_write_singleton(fr_data_buf, data_len+1, 1, 0, '1, 4'b0010);
  `wdisplay("SINGLETON STREAM DONE AT %t", $time);
  spm_wait_wb();
endtask
