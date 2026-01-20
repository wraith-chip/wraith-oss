interface rvtu_pair_arb_if ();
  // These signals are required for each RVTU
  logic dfp_read;
  logic dfp_write;
  logic [31:0] dfp_wdata;

  // MMMU signal to tell the RVTU that it has chosen its write/read
  // request, AND to start sending address (data, if necessary)
  logic dfp_ack;

  // Input data from off-chip being piped to RVTU
  logic dfp_rdata_valid;
  logic [31:0] dfp_rdata;

  modport mmmu_arb(
      input dfp_read, dfp_write, dfp_wdata,
      output dfp_ack, dfp_rdata_valid, dfp_rdata
  );

  modport rvtu_pair(
      output dfp_read, dfp_write, dfp_wdata,
      input dfp_ack, dfp_rdata_valid, dfp_rdata
  );

endinterface
