/*
 * Simple VGA example - moving color pattern
 * Original demo for testing VGA output
 */

`default_nettype none

module tt_um_vga_example(
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
  wire [9:0] pix_x;
  wire [9:0] pix_y;

  // TinyVGA PMOD
  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

  // Unused outputs assigned to 0.
  assign uio_out = 8'h00;
  assign uio_oe  = 8'h00;

  // Suppress unused signals warning
  wire _unused_ok = &{ena, ui_in, uio_in};

  reg [9:0] counter;

  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(~rst_n),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(display_on),
    .hpos(pix_x),
    .vpos(pix_y)
  );
  
  // Simple animated color pattern
  wire [9:0] moving_x = pix_x + counter;
  assign R = display_on ? {moving_x[5], pix_y[2]} : 2'b00;
  assign G = display_on ? {moving_x[6], pix_y[2]} : 2'b00;
  assign B = display_on ? {moving_x[7], pix_y[5]} : 2'b00;
  
  // Counter increments once per frame
  always @(posedge vsync, negedge rst_n) begin
    if (~rst_n) begin
      counter <= 10'd0;
    end else begin
      counter <= counter + 10'd1;
    end
  end
  
endmodule

