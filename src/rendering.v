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

    input wire [1:0] obstacle_select,  // From game_controller
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

// UW emblem obstacle: 40x48 pixels (shield with coat of arms)
localparam UW_WIDTH = 40;
localparam UW_HEIGHT = 48;

// Floor position
localparam FLOOR_Y = 240;

// Ground texture - reduced from original (saves ROM)
// 4 rows × 128 bits = 512 bits
// Pattern repeats twice horizontally across screen
reg [127:0] floor_pattern[3:0];

// Layer outputs (priority order: 0=highest, 5=lowest)
// [0]=goose, [2]=UW emblem, [3]=floor_texture, [4]=floor, [5]=sky
reg [5:0] layers;  

// Goose per-pixel colors (for shading)
reg [1:0] goose_r, goose_g, goose_b;
// Emblem per-pixel colors
reg [1:0] emblem_r, emblem_g, emblem_b;

// Collision: goose hits UW emblem
assign collision = layers[0] & layers[2];

// Composite all layers with colors (priority order: goose, obstacles, floor texture, floor, sky)
wire [1:0] final_r, final_g, final_b;
assign final_r = (layers[0] ? goose_r :        // Goose (with shading)
                  layers[2] ? emblem_r :       // UW emblem (with colors)
                  layers[3] ? 2'b11 :           // Floor texture: white R=11
                  layers[4] ? 2'b01 :           // Floor: R=01
                  layers[5] ? 2'b00 : 2'b00);   // Sky: R=00

assign final_g = (layers[0] ? goose_g :        // Goose (with shading)
                  layers[2] ? emblem_g :       // UW emblem (with colors)
                  layers[3] ? 2'b11 :           // Floor texture: white G=11
                  layers[4] ? 2'b01 :           // Floor: G=01
                  layers[5] ? 2'b11 : 2'b00);   // Sky: G=11

assign final_b = (layers[0] ? goose_b :        // Goose (with shading)
                  layers[2] ? emblem_b :       // UW emblem (with colors)
                  layers[3] ? 2'b11 :           // Floor texture: white B=11
                  layers[4] ? 2'b01 :           // Floor: B=01
                  layers[5] ? 2'b11 : 2'b00);   // Sky: B=11

assign R = display_on ? final_r : 2'b00;
assign G = display_on ? final_g : 2'b00;
assign B = display_on ? final_b : 2'b00;

wire [10:0] goose_y = GOOSE_Y_BASE - {4'd0, jump_pos};
wire [10:0] floor_scroll = haddr + scrolladdr;  // Floor pattern scrolls left with world
wire [7:0] flooraddr = floor_scroll[7:0];       // Floor texture address
wire [10:0] obs2_x = 11'd640 - scrolladdr + 11'd250;

// Goose sprite coordinates (for color calculation)
wire [5:0] goose_sprite_y;
wire [4:0] goose_sprite_x;
wire [10:0] goose_diff_y = {1'b0, vaddr} - goose_y;
wire [10:0] goose_diff_x = {1'b0, haddr} - GOOSE_X;

assign goose_sprite_y = ({1'b0, vaddr} >= goose_y && {1'b0, vaddr} < (goose_y + GOOSE_HEIGHT)) ? goose_diff_y[5:0] : 6'd0;
assign goose_sprite_x = ({1'b0, haddr} >= GOOSE_X && {1'b0, haddr} < (GOOSE_X + GOOSE_WIDTH)) ? goose_diff_x[4:0] : 5'd0;

// Emblem sprite coordinates (for obstacle 2)
wire [5:0] emblem_sprite_y;
wire [5:0] emblem_sprite_x;
wire [10:0] emblem_diff_y = {1'b0, vaddr} - (FLOOR_Y - UW_HEIGHT);
wire [10:0] emblem_diff_x = {1'b0, haddr} - obs2_x;

assign emblem_sprite_y = ({1'b0, vaddr} >= (FLOOR_Y - UW_HEIGHT) && vaddr < FLOOR_Y) ? emblem_diff_y[5:0] : 6'd0;
assign emblem_sprite_x = ({1'b0, haddr} >= obs2_x && {1'b0, haddr} < (obs2_x + UW_WIDTH)) ? emblem_diff_x[5:0] : 6'd0;

always @(posedge clk) begin
    if (sys_rst) begin
        layers <= 6'd0;
        goose_r <= 2'b00;
        goose_g <= 2'b00;
        goose_b <= 2'b00;
        emblem_r <= 2'b00;
        emblem_g <= 2'b00;
        emblem_b <= 2'b00;
    end
    else begin
        layers <= 6'd0;
        
        // Default goose colors (will be overridden if goose is drawn)
        goose_r <= 2'b11;
        goose_g <= 2'b11;
        goose_b <= 2'b00;
        
        if (display_on) begin
            // Layer 5: Sky background (everything above ground)
            if (vaddr < FLOOR_Y) begin
                layers[5] <= 1'b1;
            end
            
            // Layer 4: Ground area (everything at or below FLOOR_Y) - solid dark grey
            if (vaddr >= FLOOR_Y) begin
                layers[4] <= 1'b1;
            end
            
            // Layer 3: Floor texture (reduced pattern on first 4 rows of ground)
            if (vaddr >= FLOOR_Y && vaddr < (FLOOR_Y + 4)) begin
                // Index into 128-bit repeating pattern using lower 7 bits of scroll position
                // Pattern repeats twice across the 256-pixel horizontal space
                layers[3] <= floor_pattern[vaddr - FLOOR_Y][flooraddr[6:0]];
            end
            
            // Layer 0: Goose sprite
            if ({1'b0, haddr} >= GOOSE_X && {1'b0, haddr} < (GOOSE_X + GOOSE_WIDTH) &&
                {1'b0, vaddr} >= goose_y && {1'b0, vaddr} < (goose_y + GOOSE_HEIGHT) &&
                game_start_blink) begin
                
                // Body (Brown)
                if (goose_sprite_y >= 20 && goose_sprite_y <= 35 &&
                    goose_sprite_x >= 5 && goose_sprite_x <= 25) begin
                    layers[0] <= 1'b1;
                    if (game_over) begin
                        goose_r <= 2'b11; goose_g <= 2'b00; goose_b <= 2'b00;
                    end else begin
                        goose_r <= 2'b10; goose_g <= 2'b10; goose_b <= 2'b01;
                    end
                end
                // Neck (Black)
                else if (goose_sprite_y >= 10 && goose_sprite_y < 20 &&
                         goose_sprite_x >= 18 && goose_sprite_x <= 22) begin
                    layers[0] <= 1'b1;
                    if (game_over) begin
                         goose_r <= 2'b11; goose_g <= 2'b00; goose_b <= 2'b00;
                    end else begin
                         goose_r <= 2'b00; goose_g <= 2'b00; goose_b <= 2'b00;
                    end
                end
                // Head (Black)
                else if (goose_sprite_y >= 5 && goose_sprite_y < 10 &&
                         goose_sprite_x >= 18 && goose_sprite_x <= 26) begin
                    layers[0] <= 1'b1;
                    if (game_over) begin
                         goose_r <= 2'b11; goose_g <= 2'b00; goose_b <= 2'b00;
                    end else begin
                         goose_r <= 2'b00; goose_g <= 2'b00; goose_b <= 2'b00;
                    end
                end
                // Beak (Orange)
                else if (goose_sprite_y >= 7 && goose_sprite_y <= 9 &&
                         goose_sprite_x >= 26 && goose_sprite_x <= 29) begin
                    layers[0] <= 1'b1;
                    if (game_over) begin
                         goose_r <= 2'b11; goose_g <= 2'b00; goose_b <= 2'b00;
                    end else begin
                         goose_r <= 2'b11; goose_g <= 2'b10; goose_b <= 2'b01;
                    end
                end
                // Legs (Black)
                else if (goose_sprite_y > 35 && goose_sprite_y <= 39 &&
                         ((goose_sprite_x >= 10 && goose_sprite_x <= 12) ||
                          (goose_sprite_x >= 18 && goose_sprite_x <= 20))) begin
                    layers[0] <= 1'b1;
                    if (game_over) begin
                         goose_r <= 2'b11; goose_g <= 2'b00; goose_b <= 2'b00;
                    end else begin
                         goose_r <= 2'b00; goose_g <= 2'b00; goose_b <= 2'b00;
                    end
                end
            end

            // Layer 2: UW emblem obstacle (shield with coat of arms) - 40×48 pixels
            if (obstacle_select[1]) begin
                if ({1'b0, haddr} >= obs2_x && {1'b0, haddr} < (obs2_x + UW_WIDTH) &&
                    vaddr >= (FLOOR_Y - UW_HEIGHT) && vaddr < FLOOR_Y) begin
                    
                    // Parametric UW emblem rendering (40×48 shield)
                    // Priority: specific details over general areas
                    
                    // === LIONS (three simplified red rampant lions) ===
                    // Upper-left lion: centered ~(11, 10), 10×10 box
                    if (((emblem_sprite_y >= 7 && emblem_sprite_y <= 13) && 
                         (emblem_sprite_x >= 7 && emblem_sprite_x <= 15)) &&
                        (// Body: 6×6 core
                         ((emblem_sprite_y >= 8 && emblem_sprite_y <= 13) && (emblem_sprite_x >= 8 && emblem_sprite_x <= 13)) ||
                         // Head: 3×3 top-right
                         ((emblem_sprite_y >= 7 && emblem_sprite_y <= 9) && (emblem_sprite_x >= 12 && emblem_sprite_x <= 14)) ||
                         // Raised paw: 2×2
                         ((emblem_sprite_y >= 9 && emblem_sprite_y <= 10) && (emblem_sprite_x >= 14 && emblem_sprite_x <= 15)))) begin
                        layers[2] <= 1'b1;
                        emblem_r <= 2'b10; emblem_g <= 2'b00; emblem_b <= 2'b00; // Red #AA0000
                    end
                    // Upper-right lion: centered ~(29, 10), mirrored
                    else if (((emblem_sprite_y >= 7 && emblem_sprite_y <= 13) && 
                              (emblem_sprite_x >= 25 && emblem_sprite_x <= 33)) &&
                             (// Body: 6×6 core
                              ((emblem_sprite_y >= 8 && emblem_sprite_y <= 13) && (emblem_sprite_x >= 27 && emblem_sprite_x <= 32)) ||
                              // Head: 3×3 top-left
                              ((emblem_sprite_y >= 7 && emblem_sprite_y <= 9) && (emblem_sprite_x >= 26 && emblem_sprite_x <= 28)) ||
                              // Raised paw: 2×2
                              ((emblem_sprite_y >= 9 && emblem_sprite_y <= 10) && (emblem_sprite_x >= 25 && emblem_sprite_x <= 26)))) begin
                        layers[2] <= 1'b1;
                        emblem_r <= 2'b10; emblem_g <= 2'b00; emblem_b <= 2'b00; // Red #AA0000
                    end
                    // Lower-center lion: centered ~(20, 32), slightly larger 12×10
                    else if (((emblem_sprite_y >= 28 && emblem_sprite_y <= 37) && 
                              (emblem_sprite_x >= 15 && emblem_sprite_x <= 25)) &&
                             (// Body: 8×8 core
                              ((emblem_sprite_y >= 30 && emblem_sprite_y <= 37) && (emblem_sprite_x >= 16 && emblem_sprite_x <= 24)) ||
                              // Head: 4×4 top
                              ((emblem_sprite_y >= 28 && emblem_sprite_y <= 31) && (emblem_sprite_x >= 18 && emblem_sprite_x <= 22)) ||
                              // Paws: 2×2 each side
                              ((emblem_sprite_y >= 32 && emblem_sprite_y <= 33) && 
                               ((emblem_sprite_x >= 15 && emblem_sprite_x <= 16) || (emblem_sprite_x >= 24 && emblem_sprite_x <= 25))))) begin
                        layers[2] <= 1'b1;
                        emblem_r <= 2'b10; emblem_g <= 2'b00; emblem_b <= 2'b00; // Red #AA0000
                    end
                    
                    // === WHITE CHEVRON INTERIOR (inside black chevron) ===
                    // Chevron apex at (20, 24), arms extend to ~(6, 12) and (34, 12)
                    // White fill: 2-3px inside the black outline
                    else if (((emblem_sprite_y >= 14 && emblem_sprite_y <= 23)) &&
                             (// Left arm white fill
                              ((emblem_sprite_x >= (8 + (23 - emblem_sprite_y))) && 
                               (emblem_sprite_x <= (10 + (23 - emblem_sprite_y)))) ||
                              // Right arm white fill
                              ((emblem_sprite_x >= (30 - (23 - emblem_sprite_y))) && 
                               (emblem_sprite_x <= (32 - (23 - emblem_sprite_y)))))) begin
                        layers[2] <= 1'b1;
                        emblem_r <= 2'b11; emblem_g <= 2'b11; emblem_b <= 2'b11; // White #FFFFFF
                    end
                    
                    // === BLACK CHEVRON OUTLINE (V-shape, 3-4px thick) ===
                    // Left arm: from (6, 12) to (20, 24)
                    // Right arm: from (34, 12) to (20, 24)
                    else if (((emblem_sprite_y >= 12 && emblem_sprite_y <= 25)) &&
                             (// Left arm black outline (4px wide diagonal)
                              ((emblem_sprite_x >= (5 + (24 - emblem_sprite_y))) && 
                               (emblem_sprite_x <= (8 + (24 - emblem_sprite_y)))) ||
                              // Right arm black outline (4px wide diagonal)
                              ((emblem_sprite_x >= (32 - (24 - emblem_sprite_y))) && 
                               (emblem_sprite_x <= (35 - (24 - emblem_sprite_y)))))) begin
                        layers[2] <= 1'b1;
                        emblem_r <= 2'b00; emblem_g <= 2'b00; emblem_b <= 2'b00; // Black #000000
                    end
                    
                    // === WHITE INNER BORDER (between black outline and gold field) ===
                    else if (
                        // Top inner border (y=2): just inside black outline
                        ((emblem_sprite_y == 2) && 
                         (emblem_sprite_x >= 1 && emblem_sprite_x <= 38)) ||
                        // Upper sides inner (y=3-15)
                        ((emblem_sprite_y >= 3 && emblem_sprite_y <= 15) && 
                         ((emblem_sprite_x == 1) || (emblem_sprite_x == 38))) ||
                        // Middle sides inner (y=16-30)
                        ((emblem_sprite_y >= 16 && emblem_sprite_y <= 30) && 
                         ((emblem_sprite_x == 1) || (emblem_sprite_x == 38))) ||
                        // Lower sides taper inner (y=31-35)
                        ((emblem_sprite_y >= 31 && emblem_sprite_y <= 35) && 
                         ((emblem_sprite_x == (1 + (emblem_sprite_y - 30))) || 
                          (emblem_sprite_x == (38 - (emblem_sprite_y - 30))))) ||
                        // Lower taper inner (y=36-42)
                        ((emblem_sprite_y >= 36 && emblem_sprite_y <= 42) && 
                         ((emblem_sprite_x == (6 + (emblem_sprite_y - 35))) || 
                          (emblem_sprite_x == (33 - (emblem_sprite_y - 35))))) ||
                        // Bottom approach inner (y=43-45)
                        ((emblem_sprite_y >= 43 && emblem_sprite_y <= 45) && 
                         ((emblem_sprite_x == (14 + (emblem_sprite_y - 43))) || 
                          (emblem_sprite_x == (25 - (emblem_sprite_y - 43)))))
                    ) begin
                        layers[2] <= 1'b1;
                        emblem_r <= 2'b11; emblem_g <= 2'b11; emblem_b <= 2'b11; // White inner border #FFFFFF
                    end
                    
                    // === GOLD FIELD BACKGROUND (inside shield, behind everything) ===
                    // Shield shape: heater shield with curved sides and pointed bottom
                    // Top is flat/straight, sides taper inward gradually, bottom comes to point at center
                    else if (
                        // Top section (y=3-15): full width inside borders
                        ((emblem_sprite_y >= 3 && emblem_sprite_y <= 15) && 
                         (emblem_sprite_x >= 2 && emblem_sprite_x <= 37)) ||
                        // Middle section (y=16-30): full width
                        ((emblem_sprite_y >= 16 && emblem_sprite_y <= 30) && 
                         (emblem_sprite_x >= 2 && emblem_sprite_x <= 37)) ||
                        // Lower start taper (y=31-35)
                        ((emblem_sprite_y >= 31 && emblem_sprite_y <= 35) && 
                         (emblem_sprite_x >= (2 + (emblem_sprite_y - 30)) && 
                          emblem_sprite_x <= (37 - (emblem_sprite_y - 30)))) ||
                        // Lower taper (y=36-42): curves to point
                        ((emblem_sprite_y >= 36 && emblem_sprite_y <= 42) && 
                         (emblem_sprite_x >= (7 + (emblem_sprite_y - 35)) && 
                          emblem_sprite_x <= (32 - (emblem_sprite_y - 35)))) ||
                        // Bottom approach (y=43-45): narrowing
                        ((emblem_sprite_y >= 43 && emblem_sprite_y <= 45) && 
                         (emblem_sprite_x >= (15 + (emblem_sprite_y - 43)) && 
                          emblem_sprite_x <= (24 - (emblem_sprite_y - 43))))
                    ) begin
                        layers[2] <= 1'b1;
                        emblem_r <= 2'b11; emblem_g <= 2'b10; emblem_b <= 2'b00; // Gold #FFAA00 (orange-gold)
                    end
                    
                    // === BLACK SHIELD OUTLINE (thin, follows shield curve) ===
                    else if (
                        // Top edge (y=0-1): thin top border
                        ((emblem_sprite_y <= 1) && 
                         (emblem_sprite_x >= 2 && emblem_sprite_x <= 37)) ||
                        // Top corners (y=0-1)
                        ((emblem_sprite_y <= 1) && 
                         ((emblem_sprite_x <= 1) || (emblem_sprite_x >= 38))) ||
                        // Upper sides (y=2-15): straight sides
                        ((emblem_sprite_y >= 2 && emblem_sprite_y <= 15) && 
                         ((emblem_sprite_x == 0) || (emblem_sprite_x == 39))) ||
                        // Middle sides (y=16-30): slight taper
                        ((emblem_sprite_y >= 16 && emblem_sprite_y <= 30) && 
                         ((emblem_sprite_x == 0) || (emblem_sprite_x == 39))) ||
                        // Lower sides start taper (y=31-35)
                        ((emblem_sprite_y >= 31 && emblem_sprite_y <= 35) && 
                         ((emblem_sprite_x == (emblem_sprite_y - 30)) || 
                          (emblem_sprite_x == (39 - (emblem_sprite_y - 30))))) ||
                        // Lower taper (y=36-42): curves inward to point
                        ((emblem_sprite_y >= 36 && emblem_sprite_y <= 42) && 
                         ((emblem_sprite_x == (5 + (emblem_sprite_y - 35))) || 
                          (emblem_sprite_x == (34 - (emblem_sprite_y - 35))))) ||
                        // Bottom approach (y=43-45): narrowing to tip
                        ((emblem_sprite_y >= 43 && emblem_sprite_y <= 45) && 
                         ((emblem_sprite_x == (13 + (emblem_sprite_y - 43))) || 
                          (emblem_sprite_x == (26 - (emblem_sprite_y - 43))))) ||
                        // Bottom tip (y=46-47): point
                        ((emblem_sprite_y >= 46 && emblem_sprite_y <= 47) && 
                         ((emblem_sprite_x == 19) || (emblem_sprite_x == 20)))
                    ) begin
                        layers[2] <= 1'b1;
                        emblem_r <= 2'b00; emblem_g <= 2'b00; emblem_b <= 2'b00; // Black outline #000000
                    end
                end
            end
        end
    end
end

// Ground texture initialization - reduced from original dinogame pattern
initial begin
    // First 128 bits from each of the first 4 rows of original 256-bit pattern
    // Pattern repeats twice horizontally
    floor_pattern[0] = 128'b00000000000000000000000000000000000000000000000000000000000000000000000000000000111000000000000000000000000000000000000000000000;
    floor_pattern[1] = 128'b11111111111111111111111111111111111111111111111111111111111111111111111111111111001111100011111111111111111111111111111111111111;
    floor_pattern[2] = 128'b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000111110000000000000000000000000000000000000;
    floor_pattern[3] = 128'b00000000100000000000001000000000000000110110000001000000000001000000000000000000000001000000100000000001000000000000000000000010;
end

endmodule
