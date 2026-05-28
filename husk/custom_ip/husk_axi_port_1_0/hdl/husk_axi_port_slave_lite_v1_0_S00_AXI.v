
`timescale 1 ns / 1 ps

	module husk_axi_port_slave_lite_v1_0_S00_AXI #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line

		// Width of S_AXI data bus
		parameter integer C_S_AXI_DATA_WIDTH	= 32,
		// Width of S_AXI address bus
		parameter integer C_S_AXI_ADDR_WIDTH	= 6
	)
	(
		// Users to add ports here
		output reg  [C_S_AXI_ADDR_WIDTH-1:0]      port_addr,
		output reg                                  port_rd,
		output reg                                  port_wr,
		output reg  [C_S_AXI_DATA_WIDTH-1:0]       port_wdata,
		output reg  [(C_S_AXI_DATA_WIDTH/8)-1:0]   port_wstrb,
		input  wire [C_S_AXI_DATA_WIDTH-1:0]       port_rdata,
		input  wire                                 port_resp,
		// User ports ends
		// Do not modify the ports beyond this line

		// Global Clock Signal
		input wire  S_AXI_ACLK,
		// Global Reset Signal. This Signal is Active LOW
		input wire  S_AXI_ARESETN,
		// Write address (issued by master, acceped by Slave)
		input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
		// Write channel Protection type.
		input wire [2 : 0] S_AXI_AWPROT,
		// Write address valid.
		input wire  S_AXI_AWVALID,
		// Write address ready.
		output wire  S_AXI_AWREADY,
		// Write data (issued by master, acceped by Slave)
		input wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
		// Write strobes.
		input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
		// Write valid.
		input wire  S_AXI_WVALID,
		// Write ready.
		output wire  S_AXI_WREADY,
		// Write response.
		output wire [1 : 0] S_AXI_BRESP,
		// Write response valid.
		output wire  S_AXI_BVALID,
		// Response ready.
		input wire  S_AXI_BREADY,
		// Read address (issued by master, acceped by Slave)
		input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
		// Protection type.
		input wire [2 : 0] S_AXI_ARPROT,
		// Read address valid.
		input wire  S_AXI_ARVALID,
		// Read address ready.
		output wire  S_AXI_ARREADY,
		// Read data (issued by slave)
		output wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
		// Read response.
		output wire [1 : 0] S_AXI_RRESP,
		// Read valid.
		output wire  S_AXI_RVALID,
		// Read ready.
		input wire  S_AXI_RREADY
	);

	// Bridge state machine
	localparam [2:0] ST_IDLE       = 3'd0,
	                  ST_WAIT_WDATA = 3'd1,
	                  ST_WAIT_WRESP = 3'd2,
	                  ST_WAIT_RRESP = 3'd3,
	                  ST_SEND_BRESP = 3'd4,
	                  ST_SEND_RRESP = 3'd5;

	reg [2:0] state;

	// AXI output registers
	reg                              axi_awready;
	reg                              axi_wready;
	reg                              axi_arready;
	reg [1:0]                        axi_bresp;
	reg                              axi_bvalid;
	reg [1:0]                        axi_rresp;
	reg                              axi_rvalid;
	reg [C_S_AXI_DATA_WIDTH-1:0]    rdata_captured;

	assign S_AXI_AWREADY = axi_awready;
	assign S_AXI_WREADY  = axi_wready;
	assign S_AXI_ARREADY = axi_arready;
	assign S_AXI_BRESP   = axi_bresp;
	assign S_AXI_BVALID  = axi_bvalid;
	assign S_AXI_RDATA   = rdata_captured;
	assign S_AXI_RRESP   = axi_rresp;
	assign S_AXI_RVALID  = axi_rvalid;

	always @(posedge S_AXI_ACLK) begin
	  if (!S_AXI_ARESETN) begin
	    state          <= ST_IDLE;
	    axi_awready    <= 1'b0;
	    axi_wready     <= 1'b0;
	    axi_arready    <= 1'b0;
	    axi_bvalid     <= 1'b0;
	    axi_rvalid     <= 1'b0;
	    axi_bresp      <= 2'b00;
	    axi_rresp      <= 2'b00;
	    port_addr      <= {C_S_AXI_ADDR_WIDTH{1'b0}};
	    port_rd        <= 1'b0;
	    port_wr        <= 1'b0;
	    port_wdata     <= {C_S_AXI_DATA_WIDTH{1'b0}};
	    port_wstrb     <= {(C_S_AXI_DATA_WIDTH/8){1'b0}};
	    rdata_captured <= {C_S_AXI_DATA_WIDTH{1'b0}};
	  end else begin
	    case (state)

	      // ---------------------------------------------------------
	      // IDLE — accept new AXI transaction (write has priority)
	      // ---------------------------------------------------------
	      ST_IDLE: begin
	        axi_awready <= 1'b1;
	        axi_wready  <= 1'b1;
	        axi_arready <= 1'b1;
	        axi_bvalid  <= 1'b0;
	        axi_rvalid  <= 1'b0;
	        port_rd     <= 1'b0;
	        port_wr     <= 1'b0;

	        if (S_AXI_AWVALID && S_AXI_WVALID) begin
	          // Write address + data arrived together
	          port_addr   <= S_AXI_AWADDR;
	          port_wdata  <= S_AXI_WDATA;
	          port_wstrb  <= S_AXI_WSTRB;
	          port_wr     <= 1'b1;
	          axi_awready <= 1'b0;
	          axi_wready  <= 1'b0;
	          axi_arready <= 1'b0;
	          state       <= ST_WAIT_WRESP;
	        end else if (S_AXI_AWVALID) begin
	          // Write address only — still need data
	          port_addr   <= S_AXI_AWADDR;
	          axi_awready <= 1'b0;
	          axi_arready <= 1'b0;
	          state       <= ST_WAIT_WDATA;
	        end else if (S_AXI_ARVALID) begin
	          // Read
	          port_addr   <= S_AXI_ARADDR;
	          port_rd     <= 1'b1;
	          axi_awready <= 1'b0;
	          axi_wready  <= 1'b0;
	          axi_arready <= 1'b0;
	          state       <= ST_WAIT_RRESP;
	        end
	      end

	      // ---------------------------------------------------------
	      // WAIT_WDATA — have address, waiting for write data channel
	      // ---------------------------------------------------------
	      ST_WAIT_WDATA: begin
	        if (S_AXI_WVALID) begin
	          port_wdata <= S_AXI_WDATA;
	          port_wstrb <= S_AXI_WSTRB;
	          port_wr    <= 1'b1;
	          axi_wready <= 1'b0;
	          state      <= ST_WAIT_WRESP;
	        end
	      end

	      // ---------------------------------------------------------
	      // WAIT_WRESP — write issued on simple port, waiting for
	      // external response. port_wr held high.
	      // ---------------------------------------------------------
	      ST_WAIT_WRESP: begin
	        if (port_resp) begin
	          port_wr    <= 1'b0;
	          axi_bvalid <= 1'b1;
	          axi_bresp  <= 2'b00; // OKAY
	          state      <= ST_SEND_BRESP;
	        end
	      end

	      // ---------------------------------------------------------
	      // WAIT_RRESP — read issued on simple port, waiting for
	      // external response. port_rd held high.
	      // ---------------------------------------------------------
	      ST_WAIT_RRESP: begin
	        if (port_resp) begin
	          port_rd        <= 1'b0;
	          rdata_captured <= port_rdata;
	          axi_rvalid     <= 1'b1;
	          axi_rresp      <= 2'b00; // OKAY
	          state          <= ST_SEND_RRESP;
	        end
	      end

	      // ---------------------------------------------------------
	      // SEND_BRESP — hold write response until master accepts
	      // ---------------------------------------------------------
	      ST_SEND_BRESP: begin
	        if (S_AXI_BREADY) begin
	          axi_bvalid <= 1'b0;
	          state      <= ST_IDLE;

            axi_awready <= 1'b1;
            axi_wready  <= 1'b1;
            axi_arready <= 1'b1;
	        end
	      end

	      // ---------------------------------------------------------
	      // SEND_RRESP — hold read data until master accepts
	      // ---------------------------------------------------------
	      ST_SEND_RRESP: begin
	        if (S_AXI_RREADY) begin
	          axi_rvalid <= 1'b0;
	          state      <= ST_IDLE;

            axi_awready <= 1'b1;
            axi_wready  <= 1'b1;
            axi_arready <= 1'b1;
	        end
	      end

	    endcase
	  end
	end

	endmodule
