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

// Base scroll period - gets MUCH faster at higher speed levels
localparam [17:0] BASE_PERIOD = 18'd250000;     // 10ms at 25MHz (speed level 0)
localparam [17:0] SPEED_DECREMENT = 18'd35000;  // Aggressive reduction per level (14% faster each level!)
localparam [17:0] MIN_PERIOD = 18'd10000;       // Minimum period (prevents going impossibly fast)
localparam [10:0] MOVE_STEP = 11'd2;            // Pixels per tick

reg [17:0] ctr;
reg [17:0] current_period;
reg [22:0] speed_reduction;  // Larger to handle multiplication

// Calculate scroll period based on speed level
// Each level reduces the period, making the game progressively faster
// Formula: period = BASE_PERIOD - (speed_level * SPEED_DECREMENT)
// But never go below MIN_PERIOD
always @(*) begin
    speed_reduction = speed_level * SPEED_DECREMENT;
    
    // Check if reduction would go below minimum
    if (speed_reduction >= (BASE_PERIOD - MIN_PERIOD)) begin
        current_period = MIN_PERIOD;  // Cap at minimum period (maximum speed)
    end
    else begin
        current_period = BASE_PERIOD - speed_reduction[17:0];
    end
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
