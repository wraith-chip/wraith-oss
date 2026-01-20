import glbl_pkg::*;

logic sfin, kfin;



logic [3:0] pkt_id;

logic pid_sel, fifo_in_sel, fifo_out_sel, wb_en;

logic [31:0] rvtu0_addr, rvtu1_addr;


logic [31:0] mem_buf[];

initial spm_in_len = '0;
initial spm_out_len = '0;
initial pkt_id= '0;
initial pid_sel = '0;
initial fifo_in_sel= '0;
initial fifo_out_sel= '0;
initial wb_en= '0;
initial rvtu0_addr = '0;
initial rvtu1_addr = '0;

// --- CSR read requests ---
task automatic csr_read_spm_pkt_strm_fin(
  output logic fin
  );

  logic [31:0] csr_addr;
  logic [31:0] trans_data[] = new [1];
  logic [31:0] rd_req_resp[1];
  csr_addr = {29'b0, 1'b1, 2'b00};
  csr_addr[MMIO_CSR_SELECT_BITIDX] = '1;
  // int trans_data;
  trans_data[0]= csr_addr;
  //`wdisplay("[debug] Called CSR rd_req (SPM_PKT_STRM_FIN) at %t", $time);
  //`wdisplay("[debug] Addr is %32b", csr_addr);

  drive_dbus(csr_rd_req, trans_data, 1);

  //`wdisplay("[debug] waiting for dbus resp \n");

  // Now we wait and listen for a response
  @(posedge clk);
  lsn_dbus(csr_rd_resp, csr_addr, 1, rd_req_resp);
  @(negedge clk);

  fin = rd_req_resp[0][1];
endtask

task automatic csr_read_spm_kernel_fin(
  output logic fin
  );
  logic [31:0] csr_addr;
  logic [31:0] trans_data[] = new [1];
  logic [31:0] rd_req_resp[1];
  csr_addr = {29'b0, 1'b1, 2'b00};
  csr_addr[MMIO_CSR_SELECT_BITIDX] = '1;
  // int trans_data;
  trans_data[0]= csr_addr;
  //`wdisplay("[debug] Called CSR rd_req (SPM_KERNEL_FIN) at %t \n", $time);
  drive_dbus(csr_rd_req, trans_data, 1);

  //`wdisplay("[debug] waiting for dbus resp \n");

  // Now we wait and listen for a response
  @(posedge clk);
  lsn_dbus(csr_rd_resp, csr_addr, 1, rd_req_resp);
  @(negedge clk);
  //`wdisplay("PGBUH %8x", rd_req_resp[0]);
  fin = rd_req_resp[0][0];
endtask

task automatic csr_read_spm_in_len(
  output logic [8:0] length
  );
  logic [31:0] csr_addr;
  logic [31:0] trans_data[] = new [1];
  logic [31:0] rd_req_resp[1];
  csr_addr = {29'b0, 1'b0, 2'b00};
  csr_addr[MMIO_CSR_SELECT_BITIDX] = '1;
  // int trans_data;
  trans_data[0]= csr_addr;
  //`wdisplay("[debug] Called CSR rd_req (SPM_IN_LEN) at %t \n", $time);
  //`wdisplay("[xdebug] %32b\n", csr_addr);
  drive_dbus(csr_rd_req, trans_data, 1);

  //`wdisplay("[debug] waiting for dbus resp \n");

  // Now we wait and listen for a response
  @(posedge clk);
  lsn_dbus(csr_rd_resp, csr_addr, 1, rd_req_resp);
  @(negedge clk);
  length= rd_req_resp[0][8+$clog2(SPM_BANK_SIZE)-1:8];
endtask

task automatic csr_read_spm_out_len(
  output logic [8:0] length
  );
  logic [31:0] csr_addr;
  logic [31:0] trans_data[] = new [1];
  logic [31:0] rd_req_resp[1];
  csr_addr = {29'b0, 1'b0, 2'b00};
  csr_addr[MMIO_CSR_SELECT_BITIDX] = '1;
  // int trans_data;
  trans_data[0]= csr_addr;
  //`wdisplay("[debug] Called CSR rd_req (SPM_OUT_LEN) at %t \n", $time);
  drive_dbus(csr_rd_req, trans_data, 1);

  //`wdisplay("[debug] waiting for dbus resp \n");

  // Now we wait and listen for a response
  @(posedge clk);
  lsn_dbus(csr_rd_resp, csr_addr, 1, rd_req_resp);
  @(negedge clk);

  length= rd_req_resp[0][8+2*$clog2(SPM_BANK_SIZE)-1:8+$clog2(SPM_BANK_SIZE)];
endtask

task automatic csr_read_spm_pkt_id(
  output logic [3:0]  pkt_id
  );
  logic [31:0] csr_addr;
  logic [31:0] trans_data[] = new [1];
  logic [31:0] rd_req_resp[1];
  csr_addr = {29'b0, 1'b0, 2'b00};
  csr_addr[MMIO_CSR_SELECT_BITIDX] = '1;
  // int trans_data;
  trans_data[0]= csr_addr;
  //`wdisplay("[debug] Called CSR rd_req (SPM_PKT_ID) at %t \n", $time);
  drive_dbus(csr_rd_req, trans_data, 1);  

  //`wdisplay("[debug] waiting for dbus resp \n");

  // Now we wait and listen for a response
  @(posedge clk);
  lsn_dbus(csr_rd_resp, csr_addr, 1, rd_req_resp);
  @(negedge clk);

  pkt_id= rd_req_resp[0][7:4];
endtask

task automatic csr_read_spm_pid_sel(
  output logic pid_sel 
  );
  logic [31:0] csr_addr;
  logic [31:0] trans_data[] = new [1];
  logic [31:0] rd_req_resp[1];
  csr_addr = {29'b0, 1'b0, 2'b00};
  csr_addr[MMIO_CSR_SELECT_BITIDX] = '1;
  // int trans_data;
  trans_data[0]= csr_addr;
  //`wdisplay("[debug] Called CSR rd_req at (SPM_PID_SEL) %t \n", $time);
  drive_dbus(csr_rd_req, trans_data, 1);  

  //`wdisplay("[debug] waiting for dbus resp \n");

  // Now we wait and listen for a response
  @(posedge clk);
  lsn_dbus(csr_rd_resp, csr_addr, 1, rd_req_resp);
  @(negedge clk);
  pid_sel = rd_req_resp[0][3];
endtask

task automatic csr_read_spm_in_fifo_sel(
  output logic fifo_sel 
  );
  logic [31:0] csr_addr;
  logic [31:0] trans_data[] = new [1];
  logic [31:0] rd_req_resp[1];
  csr_addr = {29'b0, 1'b0, 2'b00};
  csr_addr[MMIO_CSR_SELECT_BITIDX] = '1;
  // int trans_data;
  trans_data[0]= csr_addr;
  //`wdisplay("[debug] Called CSR rd_req (SPM_FIFO_SEL_IN) at %t \n", $time);
  drive_dbus(csr_rd_req, trans_data, 1);  

  //`wdisplay("[debug] waiting for dbus resp \n");

  // Now we wait and listen for a response
  @(posedge clk);
  lsn_dbus(csr_rd_resp, csr_addr, 1, rd_req_resp);
  @(negedge clk);

  fifo_sel = rd_req_resp[0][0];
endtask

task automatic csr_read_spm_out_fifo_sel(
  output logic fifo_sel
  );
  logic [31:0] csr_addr;
  logic [31:0] trans_data[] = new [1];
  logic [31:0] rd_req_resp[1];
  csr_addr = {29'b0, 1'b0, 2'b00};
  csr_addr[MMIO_CSR_SELECT_BITIDX] = '1;
  // int trans_data;
  trans_data[0]= csr_addr;
  //`wdisplay("[debug] Called CSR rd_req (SPM_FIFO_SEL_OUT) at %t \n", $time);
  drive_dbus(csr_rd_req, trans_data, 1);

  //`wdisplay("[debug] waiting for dbus resp \n");

  // Now we wait and listen for a response
  @(posedge clk);
  lsn_dbus(csr_rd_resp, csr_addr, 1, rd_req_resp);
  @(negedge clk);

  fifo_sel = rd_req_resp[0][1];
endtask

task automatic csr_read_rvtu0_completion(
  output logic fin
);
  logic [31:0] csr_addr;
  logic [31:0] trans_data[] = new [1];
  logic [31:0] rd_req_resp[1];
  csr_addr = {29'b0, 1'b1, 2'b01};
  csr_addr[MMIO_CSR_SELECT_BITIDX] = '1;
  // int trans_data;
  trans_data[0]= csr_addr;
  `wdisplay("[debug] Called CSR rd_req (RVTU0_HALT) at %t \n", $time);

  drive_dbus(csr_rd_req, trans_data, 1);

  // Now we wait and listen for a response
  @(posedge clk);
  lsn_dbus(csr_rd_resp, csr_addr, 1, rd_req_resp);
  @(negedge clk);

  fin = rd_req_resp[0][0];
endtask

task automatic csr_read_rvtu1_completion(
  output logic fin
);
  logic [31:0] csr_addr;
  logic [31:0] trans_data[] = new [1];
  logic [31:0] rd_req_resp[1];
  csr_addr = {29'b0, 1'b1, 2'b10};
  csr_addr[MMIO_CSR_SELECT_BITIDX] = '1;
  // int trans_data;
  trans_data[0]= csr_addr;
  `wdisplay("[debug] Called CSR rd_req (RVTU1_HALT) at %t \n", $time);
  drive_dbus(csr_rd_req, trans_data, 1);

  //`wdisplay("[debug] waiting for dbus resp \n");

  // Now we wait and listen for a response
  @(posedge clk);
  lsn_dbus(csr_rd_resp, csr_addr, 1, rd_req_resp);
  @(negedge clk);

  //`wdisplay("[debug] Received CSR rd_resp (RVTU0_HALT) at %t", $time);
  fin = rd_req_resp[0][0];
endtask

task automatic csr_read_rvtu_pc_init(
  output logic [31:0] addr
  );
  // TODO
endtask

// --- CSR write requests ---

task automatic csr_program_spm_in_len(
  input logic [8:0] length
  );
  logic [31:0] csr_data;
  logic [31:0] csr_addr;
  logic [31:0] trans_data[2];
  spm_in_len = length; // set the dbg guy
  csr_data = {10'b0, spm_out_len, length, pkt_id, pid_sel, wb_en, fifo_out_sel, fifo_in_sel};
  csr_addr = {29'b0, 1'b0, 2'b00};
  csr_addr[MMIO_CSR_SELECT_BITIDX] = '1;

  // int trans_data;
  trans_data[0]= csr_addr;
  trans_data[1] = csr_data;
  //`wdisplay("[debug] Called CSR Prog SPM In Length at %t", $time);
  //`wdisplay("[debug] Addr is %32b", csr_addr);
  //`wdisplay("[debug] Data is %32b \n", csr_data);
  drive_dbus(csr_write, trans_data, 2);
endtask

task automatic csr_program_spm_out_len(
  input logic [8:0] length
  );
  logic [31:0] csr_data;
  logic [31:0] csr_addr;
  logic [31:0] trans_data[2];
  spm_out_len = length; // set the dbg guy
  csr_data = {10'b0, length, spm_in_len, pkt_id, pid_sel, wb_en, fifo_out_sel, fifo_in_sel};
  csr_addr = {29'b0, 1'b0, 2'b00};
  csr_addr[MMIO_CSR_SELECT_BITIDX] = '1;
  // int trans_data;
  trans_data[0]= csr_addr;
  trans_data[1] = csr_data;
  //`wdisplay("[debug] Called CSR Prog SPM OUT Length at %t", $time);
  //`wdisplay("[debug] Addr is %32b", csr_addr);
  //`wdisplay("[debug] Data is %32b \n", csr_data);
  drive_dbus(csr_write, trans_data, 2);
endtask

task automatic csr_program_spm_pkt_id(
  input logic [3:0] _pkt_id
  );
  logic [31:0] csr_data;
  logic [31:0] csr_addr;
  logic [31:0] trans_data[2];
  pkt_id = _pkt_id; // set the dbg guy
  csr_data = {10'b0, spm_out_len, spm_in_len, _pkt_id, pid_sel, wb_en, fifo_out_sel, fifo_in_sel};
  csr_addr = {29'b0, 1'b0, 2'b00};
  csr_addr[MMIO_CSR_SELECT_BITIDX] = '1;

  // int trans_data;
  trans_data[0]= csr_addr;
  trans_data[1] = csr_data;
  //`wdisplay("[debug] Called CSR Prog SPM PKT ID at %t", $time);
  //`wdisplay("[debug] Addr is %32b", csr_addr);
  //`wdisplay("[debug] Data is %32b \n", csr_data);
  drive_dbus(csr_write, trans_data, 2);
endtask

task automatic csr_program_spm_pid_sel(
  input logic _pid_sel 
  );
  logic [31:0] csr_data;
  logic [31:0] csr_addr;
  logic [31:0] trans_data[2];
  pid_sel = _pid_sel; // set the dbg guy
  csr_data = {10'b0, spm_out_len, spm_in_len, pkt_id, _pid_sel, wb_en, fifo_out_sel, fifo_in_sel};
  csr_addr = {29'b0, 1'b0, 2'b00};
  csr_addr[MMIO_CSR_SELECT_BITIDX] = '1;

  // int trans_data;
  trans_data[0]= csr_addr;
  trans_data[1] = csr_data;
  //`wdisplay("[debug] Called CSR Prog SPM PID Select at %t", $time);
  // //`wdisplay("[debug] %32b %32b \n", trans_data[0], trans_data[1]);
  //`wdisplay("[debug] Addr is %32b", csr_addr);
  //`wdisplay("[debug] Data is %32b \n", csr_data);
  drive_dbus(csr_write, trans_data, 2);
endtask

task automatic csr_program_spm_wb_en(
  input logic _wb_en
  );
  logic [31:0] csr_data;
  logic [31:0] csr_addr;
  logic [31:0] trans_data[2];
  wb_en = _wb_en; // set the dbg guy
  csr_data = {10'b0, spm_out_len, spm_in_len, pkt_id, pid_sel, _wb_en, fifo_out_sel, fifo_in_sel};
  csr_addr = {29'b0, 1'b0, 2'b00};
  csr_addr[MMIO_CSR_SELECT_BITIDX] = '1;

  // int trans_data;
  trans_data[0]= csr_addr;
  trans_data[1] = csr_data;
  //`wdisplay("[debug] Called CSR Prog SPM WB Enable at %t", $time);
  // //`wdisplay("[debug] %32b %32b \n", trans_data[0], trans_data[1]);
  //`wdisplay("[debug] Addr is %32b", csr_addr);
  //`wdisplay("[debug] Data is %32b \n", csr_data);
  drive_dbus(csr_write, trans_data, 2);  
endtask


task automatic csr_program_spm_in_fifo_sel(
  input logic fifo_sel
  );
  logic [31:0] csr_data;
  logic [31:0] csr_addr;
  logic [31:0] trans_data[2];
  fifo_in_sel = fifo_sel; // set the dbg guy
  csr_data = {10'b0, spm_out_len, spm_in_len, pkt_id, pid_sel, wb_en, fifo_out_sel, fifo_sel};
  csr_addr = {29'b0, 1'b0, 2'b00};
  csr_addr[MMIO_CSR_SELECT_BITIDX] = '1;

  // int trans_data;
  trans_data[0]= csr_addr;
  trans_data[1] = csr_data;
  //`wdisplay("[debug] Called CSR Prog FIFO_IN select at %t", $time);
  // //`wdisplay("[debug] %32b %32b \n", trans_data[0], trans_data[1]);
  //`wdisplay("[debug] Addr is %32b", csr_addr);
  //`wdisplay("[debug] Data is %32b \n", csr_data);
  drive_dbus(csr_write, trans_data, 2);  
endtask

task automatic csr_program_spm_out_fifo_sel(
  input logic fifo_sel 
  );
  logic [31:0] csr_data;
  logic [31:0] csr_addr;
  logic [31:0] trans_data[2];
  fifo_out_sel = fifo_sel; // set the dbg guy
  csr_data = {10'b0, spm_out_len, spm_in_len, pkt_id, pid_sel, wb_en, fifo_sel, fifo_in_sel};
  csr_addr = {29'b0, 1'b0, 2'b00};
  csr_addr[MMIO_CSR_SELECT_BITIDX] = '1;

  // int trans_data;
  trans_data[0]= csr_addr;
  trans_data[1] = csr_data;

  //`wdisplay("[debug] Called CSR Prog FIFO_out select at %t", $time);
  // //`wdisplay("[debug] %32b %32b \n", trans_data[0], trans_data[1]);
  //`wdisplay("[debug] Addr is %32b", csr_addr);
  //`wdisplay("[debug] Data is %32b \n", csr_data);
  drive_dbus(csr_write, trans_data, 2);
endtask


task automatic csr_program_rvtu_pc_init(
  input logic [31:0]  pc_addr,
  input logic rvtu_num
  );
  // TODO @ (Someone) : once RVTU PC Init CSRs have been implemented
endtask

