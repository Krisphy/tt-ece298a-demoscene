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
  wire halt_button = ui_in[1];

  // ============================================================================
  // Inter-Module Signals
  // ============================================================================
  
  // From game_controller
  wire game_over;
  wire game_reset;
  wire game_halt;
  wire game_start_blink;
  wire game_running;
  wire obstacle_active;
  
  // From jumping
  wire [6:0] jump_pos;
  // in_air is internal to jumping module logic, not needed at top level
  
  // From scroll
  wire [10:0] scrolladdr;
  wire [23:0] speed;
  
  // From rendering
  wire collision;
  
  // From rng
  wire [4:0] random;

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
    .halt_button(halt_button),
    .collision(collision),
    .scrolladdr(scrolladdr),
    // random input removed from game_controller
    .game_over(game_over),
    .game_reset(game_reset),
    .game_halt(game_halt),
    .game_start_blink(game_start_blink),
    .game_running(game_running),
    .obstacle_active(obstacle_active)
  );

  // Jump physics
  jumping jumping_inst (
    .speed(24'd250000),
    .jump(jump_button),
    .jump_pos(jump_pos),
    .in_air(), // Output unused at top level
    .halt(game_halt),
    .game_rst(game_reset),
    .clk(clk),
    .sys_rst(~rst_n)
  );

  // Scrolling logic
  // speed input is driven by the wire speed? Wait, scroll has input speed?
  // Checking scroll.v: output wire [23:0] speed.
  // Ah, scroll PRODUCES speed.
  // My previous analysis was wrong. scroll.v line 11: output wire [23:0] speed.
  // So scroll instantiaton needs to CONNECT to wire speed.
  scroll scroll_inst (
    .speed(speed), // Output from scroll
    .pos(scrolladdr),
    .halt(game_halt),
    .speed_change(8'd4),  // Acceleration
    .move_amt(8'd2),      // Scroll speed
    .game_rst(game_reset),
    .clk(clk),
    .sys_rst(~rst_n)
  );

  // Random number generator for obstacle types
  rng rng_inst (
    .entropy_in(jump_button),
    .out(random),
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
    .jump_pos(jump_pos),
    .vaddr(vpos),
    .haddr(hpos),
    .scrolladdr(scrolladdr),
    .display_on(display_on),
    .clk(clk),
    .sys_rst(~rst_n)
  );

endmodule
