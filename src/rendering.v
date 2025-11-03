/*
 * Rendering module for goose game
 * Handles sprite storage and layer compositing
 * Uses simple placeholder sprites (rectangles/squares)
 */

`default_nettype none

module rendering (
    output wire [1:0] R,
    output wire [1:0] G,
    output wire [1:0] B,
    output wire collision,
    output reg [2:0] obstacle_select,

    input wire game_over,
    input wire game_start_blink,

    input wire [2:0] obstacle_type,
    input wire [6:0] jump_pos,
    input wire [9:0] vaddr,
    input wire [9:0] haddr,
    input wire [10:0] scrolladdr,
    input wire display_on,

    input wire clk,
    input wire sys_rst
);

// Simple sprite definitions using rectangles
// Goose sprite: 30x40 pixels (simple rectangle)
localparam GOOSE_WIDTH = 30;
localparam GOOSE_HEIGHT = 40;
localparam GOOSE_X = 50;
localparam GOOSE_Y_BASE = 200;  // Ground level position

// ION railway obstacle: 20x40 pixels
localparam ION_WIDTH = 20;
localparam ION_HEIGHT = 40;

// UW emblem obstacle: 30x30 pixels (square)
localparam UW_WIDTH = 30;
localparam UW_HEIGHT = 30;

// Floor position
localparam FLOOR_Y = 240;
localparam FLOOR_HEIGHT = 5;

// Layer outputs
reg [4:0] layers;
reg [1:0] layer_colors [4:0];  // Color for each layer

// Collision: goose hits any obstacle
assign collision = layers[0] & (layers[1] | layers[3] | layers[4]);

// Composite all layers with colors
wire [1:0] final_r, final_g, final_b;
assign final_r = (layers[0] ? layer_colors[0] : 
                  layers[1] ? layer_colors[1] :
                  layers[2] ? layer_colors[2] :
                  layers[3] ? layer_colors[3] :
                  layers[4] ? layer_colors[4] : 2'b00);

assign final_g = (layers[0] ? 2'b11 :  // Goose is green
                  layers[1] ? layer_colors[1] :
                  layers[2] ? layer_colors[2] :
                  layers[3] ? layer_colors[3] :
                  layers[4] ? layer_colors[4] : 2'b00);

assign final_b = (layers[0] ? 2'b00 :
                  layers[1] ? layer_colors[1] :
                  layers[2] ? layer_colors[2] :
                  layers[3] ? layer_colors[3] :
                  layers[4] ? layer_colors[4] : 2'b00);

assign R = display_on ? final_r : 2'b00;
assign G = display_on ? final_g : 2'b00;
assign B = display_on ? final_b : 2'b00;

wire [10:0] goose_y = GOOSE_Y_BASE - {4'd0, jump_pos};
wire [10:0] floor_scroll = haddr + scrolladdr;  // Floor pattern scrolls left with world
wire [10:0] obs1_x = 11'd640 - scrolladdr;      // Start at right, move left
wire [10:0] obs2_x = 11'd640 - scrolladdr + 11'd250;
wire [10:0] obs3_x = 11'd640 - scrolladdr + 11'd450;

always @(posedge clk) begin
    if (sys_rst) begin
        layers <= 5'd0;
        obstacle_select <= 3'd0;
    end
    else begin
        layers <= 5'd0;
        
        // Set default colors for layers
        layer_colors[0] <= 2'b11;  // Goose - yellow/white
        layer_colors[1] <= 2'b01;  // ION - red
        layer_colors[2] <= 2'b10;  // Floor - gray
        layer_colors[3] <= 2'b01;  // ION - red
        layer_colors[4] <= 2'b11;  // UW emblem - blue

        if (display_on) begin
            // Layer 0: Goose (simple rectangle)
            if (haddr >= GOOSE_X && haddr < (GOOSE_X + GOOSE_WIDTH) &&
                vaddr >= goose_y && vaddr < (goose_y + GOOSE_HEIGHT) &&
                game_start_blink) begin
                
                if (game_over) begin
                    // Dead goose - change color to red
                    layers[0] <= 1'b1;
                    layer_colors[0] <= 2'b11;  // Red when dead
                end
                else begin
                    // Alive goose - draw simple rectangle
                    layers[0] <= 1'b1;
                end
            end

            // Layer 2: Floor (simple horizontal line)
            if (vaddr >= FLOOR_Y && vaddr < (FLOOR_Y + FLOOR_HEIGHT)) begin
                // Simple dashed floor pattern using scroll position
                if (floor_scroll[3:0] < 4'd8) begin
                    layers[2] <= 1'b1;
                end
            end

            // Layer 1: First ION railway obstacle
            if (obstacle_select[0]) begin
                if (haddr >= obs1_x && haddr < (obs1_x + ION_WIDTH) &&
                    vaddr >= (FLOOR_Y - ION_HEIGHT) && vaddr < FLOOR_Y) begin
                    // Draw ION obstacle based on type
                    if (obstacle_type[0]) begin
                        // Type 0: solid rectangle
                        layers[1] <= 1'b1;
                    end
                    else begin
                        // Type 1: dashed rectangle
                        if (vaddr[2:0] < 3'd4) begin
                            layers[1] <= 1'b1;
                        end
                    end
                end
            end

            // Layer 3: Second ION railway obstacle (offset)
            if (obstacle_select[1]) begin
                if (haddr >= obs2_x && haddr < (obs2_x + ION_WIDTH) &&
                    vaddr >= (FLOOR_Y - ION_HEIGHT) && vaddr < FLOOR_Y) begin
                    if (obstacle_type[1]) begin
                        layers[3] <= 1'b1;
                    end
                    else begin
                        if (vaddr[2:0] < 3'd4) begin
                            layers[3] <= 1'b1;
                        end
                    end
                end
            end

            // Layer 4: UW emblem obstacle (square)
            if (obstacle_select[2]) begin
                if (haddr >= obs3_x && haddr < (obs3_x + UW_WIDTH) &&
                    vaddr >= (FLOOR_Y - UW_HEIGHT) && vaddr < FLOOR_Y) begin
                    if (obstacle_type[2]) begin
                        // Draw filled square
                        layers[4] <= 1'b1;
                        layer_colors[4] <= 2'b11;  // Blue for UW
                    end
                    else begin
                        // Draw outline square
                        if ((haddr - obs3_x) < 2 || (haddr - obs3_x) >= (UW_WIDTH - 2) ||
                            (vaddr - (FLOOR_Y - UW_HEIGHT)) < 2 || 
                            (vaddr - (FLOOR_Y - UW_HEIGHT)) >= (UW_HEIGHT - 2)) begin
                            layers[4] <= 1'b1;
                            layer_colors[4] <= 2'b11;
                        end
                    end
                end
            end

            // Obstacle spawn/despawn logic
            if (scrolladdr[9:0] < 10'd10) begin
                obstacle_select[0] <= 1'b1;
            end
            else if (scrolladdr[9:0] > (10'd640 + ION_WIDTH)) begin
                obstacle_select[0] <= 1'b0;
            end

            if (scrolladdr[9:0] >= 10'd250 && scrolladdr[9:0] < 10'd260) begin
                obstacle_select[1] <= 1'b1;
            end
            else if (scrolladdr[9:0] > (10'd640 + 10'd250 + ION_WIDTH)) begin
                obstacle_select[1] <= 1'b0;
            end

            if (scrolladdr[9:0] >= 10'd450 && scrolladdr[9:0] < 10'd460) begin
                obstacle_select[2] <= 1'b1;
            end
            else if (scrolladdr[10:0] > (11'd640 + 11'd450 + UW_WIDTH)) begin
                obstacle_select[2] <= 1'b0;
            end
        end
    end
end

endmodule

