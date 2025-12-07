/*
 * VGA timing generator
 * 640x480 @ 60Hz
 */

`default_nettype none

module hvsync_generator(
  input wire clk,
  input wire reset,
  output reg hsync,
  output reg vsync,
  output wire display_on,
  output reg [9:0] hpos,
  output reg [9:0] vpos
);

  // VGA 640x480 @ 60Hz timing parameters
  localparam H_DISPLAY = 640;
  localparam H_FRONT = 16;
  localparam H_SYNC = 96;
  localparam H_BACK = 48;
  
  localparam V_DISPLAY = 480;
  localparam V_BOTTOM = 10;
  localparam V_SYNC = 2;
  localparam V_TOP = 33;
  
  // Derived constants
  localparam H_SYNC_START = H_DISPLAY + H_FRONT;              // 656
  localparam H_SYNC_END = H_DISPLAY + H_FRONT + H_SYNC - 1;   // 751
  localparam H_MAX = H_DISPLAY + H_BACK + H_FRONT + H_SYNC - 1; // 799
  
  localparam V_SYNC_START = V_DISPLAY + V_BOTTOM;             // 490
  localparam V_SYNC_END = V_DISPLAY + V_BOTTOM + V_SYNC - 1;  // 491
  localparam V_MAX = V_DISPLAY + V_TOP + V_BOTTOM + V_SYNC - 1; // 524

  reg [9:0] h_count;
  reg [9:0] v_count;
  
  wire hmaxxed = (h_count == H_MAX) || reset;
  wire vmaxxed = (v_count == V_MAX) || reset;

  // Horizontal counter and sync generation
  always @(posedge clk) begin
    hsync <= ~(h_count >= H_SYNC_START && h_count <= H_SYNC_END);
    if (hmaxxed)
      h_count <= 10'd0;
    else
      h_count <= h_count + 10'd1;
  end

  // Vertical counter and sync generation
  always @(posedge clk) begin
    vsync <= ~(v_count >= V_SYNC_START && v_count <= V_SYNC_END);
    if (hmaxxed) begin
      if (vmaxxed)
        v_count <= 10'd0;
      else
        v_count <= v_count + 10'd1;
    end
  end

  // Display enable - active during visible area
  assign display_on = (h_count < H_DISPLAY) && (v_count < V_DISPLAY);
  // Pixel position outputs for rendering engine
  assign hpos = h_count;
  assign vpos = v_count;

endmodule

