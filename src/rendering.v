/*
 * Video Controller / Rendering module for goose game
 * 
 * Pure rendering logic:
 * - Sprite storage and layer compositing
 * - Pixel-by-pixel rendering
 * - Color palette management
 * - Score display rendering
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

    input wire [1:0] obstacle_select,  // From game_controller
    input wire [1:0] obstacle_type,
    input wire [15:0] score_in,        // From game_controller
    input wire [6:0] jump_pos,
    input wire [9:0] vaddr,
    input wire [9:0] haddr,
    input wire [10:0] scrolladdr,
    input wire display_on,

    input wire clk,
    input wire sys_rst
);

// Simple sprite definitions using rectangles
// Goose sprite: 30x40 pixels (goose-shaped sprite)
localparam GOOSE_WIDTH = 30;
localparam GOOSE_HEIGHT = 40;
localparam GOOSE_X = 50;
localparam GOOSE_Y_BASE = 200;  // Ground level position

// ION railway obstacle: 30x40 pixels (front-view tram sprite)
localparam ION_WIDTH = 30;
localparam ION_HEIGHT = 40;

// UW emblem obstacle: 30x30 pixels (square)
localparam UW_WIDTH = 30;
localparam UW_HEIGHT = 30;

// Floor position
localparam FLOOR_Y = 240;
localparam FLOOR_HEIGHT = 5;

// Ground texture from dinogame (6 rows, 256 bits each)
reg [255:0] floor[5:0];

// Score rendering (display only, score counting is in game_controller)
reg [3:0] score_saved[3:0];
reg score_pixel;
reg [189:0] digits[52:0];  // Digit ROM - 19 pixels wide x 53 pixels tall for each digit 0-9

// Layer outputs (priority order: 0=highest, 5=lowest)
reg [5:0] layers;  // [0]=goose, [1]=ION, [2]=UW emblem, [3]=floor_texture, [4]=floor, [5]=sky
reg [1:0] layer_colors [4:0];  // Color for each layer (texture uses hardcoded white)

// Goose per-pixel colors (for shading)
reg [1:0] goose_r, goose_g, goose_b;
reg [1:0] tram_r, tram_g, tram_b;

// Collision: goose hits any obstacle (ION railway or UW emblem only)
assign collision = layers[0] & (layers[1] | layers[2]);

// Composite all layers with colors (priority order: score, goose, obstacles, ION, floor texture, floor, sky)
wire [1:0] final_r, final_g, final_b;
assign final_r = (score_pixel ? 2'b11 :        // Score: black R=00 (highest priority)
                  layers[0] ? goose_r :        // Goose (with shading)
                  layers[1] ? tram_r :         // Tram obstacle (with colors)
                  layers[2] ? layer_colors[2] : // UW emblem
                  layers[3] ? 2'b11 :           // Floor texture: white R=11
                  layers[4] ? 2'b01 :           // Floor: R=01
                  layers[5] ? 2'b00 : 2'b00);   // Sky: R=00

assign final_g = (score_pixel ? 2'b11 :        // Score: black G=00 (highest priority)
                  layers[0] ? goose_g :        // Goose (with shading)
                  layers[1] ? tram_g :         // Tram obstacle (with colors)
                  layers[2] ? layer_colors[2] : // UW emblem
                  layers[3] ? 2'b11 :           // Floor texture: white G=11
                  layers[4] ? 2'b01 :           // Floor: G=01
                  layers[5] ? 2'b11 : 2'b00);   // Sky: G=11

assign final_b = (score_pixel ? 2'b11 :        // Score: black B=00 (highest priority)
                  layers[0] ? goose_b :        // Goose (with shading)
                  layers[1] ? tram_b :         // Tram obstacle (with colors)
                  layers[2] ? layer_colors[2] : // UW emblem
                  layers[3] ? 2'b11 :           // Floor texture: white B=11
                  layers[4] ? 2'b01 :           // Floor: B=01
                  layers[5] ? 2'b11 : 2'b00);   // Sky: B=11

assign R = display_on ? final_r : 2'b00;
assign G = display_on ? final_g : 2'b00;
assign B = display_on ? final_b : 2'b00;

wire [10:0] goose_y = GOOSE_Y_BASE - {4'd0, jump_pos};
wire [10:0] floor_scroll = haddr + scrolladdr;  // Floor pattern scrolls left with world
wire [7:0] flooraddr = floor_scroll[7:0];       // Floor texture address
wire [10:0] obs1_x = 11'd640 - scrolladdr;      // Start at right, move left
wire [10:0] obs2_x = 11'd640 - scrolladdr + 11'd250;
wire [10:0] obs3_x = 11'd640 - scrolladdr + 11'd450;

// Goose sprite coordinates (for color calculation)
wire [5:0] goose_sprite_y;
wire [4:0] goose_sprite_x;
assign goose_sprite_y = (vaddr >= goose_y && vaddr < (goose_y + GOOSE_HEIGHT)) ? (vaddr - goose_y) : 6'd0;
assign goose_sprite_x = (haddr >= GOOSE_X && haddr < (GOOSE_X + GOOSE_WIDTH)) ? (haddr - GOOSE_X) : 5'd0;

// Tram sprite coordinates (for obstacle 1)
wire [5:0] tram_sprite_y;
wire [4:0] tram_sprite_x;
assign tram_sprite_y = (vaddr >= (FLOOR_Y - ION_HEIGHT) && vaddr < FLOOR_Y) ? (vaddr - (FLOOR_Y - ION_HEIGHT)) : 6'd0;
assign tram_sprite_x = (haddr >= obs1_x && haddr < (obs1_x + ION_WIDTH)) ? (haddr - obs1_x) : 5'd0;

always @(posedge clk) begin
    if (sys_rst) begin
        layers <= 6'd0;
        goose_r <= 2'b00;
        goose_g <= 2'b00;
        goose_b <= 2'b00;
        tram_r <= 2'b00;
        tram_g <= 2'b00;
        tram_b <= 2'b00;
    end
    else begin
        layers <= 6'd0;
        
        // Set default colors for layers
        layer_colors[0] <= 2'b11;  // Goose - yellow/white
        layer_colors[1] <= 2'b01;  // Obstacle - red
        layer_colors[2] <= 2'b11;  // ION - blue
        
        // Default goose colors (will be overridden if goose is drawn)
        goose_r <= 2'b11;
        goose_g <= 2'b11;
        goose_b <= 2'b00;
        
        // Default tram colors (will be overridden if tram is drawn)
        tram_r <= 2'b10;
        tram_g <= 2'b10;
        tram_b <= 2'b10;

        if (display_on) begin
            // Layer 5: Sky background (everything above ground)
            if (vaddr < FLOOR_Y) begin
                layers[5] <= 1'b1;
            end
            
            // Layer 4: Ground area (everything at or below FLOOR_Y) - solid dark grey
            if (vaddr >= FLOOR_Y) begin
                layers[4] <= 1'b1;
            end
            
            // Layer 3: Floor texture (white pattern on first 6 rows of ground)
            if (vaddr >= FLOOR_Y && vaddr < (FLOOR_Y + 6)) begin
                layers[3] <= floor[vaddr - FLOOR_Y][flooraddr];
            end
            
            // Layer 0: Goose (parametric Canadian goose sprite)
            if (haddr >= GOOSE_X && haddr < (GOOSE_X + GOOSE_WIDTH) &&
                vaddr >= goose_y && vaddr < (goose_y + GOOSE_HEIGHT) &&
                game_start_blink) begin
                
                // Part detection using goose_sprite_x and goose_sprite_y
                // Beak: rows 13-14, cols 27-28
                if ((goose_sprite_y >= 13 && goose_sprite_y <= 14) && 
                    (goose_sprite_x >= 27 && goose_sprite_x <= 28)) begin
                    layers[0] <= 1'b1;
                    if (game_over) begin
                        goose_r <= 2'b11; goose_g <= 2'b00; goose_b <= 2'b00; // Red when dead
                    end else begin
                        goose_r <= 2'b11; goose_g <= 2'b10; goose_b <= 2'b01; // Orange beak
                    end
                end
                // Eye: rows 12-13, col 24
                else if (((goose_sprite_y == 12) || (goose_sprite_y == 13)) && (goose_sprite_x == 24)) begin
                    layers[0] <= 1'b1;
                    if (game_over) begin
                        goose_r <= 2'b11; goose_g <= 2'b00; goose_b <= 2'b00; // Red when dead
                    end else begin
                        goose_r <= 2'b11; goose_g <= 2'b11; goose_b <= 2'b11; // White eye
                    end
                end
                // Cheek patch: rows 13-14, cols 22-23
                else if ((goose_sprite_y >= 13 && goose_sprite_y <= 14) && 
                         (goose_sprite_x >= 22 && goose_sprite_x <= 23)) begin
                    layers[0] <= 1'b1;
                    if (game_over) begin
                        goose_r <= 2'b11; goose_g <= 2'b00; goose_b <= 2'b00; // Red when dead
                    end else begin
                        goose_r <= 2'b11; goose_g <= 2'b11; goose_b <= 2'b11; // White cheek
                    end
                end
                // Belly: rows 34-35, cols 12-18
                else if ((goose_sprite_y >= 34 && goose_sprite_y <= 35) && 
                         (goose_sprite_x >= 12 && goose_sprite_x <= 18)) begin
                    layers[0] <= 1'b1;
                    if (game_over) begin
                        goose_r <= 2'b11; goose_g <= 2'b00; goose_b <= 2'b00; // Red when dead
                    end else begin
                        goose_r <= 2'b11; goose_g <= 2'b11; goose_b <= 2'b11; // White belly
                    end
                end
                // Head (excluding beak, eye, cheek): rows 11-16, cols 22-26
                else if ((goose_sprite_y >= 11 && goose_sprite_y <= 16) &&
                         (goose_sprite_x >= 22 && goose_sprite_x <= 26)) begin
                    layers[0] <= 1'b1;
                    if (game_over) begin
                        goose_r <= 2'b11; goose_g <= 2'b00; goose_b <= 2'b00; // Red when dead
                    end else begin
                        goose_r <= 2'b00; goose_g <= 2'b00; goose_b <= 2'b00; // Black head
                    end
                end
                // Neck: 2px wide S-curve from rows 17-24
                else if (((goose_sprite_y >= 17 && goose_sprite_y <= 18) && (goose_sprite_x >= 20 && goose_sprite_x <= 21)) ||
                         ((goose_sprite_y >= 19 && goose_sprite_y <= 20) && (goose_sprite_x >= 19 && goose_sprite_x <= 20)) ||
                         ((goose_sprite_y >= 21 && goose_sprite_y <= 22) && (goose_sprite_x >= 18 && goose_sprite_x <= 19)) ||
                         ((goose_sprite_y >= 23 && goose_sprite_y <= 24) && (goose_sprite_x >= 17 && goose_sprite_x <= 18))) begin
                    layers[0] <= 1'b1;
                    if (game_over) begin
                        goose_r <= 2'b11; goose_g <= 2'b00; goose_b <= 2'b00; // Red when dead
                    end else begin
                        goose_r <= 2'b00; goose_g <= 2'b00; goose_b <= 2'b00; // Black neck
                    end
                end
                // Wing leading edge (black): specific leftmost pixels at rows 14-24
                else if (((goose_sprite_y == 14) && (goose_sprite_x == 6)) ||
                         ((goose_sprite_y == 15) && (goose_sprite_x == 6)) ||
                         ((goose_sprite_y == 16) && (goose_sprite_x == 7)) ||
                         ((goose_sprite_y == 17) && (goose_sprite_x == 8)) ||
                         ((goose_sprite_y == 18) && (goose_sprite_x == 9)) ||
                         ((goose_sprite_y == 19) && (goose_sprite_x == 10)) ||
                         ((goose_sprite_y == 20) && (goose_sprite_x == 10)) ||
                         ((goose_sprite_y == 21) && (goose_sprite_x == 10)) ||
                         ((goose_sprite_y == 22) && (goose_sprite_x == 10)) ||
                         ((goose_sprite_y == 23) && (goose_sprite_x == 10)) ||
                         ((goose_sprite_y == 24) && (goose_sprite_x == 10))) begin
                    layers[0] <= 1'b1;
                    if (game_over) begin
                        goose_r <= 2'b11; goose_g <= 2'b00; goose_b <= 2'b00; // Red when dead
                    end else begin
                        goose_r <= 2'b00; goose_g <= 2'b00; goose_b <= 2'b00; // Black leading edge
                    end
                end
                // Legs: rows 36-39, cols 12 or 15
                else if ((goose_sprite_y >= 36 && goose_sprite_y <= 39) && 
                         ((goose_sprite_x == 12) || (goose_sprite_x == 15))) begin
                    layers[0] <= 1'b1;
                    if (game_over) begin
                        goose_r <= 2'b11; goose_g <= 2'b00; goose_b <= 2'b00; // Red when dead
                    end else begin
                        goose_r <= 2'b00; goose_g <= 2'b00; goose_b <= 2'b00; // Black legs
                    end
                end
                // Tail: rows 29-34, cols 6-9 (triangle extending from body)
                else if (((goose_sprite_y == 29) && (goose_sprite_x >= 6 && goose_sprite_x <= 7)) ||
                         ((goose_sprite_y == 30) && (goose_sprite_x >= 6 && goose_sprite_x <= 7)) ||
                         ((goose_sprite_y == 31) && (goose_sprite_x >= 6 && goose_sprite_x <= 7)) ||
                         ((goose_sprite_y == 32) && (goose_sprite_x >= 6 && goose_sprite_x <= 8)) ||
                         ((goose_sprite_y == 33) && (goose_sprite_x >= 6 && goose_sprite_x <= 8)) ||
                         ((goose_sprite_y == 34) && (goose_sprite_x >= 6 && goose_sprite_x <= 7))) begin
                    layers[0] <= 1'b1;
                    if (game_over) begin
                        goose_r <= 2'b11; goose_g <= 2'b00; goose_b <= 2'b00; // Red when dead
                    end else begin
                        goose_r <= 2'b10; goose_g <= 2'b01; goose_b <= 2'b00; // Dark brown tail (same as body)
                    end
                end
                // Wing (brown): raised diagonal triangle extending down to body
                else if (((goose_sprite_y == 14) && (goose_sprite_x >= 6 && goose_sprite_x <= 8)) ||
                         ((goose_sprite_y == 15) && (goose_sprite_x >= 6 && goose_sprite_x <= 9)) ||
                         ((goose_sprite_y == 16) && (goose_sprite_x >= 7 && goose_sprite_x <= 10)) ||
                         ((goose_sprite_y == 17) && (goose_sprite_x >= 8 && goose_sprite_x <= 11)) ||
                         ((goose_sprite_y == 18) && (goose_sprite_x >= 9 && goose_sprite_x <= 12)) ||
                         ((goose_sprite_y == 19) && (goose_sprite_x >= 10 && goose_sprite_x <= 13)) ||
                         ((goose_sprite_y == 20) && (goose_sprite_x >= 10 && goose_sprite_x <= 14)) ||
                         ((goose_sprite_y == 21) && (goose_sprite_x >= 10 && goose_sprite_x <= 15)) ||
                         ((goose_sprite_y == 22) && (goose_sprite_x >= 10 && goose_sprite_x <= 16)) ||
                         ((goose_sprite_y == 23) && (goose_sprite_x >= 10 && goose_sprite_x <= 17)) ||
                         ((goose_sprite_y == 24) && (goose_sprite_x >= 10 && goose_sprite_x <= 18))) begin
                    layers[0] <= 1'b1;
                    if (game_over) begin
                        goose_r <= 2'b11; goose_g <= 2'b00; goose_b <= 2'b00; // Red when dead
                    end else begin
                        goose_r <= 2'b10; goose_g <= 2'b10; goose_b <= 2'b01; // Brown wing (more green for brown)
                    end
                end
                // Body: elongated horizontal wedge/oval
                else if (((goose_sprite_y >= 25 && goose_sprite_y <= 28) && (goose_sprite_x >= 10 && goose_sprite_x <= 22)) ||
                         ((goose_sprite_y >= 29 && goose_sprite_y <= 32) && (goose_sprite_x >= 9 && goose_sprite_x <= 22)) ||
                         ((goose_sprite_y >= 33 && goose_sprite_y <= 35) && (goose_sprite_x >= 9 && goose_sprite_x <= 21))) begin
                    layers[0] <= 1'b1;
                    if (game_over) begin
                        goose_r <= 2'b11; goose_g <= 2'b00; goose_b <= 2'b00; // Red when dead
                    end else begin
                        goose_r <= 2'b10; goose_g <= 2'b10; goose_b <= 2'b01; // Brown body (more green, less red)
                    end
                end
            end

            // Layer 1: First ION railway obstacle (front-view tram sprite)
            if (obstacle_select[0]) begin
                if (haddr >= obs1_x && haddr < (obs1_x + ION_WIDTH) &&
                    vaddr >= (FLOOR_Y - ION_HEIGHT) && vaddr < FLOOR_Y) begin
                    
                    // Parametric tram rendering - front view of ION LRT (30x40 sprite)
                    // Use tram_sprite_x (0-29) and tram_sprite_y (0-39) coordinates
                    
                    // Priority order: specific details over general areas
                    
                    // Headlights (white center): left x=8-10, y=26, right x=20-22, y=26
                    if ((tram_sprite_y == 26) && 
                             ((tram_sprite_x >= 8 && tram_sprite_x <= 10) || 
                              (tram_sprite_x >= 20 && tram_sprite_x <= 22))) begin
                        layers[1] <= 1'b1;
                        tram_r <= 2'b11; tram_g <= 2'b11; tram_b <= 2'b11; // White headlights
                    end
                    // Coupler recess (dark notch center): x=14..16, y=30..34
                    else if ((tram_sprite_y >= 30 && tram_sprite_y <= 34) && 
                             (tram_sprite_x >= 14 && tram_sprite_x <= 16)) begin
                        layers[1] <= 1'b1;
                        tram_r <= 2'b00; tram_g <= 2'b00; tram_b <= 2'b01; // Dark gray #000055
                    end
                    // Blue accent blades - left side: x=3..4, y=8..28
                    else if ((tram_sprite_y >= 8 && tram_sprite_y <= 28) && 
                             (tram_sprite_x >= 3 && tram_sprite_x <= 4)) begin
                        layers[1] <= 1'b1;
                        tram_r <= 2'b00; tram_g <= 2'b01; tram_b <= 2'b11; // ION blue #0055FF
                    end
                    // Blue accent blades - right side: x=25..26, y=8..28
                    else if ((tram_sprite_y >= 8 && tram_sprite_y <= 28) && 
                             (tram_sprite_x >= 25 && tram_sprite_x <= 26)) begin
                        layers[1] <= 1'b1;
                        tram_r <= 2'b00; tram_g <= 2'b01; tram_b <= 2'b11; // ION blue #0055FF
                    end
                    // Windshield glass mask (black): x=5..24, y=6..24
                    else if ((tram_sprite_y >= 6 && tram_sprite_y <= 24) && 
                             (tram_sprite_x >= 5 && tram_sprite_x <= 24)) begin
                        layers[1] <= 1'b1;
                        tram_r <= 2'b00; tram_g <= 2'b00; tram_b <= 2'b00; // Black glass
                    end
                    // White body extends to ground: x=4..26, y=25..39
                    else if ((tram_sprite_y >= 25 && tram_sprite_y <= 39) && 
                             (tram_sprite_x >= 4 && tram_sprite_x <= 26)) begin
                        layers[1] <= 1'b1;
                        tram_r <= 2'b11; tram_g <= 2'b11; tram_b <= 2'b11; // White body
                    end
                    // Roof equipment box (pantograph base): x=12..17, y=2..4
                    else if ((tram_sprite_y >= 2 && tram_sprite_y <= 4) && 
                             (tram_sprite_x >= 12 && tram_sprite_x <= 17)) begin
                        layers[1] <= 1'b1;
                        tram_r <= 2'b10; tram_g <= 2'b10; tram_b <= 2'b10; // Mid gray #AAAAAA
                    end
                    // Upper body/roof: x=5..24, y=0..5 (ION blue top)
                    else if ((tram_sprite_y <= 5) && 
                             (tram_sprite_x >= 5 && tram_sprite_x <= 24)) begin
                        layers[1] <= 1'b1;
                        tram_r <= 2'b00; tram_g <= 2'b01; tram_b <= 2'b11; // ION blue #0055FF
                    end
                    // Bottom edge/shadow line: x=5..24, y=39 (thin dark line at ground)
                    else if ((tram_sprite_y == 39) && 
                             (tram_sprite_x >= 5 && tram_sprite_x <= 24)) begin
                        layers[1] <= 1'b1;
                        tram_r <= 2'b01; tram_g <= 2'b01; tram_b <= 2'b01; // Dark gray shadow
                    end
                end
            end

            // Layer 2: UW emblem obstacle (square) - spawns at second position
            if (obstacle_select[1]) begin
                if (haddr >= obs2_x && haddr < (obs2_x + UW_WIDTH) &&
                    vaddr >= (FLOOR_Y - UW_HEIGHT) && vaddr < FLOOR_Y) begin
                    if (obstacle_type[1]) begin
                        // Draw filled square
                        layers[2] <= 1'b1;
                        layer_colors[2] <= 2'b11;  // Blue for UW
                    end
                    else begin
                        // Draw outline square
                        if ((haddr - obs2_x) < 2 || (haddr - obs2_x) >= (UW_WIDTH - 2) ||
                            (vaddr - (FLOOR_Y - UW_HEIGHT)) < 2 || 
                            (vaddr - (FLOOR_Y - UW_HEIGHT)) >= (UW_HEIGHT - 2)) begin
                            layers[2] <= 1'b1;
                            layer_colors[2] <= 2'b11;
                        end
                    end
                end
            end
        end
    end
end

// Score rendering logic - displays in upper right corner
// Score value comes from game_controller (score_in)
always @(posedge clk) begin
    score_pixel <= 0;

    if (vaddr > 20 && vaddr < 73) begin
        if (haddr > 460 && haddr < 480) begin
            score_pixel <= digits[vaddr-21][(haddr-461)+(19*score_saved[3])];
        end
        else if (haddr > 482 && haddr < 502) begin
            score_pixel <= digits[vaddr-21][(haddr-483)+(19*score_saved[2])];
        end
        else if (haddr > 504 && haddr < 524) begin
            score_pixel <= digits[vaddr-21][(haddr-505)+(19*score_saved[1])];
        end
        else if (haddr > 526 && haddr < 546) begin
            score_pixel <= digits[vaddr-21][(haddr-527)+(19*score_saved[0])];
        end
    end
    else begin
        // Extract BCD digits from score_in
        score_saved[3] <= score_in[15:12];
        score_saved[2] <= score_in[11:8];
        score_saved[1] <= score_in[7:4];
        score_saved[0] <= score_in[3:0];
    end
end

// Ground texture initialization (from dinogame-tt05)
initial begin
    floor[0] = 255'b000000000000000000000000000000000000000000000000000000000000000000000000000000001110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000000;
    floor[1] = 255'b111111111111111111111111111111111111111111111111111111111111111111111111111111110011111000111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111100111110001111111111111111111111111111111111111;
    floor[2] = 255'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011111000000000000000000000000000000000000;
    floor[3] = 255'b000000001000000000000010000000000000001101100000010000000000010000000000000000000000010000001000000000010000000000000000000000100000000010000000000000100000000000000011011000000100000000000100000000000000000000000100000010000000000100000000000000000000001;
    floor[4] = 255'b010000000000001000000000000100000000000000000000000000000000000001000010000000000100000000000010000000001000000001000100010000000100000000000010000000000001000000000000000000000000000000000000010000100000000001000000000000100000000010000000010001000100000;
    floor[5] = 255'b001100000000000000000000000001000000000000000000100100000001100000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000010000000000000000001001000000011000000000000000000000000000000000000000000000000000000000000000000;
    
    // Digit ROM initialization (10 digits × 19 pixels wide = 190 bits, using 189 bits)
    digits[0]  = 189'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    digits[1]  = 189'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    digits[2]  = 189'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    digits[3]  = 189'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    digits[4]  = 189'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    digits[5]  = 189'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    digits[6]  = 189'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    digits[7]  = 189'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    digits[8]  = 189'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    digits[9]  = 189'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    digits[10] = 189'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    digits[11] = 189'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    digits[12] = 189'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    digits[13] = 189'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    digits[14] = 189'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    digits[15] = 189'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    digits[16] = 189'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    digits[17] = 189'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    digits[18] = 189'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    digits[19] = 189'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    digits[20] = 189'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    digits[21] = 189'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    digits[22] = 189'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    digits[23] = 189'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    digits[24] = 189'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    digits[25] = 189'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    digits[26] = 189'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    digits[27] = 189'b000111111111111100000000111111111110001111111111111111110000111111111100000000011111111111111100001111111100000000111111111111111100000011111111111110000000011111100000000000001111111100000;
    digits[28] = 189'b000111111111111100000000111111111110001111111111111111110000111111111100000000011111111111111100001111111100000000111111111111111100000011111111111110000000011111100000000000001111111100000;
    digits[29] = 189'b000111111111111100000000111111111110001111111111111111110000111111111100000000011111111111111100001111111100000000111111111111111100000011111111111110000000011111100000000000001111111100000;
    digits[30] = 189'b111111000000011111000011100000001111101111110000000111110000000000011111100000000000000001111100001111111111000000000111110000000000011111100000001111100000011111111000000000111110000011100;
    digits[31] = 189'b111111000000011111000011100000001111101111110000000111110000000000011111100000000000000001111100001111111111000000000111110000000000011111100000001111100000011111111000000000111110000011100;
    digits[32] = 189'b111111000000011111000011100000001111101111110000000111110000000000011111100000000000000001111100001111111111000000000111110000000000011111100000001111100000011111111000000000111110000011100;
    digits[33] = 189'b111111000000011111000011100001111111100001111100000000000000000000000011111000011111111111111100001111100111111000000001111110000000011111111000000000000000011111100000000111111000000011111;
    digits[34] = 189'b111111000000011111000011100001111111100001111100000000000000000000000011111000011111111111111100001111100111111000000001111110000000011111111000000000000000011111100000000111111000000011111;
    digits[35] = 189'b111111000000011111000011100001111111100001111100000000000000000000000011111000011111111111111100001111100111111000000001111110000000011111111000000000000000011111100000000111111000000011111;
    digits[36] = 189'b111111111111111100000000111111111110000000011111100000000000111111111111111011111100000000000000001111100000111110000111111111100000000011111111110000000000011111100000000111111000000011111;
    digits[37] = 189'b111111111111111100000000111111111110000000011111100000000000111111111111111011111100000000000000001111100000111110000111111111100000000011111111110000000000011111100000000111111000000011111;
    digits[38] = 189'b111111111111111100000000111111111110000000011111100000000000111111111111111011111100000000000000001111100000111110000111111111100000000011111111110000000000011111100000000111111000000011111;
    digits[39] = 189'b111111000000000000011111111111000011100000000011111000000111111000000011111011111100000000000001111111111111111110111111000000000000000000111111111110000000011111100000000111111000000011111;
    digits[40] = 189'b111111000000000000011111111111000011100000000011111000000111111000000011111011111100000000000001111111111111111110111111000000000000000000111111111110000000011111100000000111111000000011111;
    digits[41] = 189'b111111000000000000011111111111000011100000000011111000000111111000000011111011111100000000000001111111111111111110111111000000000000000000111111111110000000011111100000000111111000000011111;
    digits[42] = 189'b000111110000000000011111100000000011100000000011111000000111111000000011111011111100000001111100001111100000000000111111000000011111000000000001111111100000011111100000000000111000011111100;
    digits[43] = 189'b000111110000000000011111100000000011100000000011111000000111111000000011111011111100000001111100001111100000000000111111000000011111000000000001111111100000011111100000000000111000011111100;
    digits[44] = 189'b000111110000000000011111100000000011100000000011111000000111111000000011111011111100000001111100001111100000000000111111000000011111000000000001111111100000011111100000000000111000011111100;
    digits[45] = 189'b000001111111111100000011111111111110000000000011111000000000111111111111100000011111111111110000001111100000000000000111111111111100011111111111111111101111111111111111000000001111111100000;
    digits[46] = 189'b000001111111111100000011111111111110000000000011111000000000111111111111100000011111111111110000001111100000000000000111111111111100011111111111111111101111111111111111000000001111111100000;
    digits[47] = 189'b000001111111111100000011111111111110000000000011111000000000111111111111100000011111111111110000001111100000000000000111111111111100011111111111111111101111111111111111000000001111111100000;
    digits[48] = 189'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    digits[49] = 189'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    digits[50] = 189'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    digits[51] = 189'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    digits[52] = 189'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
end

endmodule

