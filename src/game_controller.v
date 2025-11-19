/*
 * Game Controller for Goose Game
 * 
 * Manages all game state logic:
 * - Game state FSM (running, game over, reset)
 * - Obstacle spawn/despawn
 * - Collision handling
 * - Obstacle type randomization
 */

`default_nettype none

module game_controller (
    // Clock and reset
    input wire clk,
    input wire rst_n,
    
    // User inputs
    input wire jump_button,
    input wire halt_button,
    
    // Inputs from other modules
    input wire collision,
    input wire [10:0] scrolladdr,
    input wire [4:0] random,
    input wire in_air,
    
    // Game state outputs
    output reg game_over,
    output wire game_reset,
    output wire game_halt,
    output wire game_start_blink,
    output reg game_running,
    
    // Obstacle state outputs
    output reg [1:0] obstacle_select,
    output reg [1:0] obstacle_type
);

// ============================================================================
// Game State Machine
// ============================================================================

localparam START_TIME = 30000000;  // ~1.2 seconds at 25MHz

reg [31:0] start_ctr;
reg [19:0] no_jump_ctr;

assign game_reset = game_over & jump_button & (no_jump_ctr > 20'd100000);
assign game_halt = game_over || halt_button || (start_ctr < START_TIME);
assign game_start_blink = (start_ctr >= START_TIME) || start_ctr[22] || game_over;

// ============================================================================
// Obstacle State Management
// ============================================================================

// Obstacle dimensions (must match rendering.v)
localparam UW_WIDTH = 40;

reg [1:0] obstacle_select_last;

always @(posedge clk) begin
    if (!rst_n) begin
        obstacle_select <= 2'd0;
        obstacle_type <= 2'd0;
        obstacle_select_last <= 2'd0;
    end
    else begin
        obstacle_select[0] <= 1'b0;

        // Obstacle 1: UW emblem (spawns at 250 offset)
        if (scrolladdr[9:0] >= 10'd250 && scrolladdr[9:0] < 10'd260) begin
            obstacle_select[1] <= 1'b1;
        end
        else if (scrolladdr[9:0] > (10'd640 + 10'd250 + UW_WIDTH)) begin
            obstacle_select[1] <= 1'b0;
        end

        // Generate new obstacle types when obstacles spawn
        if (obstacle_select[1] && !obstacle_select_last[1]) begin
            obstacle_type[1] <= random[1];  // UW emblem type
        end
        
        obstacle_select_last <= obstacle_select;
        
        // Reset obstacle types on game reset
        if (game_reset) begin
            obstacle_type <= 2'd0;
        end
    end
end

// ============================================================================
// Game State FSM
// ============================================================================

always @(posedge clk) begin
    if (!rst_n) begin
        game_over <= 1'b0;
        start_ctr <= 32'd0;
        no_jump_ctr <= 20'd0;
        game_running <= 1'b0;
    end
    else begin
        // Start counter for initial delay
        if (start_ctr < START_TIME) begin
            start_ctr <= start_ctr + 32'd1;
        end

        // Game running state
        game_running <= (start_ctr >= START_TIME) && !game_over;

        // Track jump button for reset detection
        if (jump_button) begin
            no_jump_ctr <= 20'd0;
        end
        else if (no_jump_ctr < 20'd1000000) begin
            no_jump_ctr <= no_jump_ctr + 20'd1;
        end

        // Game reset
        if (game_reset) begin
            game_over <= 1'b0;
            start_ctr <= START_TIME;  // Skip startup delay on reset
        end

        // Collision detection
        if (collision && !game_over) begin
            game_over <= 1'b1;
        end
    end
end

endmodule
