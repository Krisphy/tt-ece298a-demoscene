/*
 * Video Controller / Rendering module for goose game
 * 
 * Pure rendering logic:
 * - Sprite storage and layer compositing
 * - Pixel-by-pixel rendering
 * - Color palette management
 * - Collision detection (combinational)
 * 
 * No game state logic - all state comes from game_controller
 */

`default_nettype none

module rendering (
    output wire [1:0] R,
    output wire [1:0] G,
    output wire [1:0] B,
    output wire collision,

    input wire game_over,
    input wire game_start_blink,

    input wire obstacle_active,  // From game_controller
    input wire [6:0] jump_pos,
    input wire [9:0] vaddr,
    input wire [9:0] haddr,
    input wire [10:0] scrolladdr,
    input wire display_on,

    input wire clk,
    input wire sys_rst
);

localparam [10:0] FLOOR_Y = 11'd240;

localparam integer GOOSE_ROM_WIDTH = 16;
localparam integer GOOSE_ROM_HEIGHT = 16;
localparam [10:0] GOOSE_WIDTH_PX = 11'd32;
localparam [10:0] GOOSE_HEIGHT_PX = 11'd32;
localparam [10:0] GOOSE_X = 11'd64;
localparam [10:0] GOOSE_Y_BASE = FLOOR_Y - GOOSE_HEIGHT_PX;

localparam integer UW_WIDTH = 40;
localparam integer UW_HEIGHT = 48;
localparam [10:0] UW_WIDTH_PX = 11'd40;
localparam [10:0] UW_HEIGHT_PX = 11'd48;
localparam [10:0] OBSTACLE_TOP = FLOOR_Y - UW_HEIGHT_PX;
localparam [10:0] SCREEN_WIDTH = 11'd640;
localparam [10:0] OBSTACLE_OFFSET = 11'd334;  // Shifted to minimize gap at wrap

localparam integer LAYER_GOOSE = 0;
localparam integer LAYER_OBSTACLE = 1;
localparam integer LAYER_FLOOR = 2;
localparam integer LAYER_SKY = 3;
localparam integer LAYER_FLOOR_DOTS = 4;
reg [4:0] layers;

reg [1:0] goose_r, goose_g, goose_b;
reg [1:0] emblem_r, emblem_g, emblem_b;

localparam integer COLOR_BITS = 3;
localparam [COLOR_BITS-1:0] COLOR_TRANSPARENT = 3'd0;
localparam [COLOR_BITS-1:0] COLOR_GOOSE_BODY = 3'd1;
localparam [COLOR_BITS-1:0] COLOR_BLACK = 3'd2;
localparam [COLOR_BITS-1:0] COLOR_BEAK = 3'd3;
localparam [COLOR_BITS-1:0] COLOR_GOLD = 3'd4;
localparam [COLOR_BITS-1:0] COLOR_WHITE = 3'd5;
localparam [COLOR_BITS-1:0] COLOR_RED = 3'd6;

reg [COLOR_BITS*GOOSE_ROM_WIDTH-1:0] goose_rom [0:GOOSE_ROM_HEIGHT-1];

function [5:0] palette;
    input [COLOR_BITS-1:0] idx;
    begin
        case (idx)
            COLOR_GOOSE_BODY: palette = {2'b10, 2'b10, 2'b01};
            COLOR_BLACK:      palette = {2'b00, 2'b00, 2'b00};
            COLOR_BEAK:       palette = {2'b11, 2'b10, 2'b01};
            COLOR_GOLD:       palette = {2'b11, 2'b10, 2'b00};
            COLOR_WHITE:      palette = {2'b11, 2'b11, 2'b11};
            COLOR_RED:        palette = {2'b10, 2'b00, 2'b00};
            default:          palette = 6'b000000;
        endcase
    end
endfunction

function [COLOR_BITS-1:0] goose_pixel_from_row;
    input [COLOR_BITS*GOOSE_ROM_WIDTH-1:0] row_bits;
    input [3:0] px;
    integer shift;
    integer msb;
    integer px_int;
    begin
        px_int = {{(32-4){1'b0}}, px};
        shift = px_int * COLOR_BITS;
        msb = (GOOSE_ROM_WIDTH*COLOR_BITS - 1) - shift;
        goose_pixel_from_row = row_bits[msb -: COLOR_BITS];
    end
endfunction

initial begin
    goose_rom[0]  = 48'b000000000000000000000000000000000000000000000000;
    goose_rom[1]  = 48'b000000000000000000000000000000000000000000000000;
    goose_rom[2]  = 48'b000000000000000000000000000000010010010010010000;
    goose_rom[3]  = 48'b000000000000000000000000000000010010010010010011;
    goose_rom[4]  = 48'b000000000000000000000000000000010010010010010011;
    goose_rom[5]  = 48'b000000000000000000000000000000010010010010010011;
    goose_rom[6]  = 48'b000000000000000000000000000000010010010000000000;
    goose_rom[7]  = 48'b000000000000000000000000000000010010010000000000;
    goose_rom[8]  = 48'b000000000000000000000000000000010010010000000000;
    goose_rom[9]  = 48'b000000000000000000000000000000010010010000000000;
    goose_rom[10] = 48'b000000001001001001001001001001001001001000000000;
    goose_rom[11] = 48'b000000001001001001001001001001001001001000000000;
    goose_rom[12] = 48'b000000001001001001001001001001001001001000000000;
    goose_rom[13] = 48'b000000001001001001001001001001001001001000000000;
    goose_rom[14] = 48'b000000001001001001001001001001001001001000000000;
    goose_rom[15] = 48'b000000000000010010000000000010010000000000000000;
end

assign collision = layers[LAYER_GOOSE] & layers[LAYER_OBSTACLE];

wire [1:0] final_r, final_g, final_b;
assign final_r = (layers[LAYER_GOOSE] ? goose_r :
                  layers[LAYER_OBSTACLE] ? emblem_r :
                  layers[LAYER_FLOOR_DOTS] ? 2'b10 :
                  layers[LAYER_FLOOR] ? 2'b01 :
                  layers[LAYER_SKY] ? 2'b00 : 2'b00);

assign final_g = (layers[LAYER_GOOSE] ? goose_g :
                  layers[LAYER_OBSTACLE] ? emblem_g :
                  layers[LAYER_FLOOR_DOTS] ? 2'b10 :
                  layers[LAYER_FLOOR] ? 2'b01 :
                  layers[LAYER_SKY] ? 2'b11 : 2'b00);

assign final_b = (layers[LAYER_GOOSE] ? goose_b :
                  layers[LAYER_OBSTACLE] ? emblem_b :
                  layers[LAYER_FLOOR_DOTS] ? 2'b10 :
                  layers[LAYER_FLOOR] ? 2'b01 :
                  layers[LAYER_SKY] ? 2'b11 : 2'b00);

assign R = display_on ? final_r : 2'b00;
assign G = display_on ? final_g : 2'b00;
assign B = display_on ? final_b : 2'b00;

wire [10:0] vaddr_ext = {1'b0, vaddr};
wire [10:0] haddr_ext = {1'b0, haddr};

wire [10:0] goose_y = GOOSE_Y_BASE - {4'd0, jump_pos};
wire goose_x_in_bounds = (haddr_ext[10:5] == 6'b000010);
wire goose_in_bounds = goose_x_in_bounds &&
                       (vaddr_ext >= goose_y) && (vaddr_ext < (goose_y + GOOSE_HEIGHT_PX));
wire goose_active = goose_in_bounds && game_start_blink && display_on;

wire [10:0] goose_diff_y_full = vaddr_ext - goose_y;
wire [3:0] goose_rom_x = haddr_ext[4:1];
wire [3:0] goose_rom_y = goose_diff_y_full[4:1];

wire [COLOR_BITS*GOOSE_ROM_WIDTH-1:0] goose_row_bits = goose_rom[goose_rom_y];
wire [COLOR_BITS-1:0] goose_pixel_raw = goose_pixel_from_row(goose_row_bits, goose_rom_x);
wire [COLOR_BITS-1:0] goose_pixel_idx = goose_active ? goose_pixel_raw : COLOR_TRANSPARENT;
wire [COLOR_BITS-1:0] goose_color_idx =
    (game_over && goose_pixel_idx != COLOR_TRANSPARENT) ? COLOR_RED : goose_pixel_idx;
wire [5:0] goose_rgb = palette(goose_color_idx);

// Two obstacles at different positions for nearly continuous gameplay
// Obstacle 1: uses scrolladdr directly with OBSTACLE_OFFSET = 334
// Obstacle 2: offset by ~344 to fill the gap when obs1 wraps
wire [10:0] obs1_x = SCREEN_WIDTH - scrolladdr + OBSTACLE_OFFSET;
wire [10:0] obs2_x_pos = SCREEN_WIDTH - scrolladdr + OBSTACLE_OFFSET + 11'd344;

// Check if either obstacle is in bounds
wire [10:0] obs1_right = obs1_x + UW_WIDTH_PX;
wire [10:0] obs2_right = obs2_x_pos + UW_WIDTH_PX;

wire obs1_in_bounds = (haddr_ext >= obs1_x) && (haddr_ext < obs1_right) &&
                      (vaddr_ext >= OBSTACLE_TOP) && (vaddr_ext < FLOOR_Y);
wire obs2_in_bounds = (haddr_ext >= obs2_x_pos) && (haddr_ext < obs2_right) &&
                      (vaddr_ext >= OBSTACLE_TOP) && (vaddr_ext < FLOOR_Y);

wire obstacle_in_bounds = obstacle_active && display_on && (obs1_in_bounds || obs2_in_bounds);

// Use obs1 or obs2 coordinates for emblem rendering based on which is visible
wire [10:0] obs2_x = obs1_in_bounds ? obs1_x : obs2_x_pos;

wire [5:0] emblem_local_x = obstacle_in_bounds ? (haddr_ext[5:0] - obs2_x[5:0]) : 6'd0;
wire [5:0] emblem_local_y = obstacle_in_bounds ? (vaddr_ext[5:0] - OBSTACLE_TOP[5:0]) : 6'd0;

// Floor dots scrolling position
wire [10:0] floor_scroll_pos = haddr_ext + scrolladdr;

always @(posedge clk) begin
    if (sys_rst) begin
        layers <= 5'd0;
        goose_r <= 2'b00;
        goose_g <= 2'b00;
        goose_b <= 2'b00;
        emblem_r <= 2'b00;
        emblem_g <= 2'b00;
        emblem_b <= 2'b00;
    end
    else begin
        layers <= 5'd0;
        goose_r <= 2'b00;
        goose_g <= 2'b00;
        goose_b <= 2'b00;
        emblem_r <= 2'b00;
        emblem_g <= 2'b00;
        emblem_b <= 2'b00;
        
        if (display_on) begin
            if (vaddr_ext < FLOOR_Y) begin
                layers[LAYER_SKY] <= 1'b1;
            end
            else begin
                layers[LAYER_FLOOR] <= 1'b1;
                // Add dotted texture at top of floor (1 pixel high) that scrolls
                if (vaddr_ext == FLOOR_Y) begin
                    // Create dots every 16 pixels that scroll with the game
                    if (floor_scroll_pos[3:0] >= 4'd2 && 
                        floor_scroll_pos[3:0] <= 4'd5) begin
                        layers[LAYER_FLOOR_DOTS] <= 1'b1;
                    end
                end
            end
            
            if (goose_pixel_idx != COLOR_TRANSPARENT) begin
                    layers[LAYER_GOOSE] <= 1'b1;
                {goose_r, goose_g, goose_b} <= goose_rgb;
            end

            if (obstacle_active) begin
                if (obstacle_in_bounds) begin
                    // === RED LIONS (on gold background) ===
                    
                    // Upper left lion
                    if (((emblem_local_y >= 7 && emblem_local_y <= 13) && 
                         (emblem_local_x >= 7 && emblem_local_x <= 15)) &&
                        (((emblem_local_y >= 8 && emblem_local_y <= 13) && (emblem_local_x >= 8 && emblem_local_x <= 13)) ||
                         ((emblem_local_y >= 7 && emblem_local_y <= 9) && (emblem_local_x >= 12 && emblem_local_x <= 14)) ||
                         ((emblem_local_y >= 9 && emblem_local_y <= 10) && (emblem_local_x >= 14 && emblem_local_x <= 15)))) begin
                        layers[LAYER_OBSTACLE] <= 1'b1;
                        emblem_r <= 2'b10; emblem_g <= 2'b00; emblem_b <= 2'b00;
                    end
                    // Upper right lion
                    else if (((emblem_local_y >= 7 && emblem_local_y <= 13) && 
                              (emblem_local_x >= 25 && emblem_local_x <= 33)) &&
                             (((emblem_local_y >= 8 && emblem_local_y <= 13) && (emblem_local_x >= 27 && emblem_local_x <= 32)) ||
                              ((emblem_local_y >= 7 && emblem_local_y <= 9) && (emblem_local_x >= 26 && emblem_local_x <= 28)) ||
                              ((emblem_local_y >= 9 && emblem_local_y <= 10) && (emblem_local_x >= 25 && emblem_local_x <= 26)))) begin
                        layers[LAYER_OBSTACLE] <= 1'b1;
                        emblem_r <= 2'b10; emblem_g <= 2'b00; emblem_b <= 2'b00;
                    end
                    // Lower/bottom lion
                    else if (((emblem_local_y >= 28 && emblem_local_y <= 37) && 
                              (emblem_local_x >= 15 && emblem_local_x <= 25)) &&
                             (((emblem_local_y >= 30 && emblem_local_y <= 37) && (emblem_local_x >= 16 && emblem_local_x <= 24)) ||
                              ((emblem_local_y >= 28 && emblem_local_y <= 31) && (emblem_local_x >= 18 && emblem_local_x <= 22)) ||
                              ((emblem_local_y >= 32 && emblem_local_y <= 33) && 
                               ((emblem_local_x >= 15 && emblem_local_x <= 16) || (emblem_local_x >= 24 && emblem_local_x <= 25))))) begin
                        layers[LAYER_OBSTACLE] <= 1'b1;
                        emblem_r <= 2'b10; emblem_g <= 2'b00; emblem_b <= 2'b00;
                    end
                    
                    // === CHEVRON (inverted V shape) ===
                    
                    // White inner chevron stripes (left and right bands)
                    // Forms inner white diagonal stripes going down and inward
                    // Extends to emblem outline
                    else if (((emblem_local_y >= 17 && emblem_local_y <= 31)) &&
                             (((emblem_local_x >= (7 + (28 - emblem_local_y))) && 
                               (emblem_local_x <= (9 + (28 - emblem_local_y)))) ||
                              ((emblem_local_x >= (31 - (28 - emblem_local_y))) && 
                               (emblem_local_x <= (33 - (28 - emblem_local_y)))))) begin
                        layers[LAYER_OBSTACLE] <= 1'b1;
                        emblem_r <= 2'b11; emblem_g <= 2'b11; emblem_b <= 2'b11;
                    end
                    // Black outer chevron bands (left and right bands)
                    // Forms outer black diagonal bands flanking the white stripes
                    // Extends below white to create bottom outline
                    else if (((emblem_local_y >= 15 && emblem_local_y <= 31)) &&
                             (((emblem_local_x >= (4 + (29 - emblem_local_y))) && 
                               (emblem_local_x <= (9 + (29 - emblem_local_y)))) ||
                              ((emblem_local_x >= (31 - (29 - emblem_local_y))) && 
                               (emblem_local_x <= (36 - (29 - emblem_local_y)))))) begin
                        layers[LAYER_OBSTACLE] <= 1'b1;
                        emblem_r <= 2'b00; emblem_g <= 2'b00; emblem_b <= 2'b00;
                    end
                    
                    // === WHITE INNER BORDER (shield outline) ===
                    // Forms the white border just inside the black outer edge
                    else if (
                        ((emblem_local_y == 2) && 
                         (emblem_local_x >= 1 && emblem_local_x <= 38)) ||
                        ((emblem_local_y >= 3 && emblem_local_y <= 15) && 
                         ((emblem_local_x == 1) || (emblem_local_x == 38))) ||
                        ((emblem_local_y >= 16 && emblem_local_y <= 30) && 
                         ((emblem_local_x == 1) || (emblem_local_x == 38))) ||
                        ((emblem_local_y >= 31 && emblem_local_y <= 35) && 
                         ((emblem_local_x == (1 + (emblem_local_y - 30))) || 
                          (emblem_local_x == (38 - (emblem_local_y - 30))))) ||
                        ((emblem_local_y >= 36 && emblem_local_y <= 42) && 
                         ((emblem_local_x == (6 + (emblem_local_y - 35))) || 
                          (emblem_local_x == (33 - (emblem_local_y - 35))))) ||
                        ((emblem_local_y >= 43 && emblem_local_y <= 45) && 
                         ((emblem_local_x == (14 + (emblem_local_y - 43))) || 
                          (emblem_local_x == (25 - (emblem_local_y - 43)))))
                    ) begin
                        layers[LAYER_OBSTACLE] <= 1'b1;
                        emblem_r <= 2'b11; emblem_g <= 2'b11; emblem_b <= 2'b11;
                    end
                    
                    // === GOLD BACKGROUND ===
                    // Gold/yellow background fill for the shield
                    // Contains the red lions on top
                    else if (
                        ((emblem_local_y >= 3 && emblem_local_y <= 15) && 
                         (emblem_local_x >= 2 && emblem_local_x <= 37)) ||
                        ((emblem_local_y >= 16 && emblem_local_y <= 30) && 
                         (emblem_local_x >= 2 && emblem_local_x <= 37)) ||
                        ((emblem_local_y >= 31 && emblem_local_y <= 35) && 
                         (emblem_local_x >= (2 + (emblem_local_y - 30)) && 
                          emblem_local_x <= (37 - (emblem_local_y - 30)))) ||
                        ((emblem_local_y >= 36 && emblem_local_y <= 42) && 
                         (emblem_local_x >= (7 + (emblem_local_y - 35)) && 
                          emblem_local_x <= (32 - (emblem_local_y - 35)))) ||
                        ((emblem_local_y >= 43 && emblem_local_y <= 45) && 
                         (emblem_local_x >= (15 + (emblem_local_y - 43)) && 
                          emblem_local_x <= (24 - (emblem_local_y - 43))))
                    ) begin
                        layers[LAYER_OBSTACLE] <= 1'b1;
                        emblem_r <= 2'b11; emblem_g <= 2'b10; emblem_b <= 2'b00;
                    end
                    
                    // === BLACK OUTER BORDER ===
                    // Outermost black border of the shield
                    // Defines the shield's triangular shape
                    else if (
                        ((emblem_local_y <= 1) && 
                         (emblem_local_x >= 2 && emblem_local_x <= 37)) ||
                        ((emblem_local_y <= 1) && 
                         ((emblem_local_x <= 1) || (emblem_local_x >= 38))) ||
                        ((emblem_local_y >= 2 && emblem_local_y <= 15) && 
                         ((emblem_local_x == 0) || (emblem_local_x == 39))) ||
                        ((emblem_local_y >= 16 && emblem_local_y <= 30) && 
                         ((emblem_local_x == 0) || (emblem_local_x == 39))) ||
                        ((emblem_local_y >= 31 && emblem_local_y <= 35) && 
                         ((emblem_local_x == (emblem_local_y - 30)) || 
                          (emblem_local_x == (39 - (emblem_local_y - 30))))) ||
                        ((emblem_local_y >= 36 && emblem_local_y <= 42) && 
                         ((emblem_local_x == (5 + (emblem_local_y - 35))) || 
                          (emblem_local_x == (34 - (emblem_local_y - 35))))) ||
                        ((emblem_local_y >= 43 && emblem_local_y <= 45) && 
                         ((emblem_local_x == (13 + (emblem_local_y - 43))) || 
                          (emblem_local_x == (26 - (emblem_local_y - 43))))) ||
                        ((emblem_local_y >= 46 && emblem_local_y <= 47) && 
                         ((emblem_local_x == 19) || (emblem_local_x == 20)))
                    ) begin
                        layers[LAYER_OBSTACLE] <= 1'b1;
                        emblem_r <= 2'b00; emblem_g <= 2'b00; emblem_b <= 2'b00;
                    end
                end
            end
        end
    end
end

endmodule
