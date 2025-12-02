/*
 * Game Controller for Goose Game
 */

`default_nettype none

module game_controller (
    input wire clk,
    input wire rst_n,
    input wire reset_button,
    input wire collision,
    input wire [9:0] scrolladdr,
    
    output reg game_over,
    output wire game_reset,
    output wire game_halt,
    output wire game_start_blink,
    
    output reg obstacle_active,
    output reg [9:0] obstacle_pos,
    output reg [3:0] speed_level  // 4 bits (0-15, capped at 8)
);

localparam START_TIME = 30000000;
localparam SPEED_UP_INTERVAL = 125000000;
localparam [9:0] OBSTACLE_CYCLE = 10'd700;

reg [24:0] start_ctr;
reg reset_button_prev;
reg [26:0] speed_timer;
reg [9:0] scrolladdr_prev;

wire reset_button_pressed = reset_button && !reset_button_prev;

assign game_reset = reset_button_pressed;
assign game_halt = game_over || (start_ctr < START_TIME);
assign game_start_blink = (start_ctr >= START_TIME) || start_ctr[22] || game_over;

always @(posedge clk) begin
    if (!rst_n) begin
        obstacle_active <= 1'b0;
        obstacle_pos <= 10'd0;
        scrolladdr_prev <= 10'd0;
    end
    else if (game_reset) begin
        obstacle_active <= 1'b0;
        obstacle_pos <= 10'd0;
        scrolladdr_prev <= 10'd0;
    end
    else if (!game_halt) begin
        obstacle_active <= 1'b1;
        if (scrolladdr != scrolladdr_prev) begin
            scrolladdr_prev <= scrolladdr;
            obstacle_pos <= (obstacle_pos >= OBSTACLE_CYCLE - 10'd1) ? 10'd0 : obstacle_pos + 10'd1;
        end
    end
end

always @(posedge clk) begin
    if (!rst_n) begin
        game_over <= 1'b0;
        start_ctr <= 25'd0;
        reset_button_prev <= 1'b0;
        speed_level <= 4'd0;
        speed_timer <= 27'd0;
    end
    else begin
        reset_button_prev <= reset_button;
        
        if (start_ctr < START_TIME)
            start_ctr <= start_ctr + 25'd1;

        if (game_reset) begin
            game_over <= 1'b0;
            start_ctr <= START_TIME;
            speed_level <= 4'd0;
            speed_timer <= 27'd0;
        end
        else if (collision && !game_over)
            game_over <= 1'b1;
        
        if (!game_halt && !game_over) begin
            speed_timer <= speed_timer + 27'd1;
            if (speed_timer >= SPEED_UP_INTERVAL) begin
                if (speed_level < 4'd15)
                    speed_level <= speed_level + 4'd1;
                speed_timer <= 27'd0;
            end
        end
    end
end

endmodule
