// LOL SRAMs are too large
module pe_action_table
    import pe_types::*;
(
    input logic clk,

    input logic write_en,
    input action_table_entry_t w_entry,

    input pid_t pid,
    output action_table_entry_t entry
);

    action_table_entry_t entries[PAT_SIZE-1:2];

    always_ff @(posedge clk) begin
        if (write_en) begin
            case (pid)
                4'd0: begin
                end
                4'd1: begin
                end
                default: entries[pid] <= w_entry;
            endcase
        end
    end

    // Since this is likely just going to be a regfile might was well make it comb read, since the arb is gonna latch the output packet.
    assign entry = entries[pid];

endmodule
