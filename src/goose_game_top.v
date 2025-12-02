/*
 * Goose Game - Chrome Dino style game for Tiny Tapeout
 * 
 * Top-level module that instantiates and connects all submodules:
 * - Game Controller (game state, obstacles)
 * - Video Controller (rendering)
 * - Jump Physics
 * - Scroll Logic
 * - VGA Sync Generator
 * - Random Number Generator
 * 
 * Jump over ION railway crossings and dodge UW emblems!
 */

`default_nettype none

module tt_um_goose_game(
  input  wire [7:0] ui_in,    // Dedicated inputs
  output wire [7:0] uo_out,   // Dedicated outputs
  input  wire [7:0] uio_in,   // IOs: Input path
  output wire [7:0] uio_out,  // IOs: Output path
  output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
  input  wire       ena,      // always 1 when the design is powered, so you can ignore it
  input  wire       clk,      // clock
  input  wire       rst_n     // reset_n - low to reset
);

  // ============================================================================
  // VGA Signals
  // ============================================================================
  
  wire hsync;
  wire vsync;
  wire [1:0] R;
  wire [1:0] G;
  wire [1:0] B;
  wire display_on;
  wire [9:0] hpos;
  wire [9:0] vpos;

  // ============================================================================
  // User Inputs
  // ============================================================================
  
  wire jump_button = ui_in[0];
  wire reset_button = ui_in[1];

  // ============================================================================
  // Inter-Module Signals
  // ============================================================================
  
  // From game_controller
  wire game_over;
  wire game_reset;
  wire game_halt;
  wire game_start_blink;
  wire obstacle_active;
  wire [9:0] obstacle_pos;
  wire [4:0] speed_level;
  
  // From jumping
  wire [6:0] jump_pos;
  
  // From scroll
  wire [10:0] scrolladdr;
  
  // From rendering
  wire collision;
  

  // ============================================================================
  // Output Assignments
  // ============================================================================
  
  // TinyVGA PMOD output
  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

  // Bidirectional pins unused
  assign uio_out = 8'b0;
  assign uio_oe = 8'b0;
  
  /* verilator lint_off UNUSEDSIGNAL */
  // Suppress unused signals warning for standard interface
  wire _unused_ok = &{ena, ui_in[7:2], uio_in};
  /* verilator lint_on UNUSEDSIGNAL */

  // ============================================================================
  // Module Instantiations
  // ============================================================================

  // VGA sync generator
  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(~rst_n),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(display_on),
    .hpos(hpos),
    .vpos(vpos)
  );

  // Game Controller - All game state logic
  game_controller game_ctrl(
    .clk(clk),
    .rst_n(rst_n),
    .jump_button(jump_button),
    .reset_button(reset_button),
    .collision(collision),
    .scrolladdr(scrolladdr[9:0]),
    .game_over(game_over),
    .game_reset(game_reset),
    .game_halt(game_halt),
    .game_start_blink(game_start_blink),
    .obstacle_active(obstacle_active),
    .obstacle_pos(obstacle_pos),
    .speed_level(speed_level)
  );

  // Jump physics
  jumping jumping_inst (
    .speed(24'd250000),
    .jump(jump_button),
    .jump_pos(jump_pos),
    .halt(game_halt),
    .game_rst(game_reset),
    .clk(clk),
    .sys_rst(~rst_n)
  );

  // Scrolling logic
  scroll scroll_inst (
    .pos(scrolladdr),
    .halt(game_halt),
    .speed_level(speed_level),
    .game_rst(game_reset),
    .clk(clk),
    .sys_rst(~rst_n)
  );

  // Video Controller / Rendering engine
  rendering video_ctrl(
    .R(R),
    .G(G),
    .B(B),
    .collision(collision),
    .game_over(game_over),
    .game_start_blink(game_start_blink),
    .obstacle_active(obstacle_active),
    .obstacle_pos(obstacle_pos),
    .jump_pos(jump_pos),
    .vaddr(vpos),
    .haddr(hpos),
    .scrolladdr(scrolladdr),
    .display_on(display_on),
    .clk(clk),
    .sys_rst(~rst_n)
  );

endmodule
