`timescale 1ns / 1ps

module tb_husk_axi_port;

    // -------------------------------------------------------------------------
    // Parameters
    // -------------------------------------------------------------------------
    localparam DATA_WIDTH = 32;
    localparam ADDR_WIDTH = 6;
    localparam CLK_PERIOD = 10;

    // Simulated backend latency in cycles (set to 1 for minimum, >1 to stress-test)
    localparam BACKEND_LATENCY = 2;

    // -------------------------------------------------------------------------
    // DUT Signals
    // -------------------------------------------------------------------------

    reg  s00_axi_aclk    = 0;
    reg  s00_axi_aresetn = 0;

    // Write Address Channel
    reg  [ADDR_WIDTH-1:0]   s00_axi_awaddr  = 0;
    reg  [2:0]              s00_axi_awprot  = 0;
    reg                     s00_axi_awvalid = 0;
    wire                    s00_axi_awready;

    // Write Data Channel
    reg  [DATA_WIDTH-1:0]   s00_axi_wdata  = 0;
    reg  [(DATA_WIDTH/8)-1:0] s00_axi_wstrb = 4'hF;
    reg                     s00_axi_wvalid = 0;
    wire                    s00_axi_wready;

    // Write Response Channel
    wire [1:0] s00_axi_bresp;
    wire       s00_axi_bvalid;
    reg        s00_axi_bready = 0;

    // Read Address Channel
    reg  [ADDR_WIDTH-1:0]   s00_axi_araddr  = 0;
    reg  [2:0]              s00_axi_arprot  = 0;
    reg                     s00_axi_arvalid = 0;
    wire                    s00_axi_arready;

    // Read Data Channel
    wire [DATA_WIDTH-1:0]   s00_axi_rdata;
    wire [1:0]              s00_axi_rresp;
    wire                    s00_axi_rvalid;
    reg                     s00_axi_rready = 0;

    // Custom port (backend side)
    wire [ADDR_WIDTH-1:0]     port_addr;
    wire                      port_rd;
    wire                      port_wr;
    wire [DATA_WIDTH-1:0]     port_wdata;
    wire [(DATA_WIDTH/8)-1:0] port_wstrb;
    reg  [DATA_WIDTH-1:0]     port_rdata = 0;
    reg                       port_resp  = 0;
    wire                      port_clk;
    wire                      port_resetn;

    // -------------------------------------------------------------------------
    // DUT Instantiation
    // -------------------------------------------------------------------------

    husk_axi_port #(
        .C_S00_AXI_DATA_WIDTH(DATA_WIDTH),
        .C_S00_AXI_ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .port_addr    (port_addr),
        .port_rd      (port_rd),
        .port_wr      (port_wr),
        .port_wdata   (port_wdata),
        .port_wstrb   (port_wstrb),
        .port_rdata   (port_rdata),
        .port_resp    (port_resp),
        .port_clk     (port_clk),
        .port_resetn  (port_resetn),

        .s00_axi_aclk    (s00_axi_aclk),
        .s00_axi_aresetn (s00_axi_aresetn),
        .s00_axi_awaddr  (s00_axi_awaddr),
        .s00_axi_awprot  (s00_axi_awprot),
        .s00_axi_awvalid (s00_axi_awvalid),
        .s00_axi_awready (s00_axi_awready),
        .s00_axi_wdata   (s00_axi_wdata),
        .s00_axi_wstrb   (s00_axi_wstrb),
        .s00_axi_wvalid  (s00_axi_wvalid),
        .s00_axi_wready  (s00_axi_wready),
        .s00_axi_bresp   (s00_axi_bresp),
        .s00_axi_bvalid  (s00_axi_bvalid),
        .s00_axi_bready  (s00_axi_bready),
        .s00_axi_araddr  (s00_axi_araddr),
        .s00_axi_arprot  (s00_axi_arprot),
        .s00_axi_arvalid (s00_axi_arvalid),
        .s00_axi_arready (s00_axi_arready),
        .s00_axi_rdata   (s00_axi_rdata),
        .s00_axi_rresp   (s00_axi_rresp),
        .s00_axi_rvalid  (s00_axi_rvalid),
        .s00_axi_rready  (s00_axi_rready)
    );

    // -------------------------------------------------------------------------
    // Clock
    // -------------------------------------------------------------------------

    always #(CLK_PERIOD/2) s00_axi_aclk = ~s00_axi_aclk;

    // -------------------------------------------------------------------------
    // Backend memory model
    //
    // KEY TIMING (from state machine):
    //   - port_wr/port_rd are HELD HIGH until we assert port_resp
    //   - port_resp must pulse HIGH for exactly ONE cycle to acknowledge
    //   - For reads: port_rdata must be stable WHEN port_resp is asserted,
    //     because rdata_captured latches on that exact cycle
    //   - After port_resp is seen, the IP de-asserts port_wr/port_rd
    //     and moves toward sending the AXI response
    // -------------------------------------------------------------------------

    reg [DATA_WIDTH-1:0] mem [0:2**ADDR_WIDTH-1];

    integer k;
    initial begin
        for (k = 0; k < 2**ADDR_WIDTH; k = k + 1)
            mem[k] = k * 32'hDEAD_0001;
    end

    // Latency counter — waits BACKEND_LATENCY cycles after seeing
    // port_rd/port_wr before asserting port_resp for one cycle
    integer lat_count;

    always @(posedge port_clk or negedge port_resetn) begin
        if (!port_resetn) begin
            port_resp  <= 1'b0;
            port_rdata <= {DATA_WIDTH{1'b0}};
            lat_count  <= 0;
        end else begin
            port_resp <= 1'b0; // default: deasserted

            if (port_wr && !port_resp) begin
                // Write: count latency, then commit and ack
                if (lat_count < BACKEND_LATENCY - 1) begin
                    lat_count <= lat_count + 1;
                end else begin
                    // Apply byte-enables and assert response
                    if (port_wstrb[0]) mem[port_addr][7:0]   <= port_wdata[7:0];
                    if (port_wstrb[1]) mem[port_addr][15:8]  <= port_wdata[15:8];
                    if (port_wstrb[2]) mem[port_addr][23:16] <= port_wdata[23:16];
                    if (port_wstrb[3]) mem[port_addr][31:24] <= port_wdata[31:24];
                    port_resp <= 1'b1;
                    lat_count <= 0;
                end

            end else if (port_rd && !port_resp) begin
                // Read: count latency, then drive rdata stable and ack
                // rdata must be valid ON the same cycle port_resp is asserted
                if (lat_count < BACKEND_LATENCY - 1) begin
                    lat_count  <= lat_count + 1;
                    port_rdata <= mem[port_addr]; // pre-drive so it's stable
                end else begin
                    port_rdata <= mem[port_addr];
                    port_resp  <= 1'b1;
                    lat_count  <= 0;
                end

            end else if (!port_wr && !port_rd) begin
                lat_count <= 0; // reset counter when idle
            end
        end
    end

    // -------------------------------------------------------------------------
    // AXI4-Lite BFM Tasks
    // -------------------------------------------------------------------------

    task axi_write(
        input [ADDR_WIDTH-1:0]     addr,
        input [DATA_WIDTH-1:0]     data,
        input [(DATA_WIDTH/8)-1:0] strb
    );
        reg [1:0] resp;
        begin
            @(posedge s00_axi_aclk);
            #1; // small skew to avoid setup races

            // Drive AW and W simultaneously (both valid at once)
            s00_axi_awaddr  <= addr;
            s00_axi_awvalid <= 1;
            s00_axi_wdata   <= data;
            s00_axi_wstrb   <= strb;
            s00_axi_wvalid  <= 1;

            // Wait for both channels to handshake (may be same cycle or different)
            fork
                begin
                    @(posedge s00_axi_aclk iff (s00_axi_awvalid && s00_axi_awready));
                    #1; s00_axi_awvalid <= 0;
                end
                begin
                    @(posedge s00_axi_aclk iff (s00_axi_wvalid && s00_axi_wready));
                    #1; s00_axi_wvalid <= 0;
                end
            join

            // Accept write response
            s00_axi_bready <= 1;
            @(posedge s00_axi_aclk iff (s00_axi_bvalid && s00_axi_bready));
            resp = s00_axi_bresp;
            #1; s00_axi_bready <= 0;

            if (resp != 2'b00)
                $display("[WARN] axi_write addr=0x%02X: BRESP=%02b (expected OKAY)", addr, resp);
        end
    endtask

    // Write with address arriving before data (exercises ST_WAIT_WDATA)
    task axi_write_addr_first(
        input [ADDR_WIDTH-1:0]     addr,
        input [DATA_WIDTH-1:0]     data,
        input [(DATA_WIDTH/8)-1:0] strb,
        input integer              data_delay_cycles
    );
        integer d;
        reg [1:0] resp;
        begin
            @(posedge s00_axi_aclk); #1;

            // Send address only
            s00_axi_awaddr  <= addr;
            s00_axi_awvalid <= 1;
            @(posedge s00_axi_aclk iff (s00_axi_awvalid && s00_axi_awready));
            #1; s00_axi_awvalid <= 0;

            // Deliberate gap before data
            repeat(data_delay_cycles) @(posedge s00_axi_aclk);
            #1;

            // Now send data
            s00_axi_wdata  <= data;
            s00_axi_wstrb  <= strb;
            s00_axi_wvalid <= 1;
            @(posedge s00_axi_aclk iff (s00_axi_wvalid && s00_axi_wready));
            #1; s00_axi_wvalid <= 0;

            // Accept response
            s00_axi_bready <= 1;
            @(posedge s00_axi_aclk iff (s00_axi_bvalid && s00_axi_bready));
            resp = s00_axi_bresp;
            #1; s00_axi_bready <= 0;

            if (resp != 2'b00)
                $display("[WARN] axi_write_addr_first addr=0x%02X: BRESP=%02b", addr, resp);
        end
    endtask

    task axi_read(
        input  [ADDR_WIDTH-1:0] addr,
        output [DATA_WIDTH-1:0] data
    );
        reg [1:0] resp;
        begin
            @(posedge s00_axi_aclk); #1;

            s00_axi_araddr  <= addr;
            s00_axi_arvalid <= 1;
            @(posedge s00_axi_aclk iff (s00_axi_arvalid && s00_axi_arready));
            #1; s00_axi_arvalid <= 0;

            s00_axi_rready <= 1;
            @(posedge s00_axi_aclk iff (s00_axi_rvalid && s00_axi_rready));
            data = s00_axi_rdata;
            resp = s00_axi_rresp;
            #1; s00_axi_rready <= 0;

            if (resp != 2'b00)
                $display("[WARN] axi_read addr=0x%02X: RRESP=%02b (expected OKAY)", addr, resp);
        end
    endtask

    task check_read(
        input [ADDR_WIDTH-1:0] addr,
        input [DATA_WIDTH-1:0] expected
    );
        reg [DATA_WIDTH-1:0] got;
        begin
            axi_read(addr, got);
            if (got === expected)
                $display("[PASS] addr=0x%02X  got=0x%08X", addr, got);
            else
                $display("[FAIL] addr=0x%02X  expected=0x%08X  got=0x%08X",
                         addr, expected, got);
        end
    endtask

    // -------------------------------------------------------------------------
    // Test Stimulus
    // -------------------------------------------------------------------------

    reg [DATA_WIDTH-1:0] rdata;

    initial begin
        $dumpfile("tb_husk_axi_port.vcd");
        $dumpvars(0, tb_husk_axi_port);

        // --- Reset sequence ---
        s00_axi_aresetn = 0;
        repeat(5) @(posedge s00_axi_aclk);
        s00_axi_aresetn = 1;
        repeat(3) @(posedge s00_axi_aclk);

        // -----------------------------------------------------------------
        // Test 1: Basic simultaneous AW+W write then read-back
        // Exercises: ST_IDLE -> ST_WAIT_WRESP -> ST_SEND_BRESP -> ST_IDLE
        // -----------------------------------------------------------------
        $display("=== Test 1: Basic write + read-back ===");
        axi_write(6'h04, 32'hDEAD_BEEF, 4'hF);
        check_read(6'h04, 32'hDEAD_BEEF);

        // -----------------------------------------------------------------
        // Test 2: Address-before-data write
        // Exercises: ST_IDLE -> ST_WAIT_WDATA -> ST_WAIT_WRESP -> ...
        // -----------------------------------------------------------------
        $display("=== Test 2: AW before W (gap = 3 cycles) ===");
        axi_write_addr_first(6'h08, 32'hCAFE_F00D, 4'hF, 3);
        check_read(6'h08, 32'hCAFE_F00D);

        // -----------------------------------------------------------------
        // Test 3: Byte-enable masking
        // Write all-ones, then overwrite only low byte, expect merge
        // -----------------------------------------------------------------
        $display("=== Test 3: Byte-enable masking ===");
        axi_write(6'h0C, 32'hFFFF_FFFF, 4'hF);
        axi_write(6'h0C, 32'h1234_5678, 4'h1); // only byte 0
        check_read(6'h0C, 32'hFFFF_FF78);

        axi_write(6'h0C, 32'hFFFF_FFFF, 4'hF);
        axi_write(6'h0C, 32'h1234_5678, 4'hC); // only bytes 3:2
        check_read(6'h0C, 32'h1234_FFFF);

        // -----------------------------------------------------------------
        // Test 4: Sequential writes then sequential reads (no overlap,
        // state machine is one-at-a-time so this verifies ordering)
        // -----------------------------------------------------------------
        $display("=== Test 4: Sequential write/read sweep ===");
        begin : sweep
            integer idx;
            reg [DATA_WIDTH-1:0] wval;
            for (idx = 0; idx < 8; idx = idx + 1) begin
                wval = $random;
                axi_write(idx * 4, wval, 4'hF);
                check_read(idx * 4, wval);
            end
        end

        // -----------------------------------------------------------------
        // Test 5: Delayed BREADY — master stalls accepting write response
        // Exercises ST_SEND_BRESP holding bvalid until bready
        // -----------------------------------------------------------------
        $display("=== Test 5: Delayed BREADY ===");
        begin
            @(posedge s00_axi_aclk); #1;
            s00_axi_awaddr  <= 6'h10;
            s00_axi_awvalid <= 1;
            s00_axi_wdata   <= 32'hABCD_1234;
            s00_axi_wstrb   <= 4'hF;
            s00_axi_wvalid  <= 1;
            fork
                begin
                    @(posedge s00_axi_aclk iff (s00_axi_awvalid && s00_axi_awready));
                    #1; s00_axi_awvalid <= 0;
                end
                begin
                    @(posedge s00_axi_aclk iff (s00_axi_wvalid && s00_axi_wready));
                    #1; s00_axi_wvalid <= 0;
                end
            join
            // Wait for bvalid then deliberately stall 5 cycles before bready
            @(posedge s00_axi_aclk iff s00_axi_bvalid);
            repeat(5) @(posedge s00_axi_aclk);
            s00_axi_bready <= 1;
            @(posedge s00_axi_aclk iff (s00_axi_bvalid && s00_axi_bready));
            #1; s00_axi_bready <= 0;
            check_read(6'h10, 32'hABCD_1234);
        end

        // -----------------------------------------------------------------
        // Test 6: Delayed RREADY — master stalls accepting read data
        // Exercises ST_SEND_RRESP holding rvalid until rready
        // -----------------------------------------------------------------
        $display("=== Test 6: Delayed RREADY ===");
        begin
            reg [DATA_WIDTH-1:0] got;
            axi_write(6'h14, 32'h5A5A_A5A5, 4'hF);
            @(posedge s00_axi_aclk); #1;
            s00_axi_araddr  <= 6'h14;
            s00_axi_arvalid <= 1;
            @(posedge s00_axi_aclk iff (s00_axi_arvalid && s00_axi_arready));
            #1; s00_axi_arvalid <= 0;
            // Wait for rvalid then deliberately stall 5 cycles
            @(posedge s00_axi_aclk iff s00_axi_rvalid);
            repeat(5) @(posedge s00_axi_aclk);
            s00_axi_rready <= 1;
            @(posedge s00_axi_aclk iff (s00_axi_rvalid && s00_axi_rready));
            got = s00_axi_rdata;
            #1; s00_axi_rready <= 0;
            if (got === 32'h5A5A_A5A5)
                $display("[PASS] Delayed RREADY: got=0x%08X", got);
            else
                $display("[FAIL] Delayed RREADY: expected=0x5A5A_A5A5 got=0x%08X", got);
        end

        // -----------------------------------------------------------------
        // Test 7: Verify port_wr held until port_resp
        // Check that port_wr stays high for exactly BACKEND_LATENCY cycles
        // -----------------------------------------------------------------
        $display("=== Test 7: port_wr held high until port_resp ===");
        begin : wr_hold_check
            integer wr_cycles;
            wr_cycles = 0;
            @(posedge s00_axi_aclk); #1;
            s00_axi_awaddr  <= 6'h18;
            s00_axi_awvalid <= 1;
            s00_axi_wdata   <= 32'h1111_2222;
            s00_axi_wstrb   <= 4'hF;
            s00_axi_wvalid  <= 1;
            fork
                begin
                    @(posedge s00_axi_aclk iff (s00_axi_awvalid && s00_axi_awready));
                    #1; s00_axi_awvalid <= 0;
                end
                begin
                    @(posedge s00_axi_aclk iff (s00_axi_wvalid && s00_axi_wready));
                    #1; s00_axi_wvalid <= 0;
                end
            join
            // Count cycles port_wr stays high
            while (port_wr) begin
                @(posedge s00_axi_aclk);
                wr_cycles = wr_cycles + 1;
            end
            $display("[INFO] port_wr held for %0d cycles (expected ~%0d)",
                     wr_cycles, BACKEND_LATENCY);
            s00_axi_bready <= 1;
            @(posedge s00_axi_aclk iff (s00_axi_bvalid && s00_axi_bready));
            #1; s00_axi_bready <= 0;
        end

        $display("=== All tests complete ===");
        #100 $finish;
    end

    // -------------------------------------------------------------------------
    // Simulation timeout watchdog
    // -------------------------------------------------------------------------

    initial begin
        #500000;
        $display("[TIMEOUT] Simulation exceeded limit — likely a hanging handshake");
        $finish;
    end

    // -------------------------------------------------------------------------
    // State machine monitor (optional debug visibility)
    // -------------------------------------------------------------------------
    `define DEBUG
    `ifdef DEBUG
    always @(posedge s00_axi_aclk) begin
        $display("t=%0t | port_wr=%b port_rd=%b port_resp=%b port_addr=0x%02X",
                 $time, port_wr, port_rd, port_resp, port_addr);
    end
    `endif

endmodule