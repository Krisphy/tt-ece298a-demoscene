/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_example (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // Audio module signals
  wire audio_pwm;
  
  // Instantiate audio module
  audio audio_inst (
    .clk(clk),
    .rst_n(rst_n),
    .event_jump(ui_in[1]),        // Use ui_in[1] as jump button
    .event_death(ui_in[2]),       // Use ui_in[2] for death (test)
    .event_highscore(ui_in[3]),   // Use ui_in[3] for high score (test)
    .game_running(ui_in[0]),      // Use ui_in[0] to control game_running
    .audio_pwm(audio_pwm)
  );

  // Connect audio to uio_out[7] (A_PWM per proposal)
  assign uio_out[7] = audio_pwm;
  assign uio_oe[7] = 1'b1;       // Enable as output
  
  // Other outputs
  assign uio_out[6:0] = 7'b0;
  assign uio_oe[6:0] = 7'b0;
  assign uo_out = 8'b0;  // TODO: Connect VGA outputs here

  // Mark unused inputs
  wire _unused = &{ena, uio_in, 1'b0};

endmodule
