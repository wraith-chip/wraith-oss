interface scratchpad_controller_if ();
  // 1=scratchpad controller has request, is ALWAYS be a write request
  logic req_out;
  logic [31:0] dbus_out;

  // MMMU signal to tell the controller that it can request to write data (NOT READ FOR SCRATCHPAD)
  logic bus_ready;
  // MMMU signal to tell the controller that it has chosen its write request, AND it should start sending its addr/data
  logic bus_own_ack;

  // There is data being received for the scratchpad (data to write into scratchpad)
  logic req_in;
  logic [31:0] dbus_in;

  // This modport is provided to the MMMU Arbitrator to provide
  // necessary I/O to interface with scratchpad controller writebacks,
  // and to program the scratchpad memory from off-chip.
  modport mmmu_arb(input req_out, dbus_out, output bus_ready, bus_own_ack, req_in, dbus_in);

  modport spm(input bus_ready, bus_own_ack, req_in, dbus_in, output req_out, dbus_out);
endinterface
