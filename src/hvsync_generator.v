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
  output wire [9:0] hpos,
  output wire [9:0] vpos
);

  // VGA 640x480 @ 60Hz timing
  localparam H_DISPLAY = 640;
  localparam H_SYNC_START = 656;  // 640 + 16 (front porch)
  localparam H_SYNC_END = 752;    // 656 + 96 (sync pulse)
  localparam H_TOTAL = 799;       // 800 - 1
  
  localparam V_DISPLAY = 480;
  localparam V_SYNC_START = 490;  // 480 + 10 (front porch)
  localparam V_SYNC_END = 492;    // 490 + 2 (sync pulse)
  localparam V_TOTAL = 524;       // 525 - 1

  reg [9:0] h_count;
  reg [9:0] v_count;

  // VGA timing state machine
  always @(posedge clk) begin
    if (reset) begin
      h_count <= 10'd0;
      v_count <= 10'd0;
      hsync <= 1'b1;  // Sync inactive (high) during reset
      vsync <= 1'b1;
    end else begin
      // Horizontal counter - increment every clock
      if (h_count == H_TOTAL) begin
        h_count <= 10'd0;
        // Vertical counter - increment at end of line
        v_count <= (v_count == V_TOTAL) ? 10'd0 : v_count + 10'd1;
      end else begin
        h_count <= h_count + 10'd1;
      end
      
      // Generate sync pulses (active low)
      hsync <= (h_count >= H_SYNC_START && h_count < H_SYNC_END) ? 1'b0 : 1'b1;
      vsync <= (v_count >= V_SYNC_START && v_count < V_SYNC_END) ? 1'b0 : 1'b1;
    end
  end

  // Display enable - single centralized check saves area in rendering modules
  assign display_on = (h_count < H_DISPLAY) && (v_count < V_DISPLAY);
  // Pixel position outputs for rendering engine
  assign hpos = h_count;
  assign vpos = v_count;

endmodule

