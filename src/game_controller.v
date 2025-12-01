/*
 * Game Controller for Goose Game
 * 
 * Manages all game state logic:
 * - Game state FSM (running, game over, reset)
 * - Obstacle spawn/despawn
 * - Collision handling
 */

`default_nettype none

module game_controller (
    // Clock and reset
    input wire clk,
    input wire rst_n,
    
    // User inputs
    input wire jump_button,
    input wire reset_button,
    
    // Inputs from other modules
    input wire collision,
    input wire [9:0] scrolladdr,
    
    // Game state outputs
    output reg game_over,
    output wire game_reset,
    output wire game_halt,
    output wire game_start_blink,
    
    // Obstacle state outputs - now support 3 obstacles
    output reg [2:0] obstacle_active
);

// ============================================================================
// Game State Machine
// ============================================================================

localparam START_TIME = 30000000;  // ~1.2 seconds at 25MHz

reg [24:0] start_ctr;
reg reset_button_prev;

// Reset button edge detection - trigger on rising edge
wire reset_button_pressed = reset_button && !reset_button_prev;

assign game_reset = reset_button_pressed;
assign game_halt = game_over || (start_ctr < START_TIME);
assign game_start_blink = (start_ctr >= START_TIME) || start_ctr[22] || game_over;

// ============================================================================
// Obstacle State Management
// ============================================================================

// Obstacle dimensions (must match rendering.v)
localparam UW_WIDTH = 40;

// Multiple obstacles can be active at once
// Obstacle spawn positions are staggered to create continuous challenges
// Obstacles move RIGHT to LEFT (start at right edge, exit left)
always @(posedge clk) begin
    if (!rst_n) begin
        obstacle_active <= 3'b000;
    end
    else begin
        // Obstacle 0: spawns at scrolladdr 0-10, at position 640-scrolladdr
        // Deactivates when completely off left: scrolladdr > 680 (640 + 40)
        if (scrolladdr[9:0] >= 10'd0 && scrolladdr[9:0] < 10'd10) begin
            obstacle_active[0] <= 1'b1;
        end
        else if (scrolladdr[9:0] > 10'd680) begin
            obstacle_active[0] <= 1'b0;
        end
        
        // Obstacle 1: spawns at scrolladdr 200-210, at position 640-scrolladdr+200
        // Deactivates when completely off left: scrolladdr > 880 (640 + 200 + 40)
        if (scrolladdr[9:0] >= 10'd200 && scrolladdr[9:0] < 10'd210) begin
            obstacle_active[1] <= 1'b1;
        end
        else if (scrolladdr[9:0] > 10'd880) begin
            obstacle_active[1] <= 1'b0;
        end
        
        // Obstacle 2: spawns at scrolladdr 400-410, at position 640-scrolladdr+400
        // Deactivates when completely off left: scrolladdr > 1080
        // Since 1080 > 1023 (10-bit max), it wraps to 56 (1080 - 1024 = 56)
        if (scrolladdr[9:0] >= 10'd400 && scrolladdr[9:0] < 10'd410) begin
            obstacle_active[2] <= 1'b1;
        end
        else if (scrolladdr[9:0] > 10'd56 && scrolladdr[9:0] < 10'd400) begin
            // Deactivate when scrolladdr wrapped past 1024 and is now > 56
            obstacle_active[2] <= 1'b0;
        end
    end
end

// ============================================================================
// Game State FSM
// ============================================================================

always @(posedge clk) begin
    if (!rst_n) begin
        game_over <= 1'b0;
        start_ctr <= 25'd0;
        reset_button_prev <= 1'b0;
    end
    else begin
        // Track reset button for edge detection
        reset_button_prev <= reset_button;
        
        // Start counter for initial delay
        if (start_ctr < START_TIME) begin
            start_ctr <= start_ctr + 25'd1;
        end

        // Game reset - restart the game
        if (game_reset) begin
            game_over <= 1'b0;
            start_ctr <= START_TIME;  // Skip startup delay on reset
        end
        // Collision detection
        else if (collision && !game_over) begin
            game_over <= 1'b1;
        end
    end
end

endmodule
