/*
 * Game Controller for Goose Game
 * 
 * Manages all game state logic:
 * - Game state FSM (running, game over, reset)
 * - Score tracking
 * - Obstacle spawn/despawn
 * - Collision handling
 * - Audio event generation
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
    output reg [1:0] obstacle_type,
    
    // Score output
    output wire [15:0] score_out,
    
    // Audio event outputs
    output wire event_jump,
    output wire event_death,
    output wire event_highscore
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
// Score Tracking
// ============================================================================

localparam SCORE_INC_TIME = 2517500;  // ~100ms at 25MHz

reg [21:0] score_ctr;
reg [3:0] score[3:0];  // 4 BCD digits

assign score_out = {score[3], score[2], score[1], score[0]};

always @(posedge clk) begin
    if (game_reset || !rst_n) begin
        score_ctr <= 0;
        score[3] <= 0;
        score[2] <= 0;
        score[1] <= 0;
        score[0] <= 0;
    end
    else if (!game_halt) begin
        score_ctr <= score_ctr + 1;
        if (score_ctr >= SCORE_INC_TIME) begin
            score_ctr <= 0;
            score[0] <= score[0] + 1;
            if (score[0] + 1 >= 10) begin
                score[0] <= 0;
                score[1] <= score[1] + 1;
                if (score[1] + 1 >= 10) begin
                    score[1] <= 0;
                    score[2] <= score[2] + 1;
                    if (score[2] + 1 >= 10) begin
                        score[2] <= 0;
                        score[3] <= score[3] + 1;
                        if (score[3] + 1 >= 10) begin
                            score[3] <= 0;
                        end
                    end
                end
            end
        end
    end
end

// ============================================================================
// Obstacle State Management
// ============================================================================

// Obstacle dimensions (must match rendering.v)
localparam ION_WIDTH = 20;
localparam UW_WIDTH = 30;

reg [1:0] obstacle_select_last;

always @(posedge clk) begin
    if (!rst_n) begin
        obstacle_select <= 2'd0;
        obstacle_type <= 2'd0;
        obstacle_select_last <= 2'd0;
    end
    else begin
        // Obstacle 0: ION railway
        if (scrolladdr[9:0] < 10'd10) begin
            obstacle_select[0] <= 1'b1;
        end
        else if (scrolladdr[9:0] > (10'd640 + ION_WIDTH)) begin
            obstacle_select[0] <= 1'b0;
        end

        // Obstacle 1: UW emblem (spawns at 250 offset)
        if (scrolladdr[9:0] >= 10'd250 && scrolladdr[9:0] < 10'd260) begin
            obstacle_select[1] <= 1'b1;
        end
        else if (scrolladdr[9:0] > (10'd640 + 10'd250 + UW_WIDTH)) begin
            obstacle_select[1] <= 1'b0;
        end

        // Generate new obstacle types when obstacles spawn
        if (obstacle_select[0] && !obstacle_select_last[0]) begin
            obstacle_type[0] <= random[0];  // ION railway type
        end
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
// Audio Event Generation
// ============================================================================

reg [9:0] event_jump_ctr;
reg [9:0] event_death_ctr;
reg event_jump_prev;
reg collision_prev;

assign event_jump = (event_jump_ctr > 0);
assign event_death = (event_death_ctr > 0);
assign event_highscore = 1'b0;  // TODO: Implement high score detection

always @(posedge clk) begin
    if (!rst_n) begin
        event_jump_ctr <= 10'd0;
        event_death_ctr <= 10'd0;
        event_jump_prev <= 1'b0;
        collision_prev <= 1'b0;
    end
    else begin
        // Jump event: rising edge of jump_button, only when on ground
        if (jump_button && !event_jump_prev && !in_air) begin
            event_jump_ctr <= 10'd512;
        end else if (event_jump_ctr > 0) begin
            event_jump_ctr <= event_jump_ctr - 10'd1;
        end
        event_jump_prev <= jump_button;
        
        // Death event: collision while alive
        if (collision && !collision_prev && !game_over) begin
            event_death_ctr <= 10'd512;
        end else if (event_death_ctr > 0) begin
            event_death_ctr <= event_death_ctr - 10'd1;
        end
        collision_prev <= collision;
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

