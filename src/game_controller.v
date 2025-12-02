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
    
    // Obstacle state outputs
    output reg obstacle_active,
    output reg [9:0] obstacle_pos,  // Obstacle position counter (0-699)
    
    // Speed control output (5 bits allows up to level 31)
    output reg [4:0] speed_level
);

// ============================================================================
// Game State Machine
// ============================================================================

localparam START_TIME = 30000000;  // ~1.2 seconds at 25MHz

// Speed progression: increase every 5 seconds of gameplay
localparam SPEED_UP_INTERVAL = 125000000;  // 5 seconds at 25MHz

reg [24:0] start_ctr;
reg reset_button_prev;
reg [26:0] speed_timer;  // Timer for speed progression

// Reset button edge detection - trigger on rising edge
wire reset_button_pressed = reset_button && !reset_button_prev;

assign game_reset = reset_button_pressed;
assign game_halt = game_over || (start_ctr < START_TIME);
assign game_start_blink = (start_ctr >= START_TIME) || start_ctr[22] || game_over;

// ============================================================================
// Obstacle State Management - 700-unit Cycle Counter
// ============================================================================

localparam [9:0] OBSTACLE_CYCLE = 10'd700;  // Obstacle respawns every 700 scroll units

reg [9:0] obstacle_counter;  // Tracks position within cycle
reg [9:0] scrolladdr_prev;

always @(posedge clk) begin
    if (!rst_n) begin
        obstacle_active <= 1'b0;
        obstacle_counter <= 10'd0;
        obstacle_pos <= 10'd0;
        scrolladdr_prev <= 10'd0;
    end
    else if (game_reset) begin
        obstacle_active <= 1'b0;
        obstacle_counter <= 10'd0;
        obstacle_pos <= 10'd0;
        scrolladdr_prev <= 10'd0;
    end
    else if (!game_halt) begin
        obstacle_active <= 1'b1;
        obstacle_pos <= obstacle_counter;  // Output the counter
        
        // Detect scroll movement and increment counter
        if (scrolladdr != scrolladdr_prev) begin
            scrolladdr_prev <= scrolladdr;
            
            // Increment counter, wrap at OBSTACLE_CYCLE
            if (obstacle_counter >= OBSTACLE_CYCLE - 10'd1) begin
                obstacle_counter <= 10'd0;
            end
            else begin
                obstacle_counter <= obstacle_counter + 10'd1;
            end
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
        speed_level <= 5'd0;
        speed_timer <= 27'd0;
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
            speed_level <= 5'd0;      // Reset speed to initial
            speed_timer <= 27'd0;     // Reset speed timer
        end
        // Collision detection
        else if (collision && !game_over) begin
            game_over <= 1'b1;
        end
        
        // Speed progression - increase speed every interval when game is running (NO LIMIT!)
        if (!game_halt && !game_over) begin
            speed_timer <= speed_timer + 27'd1;
            
            // Increase speed level every SPEED_UP_INTERVAL with saturation to prevent wraparound
            if (speed_timer >= SPEED_UP_INTERVAL) begin
                // Only increment if not at max (prevent overflow)
                if (speed_level < 5'd31) begin
                    speed_level <= speed_level + 5'd1;
                end
                speed_timer <= 27'd0;
            end
        end
    end
end

endmodule
