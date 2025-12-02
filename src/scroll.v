/*
 * Scrolling logic for goose game
 * Area-optimized with synchronous reset
 */

`default_nettype none

module scroll (
    input wire halt,
    input wire [4:0] speed_level,
    output reg [10:0] pos,

    input wire game_rst,
    input wire clk,
    input wire sys_rst
);

// Scroll period lookup table - no multiplier needed!
// Pre-computed: BASE=125000, DECREMENT=15000, MIN=10000
localparam [10:0] MOVE_STEP = 11'd2;

reg [17:0] ctr;
reg [17:0] current_period;

// Lookup table replaces expensive multiplication
always @(*) begin
    case (speed_level[2:0])  // Only need 3 bits (levels 0-7, then max speed)
        3'd0: current_period = 18'd125000;
        3'd1: current_period = 18'd110000;
        3'd2: current_period = 18'd95000;
        3'd3: current_period = 18'd80000;
        3'd4: current_period = 18'd65000;
        3'd5: current_period = 18'd50000;
        3'd6: current_period = 18'd35000;
        3'd7: current_period = 18'd20000;
        default: current_period = 18'd10000;
    endcase
    // After level 7, stay at max speed (10000)
    if (speed_level >= 5'd8) current_period = 18'd10000;
end

always @(posedge clk) begin
    if (game_rst || sys_rst) begin
        pos <= 11'd0;
        ctr <= 18'd0;
    end
    else if (!halt) begin
        if (ctr >= current_period) begin
            ctr <= 18'd0;
            pos <= pos + MOVE_STEP;
        end
        else begin
            ctr <= ctr + 18'd1;
        end
    end
end

endmodule
