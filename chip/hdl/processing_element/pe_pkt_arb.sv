/*
    The packet arbiter does the following:

    - consolidates the valid/non-empty bits from ingress FIFOs
    - provides a selector signal to the data switchbox, and dequeues from the corresponding FIFO
    - prevent starvation of any one ingress FIFO

    Notably, our FSM on dequeue needs to be live for a single cycle, and we should be ready with the next arbit decision
    as soon as the FU/PE requests for a new packet internally.

    This arbiter also takes in a ready bit from the output switchbox. This determines its ability to actually *make* a decision.
    Once it goes down it doesn't provide a valid bit to the rest of the PE until it gets it again.
    This ready bit is stored as a skid buffer (i think).

*/

module pe_packet_arb
    import pe_types::*;
#(
    parameter int PORTS = 4
) (
    input logic clk,
    input logic rst,

    input logic fifo_empty[PORTS],
    input logic stall,

    output port_dir_t selector,
    output logic      valid
);

    port_dir_t last_req;
    port_dir_t next_req;

    logic valid_enable;

    // loop counter
    integer unsigned offset;

    always_comb begin
        valid_enable = '0;
        next_req = last_req;

        for (offset = 1; offset <= PORTS; offset++) begin : for_pe_pkt_arb_iterate_ports
            if (!fifo_empty[(last_req+(3)'(offset))%PORTS] && !valid_enable) begin
                next_req = port_dir_t'((last_req + (3)'(offset)) % PORTS);
                valid_enable = 1'b1;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            last_req <= port_dir_t'('0);
        end else if (!stall && valid_enable) begin
            last_req <= next_req;
        end
    end

    assign selector = next_req;
    assign valid = valid_enable;
endmodule
