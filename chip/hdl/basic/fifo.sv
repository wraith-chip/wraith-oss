module fifo
#(
    parameter int DEPTH = 3,  // Number of Elements (Power of 2)
    parameter int WIDTH = 32 // Bitwidth of Elements
) (
    input  logic clk,
    input  logic rst,

    input  logic             enqueue,
    input  logic [WIDTH-1:0] wdata,

    input  logic             dequeue,
    output logic [WIDTH-1:0] rdata,

    output logic             full,
    output logic             empty
);

localparam int PTR = DEPTH;
localparam int TDEPTH = 2 ** DEPTH;

logic [WIDTH-1:0] data [TDEPTH];
logic [PTR:0] head;
logic [PTR:0] tail;


always_ff @(posedge clk) begin
    // Reset
    if (rst) begin
        head <= '0;
        tail <= '0;
    end else begin
        if (enqueue & dequeue & (full | empty)) begin
            if (empty) begin
                // Enqueue enqueues an element next cycle
                // Dequeue ignored on empty.
                // When both happen the same time & queue is empty - its just an enqueue.
                data[tail[PTR-1:0]] <= wdata;
                tail <= tail + 1'b1;
            end else if (full) begin
                // Simultaneous enqueue + dequeue when full should still "work"
                data[tail[PTR-1:0]] <= wdata;
                head <= head + 1'b1;
                tail <= tail + 1'b1;
            end
        end else begin
            // Write
            if (enqueue & !full) begin
                data[tail[PTR-1:0]] <= wdata;
                tail <= tail + 1'b1;
            end
            // Read
            if (dequeue & !empty) begin
                head <= head + 1'b1;
            end
        end
    end
end

// Logic
always_comb begin
    full  = (head[PTR] ^ tail[PTR]) & (head[PTR-1:0] == tail[PTR-1:0]);
    empty = (head == tail);
    rdata = data[head[PTR-1:0]];
end
endmodule : fifo
