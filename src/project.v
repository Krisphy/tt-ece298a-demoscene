/*
 * Goose Game - Chrome Dino style game for Tiny Tapeout
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

  // VGA signals
  wire hsync;
  wire vsync;
  wire [1:0] R;
  wire [1:0] G;
  wire [1:0] B;
  wire display_on;
  wire [9:0] hpos;
  wire [9:0] vpos;

  // Game signals
  wire jump_button = ui_in[0];
  wire halt_button = ui_in[1];
  
  // Game state
  localparam START_TIME = 30000000;  // ~1.2 seconds at 25MHz
  reg [31:0] start_ctr;
  reg game_over;
  reg [19:0] no_jump_ctr;
  reg game_running;
  
  wire game_reset = game_over & jump_button & (no_jump_ctr > 20'd100000);
  wire game_halt = game_over || halt_button || (start_ctr < START_TIME);
  wire game_start_blink = (start_ctr >= START_TIME) || start_ctr[22] || game_over;

  // Inter-module connections
  wire [23:0] speed;
  wire [2:0] obstacle_select;
  reg [2:0] obstacle_select_last;
  reg [2:0] obstacle_type;
  wire collision;
  wire [10:0] scrolladdr;
  wire [6:0] jump_pos;
  wire [4:0] random;

  // Audio signals
  wire audio_pwm;
  reg event_jump_prev;
  wire event_jump = jump_button && !event_jump_prev;
  wire event_death = collision && !game_over;
  wire event_highscore = 1'b0;  // TODO: Implement high score detection

  // TinyVGA PMOD output
  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

  // Audio PWM output on uio[7] (A_PWM per proposal)
  assign uio_out[7] = audio_pwm;
  assign uio_out[6:0] = 7'b0;
  assign uio_oe[7] = 1'b1;
  assign uio_oe[6:0] = 7'b0;

  // Suppress unused signals warning
  wire _unused_ok = &{ena, ui_in[7:2], uio_in};

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
    .speed(speed),
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

  // Rendering engine
  rendering rendering_inst (
    .R(R),
    .G(G),
    .B(B),
    .collision(collision),
    .obstacle_select(obstacle_select),
    .game_over(game_over),
    .game_start_blink(game_start_blink),
    .obstacle_type(obstacle_type),
    .jump_pos(jump_pos),
    .vaddr(vpos),
    .haddr(hpos),
    .scrolladdr(scrolladdr),
    .display_on(display_on),
    .clk(clk),
    .sys_rst(~rst_n)
  );

  // Audio module
  audio audio_inst (
    .clk(clk),
    .rst_n(rst_n),
    .event_jump(event_jump),
    .event_death(event_death),
    .event_highscore(event_highscore),
    .game_running(game_running),
    .audio_pwm(audio_pwm)
  );

  // Game state machine
  always @(posedge clk) begin
    if (~rst_n) begin
      game_over <= 1'b0;
      start_ctr <= 32'd0;
      no_jump_ctr <= 20'd0;
      obstacle_select_last <= 3'd0;
      obstacle_type <= 3'd0;
      game_running <= 1'b0;
      event_jump_prev <= 1'b0;
    end
    else begin
      // Track previous jump button state for edge detection
      event_jump_prev <= jump_button;

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
        obstacle_type <= 3'd0;
      end

      // Collision detection
      if (collision && !game_over) begin
        game_over <= 1'b1;
      end

      // Generate new obstacle types when obstacles spawn
      if (obstacle_select[0] && !obstacle_select_last[0]) begin
        obstacle_type[0] <= random[0];
      end
      if (obstacle_select[1] && !obstacle_select_last[1]) begin
        obstacle_type[1] <= random[1];
      end
      if (obstacle_select[2] && !obstacle_select_last[2]) begin
        obstacle_type[2] <= random[2];
      end
      
      obstacle_select_last <= obstacle_select;
    end
  end

endmodule
