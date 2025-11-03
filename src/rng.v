/*
 * Random number generator for obstacle placement
 * Uses LFSR (Linear Feedback Shift Register)
 */

`default_nettype none

module rng (
    input wire entropy_in,
    output reg [4:0] out,
    input wire clk,
    input wire sys_rst
);

always @(posedge clk) begin
    if (sys_rst) begin
        out <= 5'd1;
    end
    else if (entropy_in) begin
        // 5-bit LFSR with taps at positions 5 and 3
        out[0] <= out[1] ^ out[4];
        out[1] <= out[0];
        out[2] <= out[1];
        out[3] <= out[2];
        out[4] <= out[3];
    end
end

endmodule

