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

  // horizontal constants
  parameter H_DISPLAY       = 640; // horizontal display width
  parameter H_BACK          =  48; // horizontal left border (back porch)
  parameter H_FRONT         =  16; // horizontal right border (front porch)
  parameter H_SYNC          =  96; // horizontal sync width

  // vertical constants
  parameter V_DISPLAY       = 480; // vertical display height
  parameter V_TOP           =  33; // vertical top border
  parameter V_BOTTOM        =  10; // vertical bottom border
  parameter V_SYNC          =   2; // vertical sync # lines

  // derived constants
  parameter H_SYNC_START    = H_DISPLAY + H_FRONT;
  parameter H_SYNC_END      = H_DISPLAY + H_FRONT + H_SYNC - 1;
  parameter H_MAX           = H_DISPLAY + H_BACK + H_FRONT + H_SYNC - 1;

  parameter V_SYNC_START    = V_DISPLAY + V_BOTTOM;
  parameter V_SYNC_END      = V_DISPLAY + V_BOTTOM + V_SYNC - 1;
  parameter V_MAX           = V_DISPLAY + V_TOP + V_BOTTOM + V_SYNC - 1;

  wire hmaxxed = (hpos == H_MAX) || reset;	// set when hpos is maximum or on reset
  wire vmaxxed = (vpos == V_MAX) || reset;	// set when vpos is maximum or on reset

  // horizontal position counter and hsync
  always @(posedge clk) begin
    hsync <= (hpos >= H_SYNC_START && hpos <= H_SYNC_END);
    if (hmaxxed)
      hpos <= 0;
    else
      hpos <= hpos + 1;
  end

  // vertical position counter and vsync
  always @(posedge clk) begin
    vsync <= (vpos >= V_SYNC_START && vpos <= V_SYNC_END);
    if (hmaxxed) begin
      if (vmaxxed)
        vpos <= 0;
      else
        vpos <= vpos + 1;
    end
  end

  // display_on is set when beam is in "safe" visible frame
  assign display_on = (hpos < H_DISPLAY) && (vpos < V_DISPLAY);

endmodule

