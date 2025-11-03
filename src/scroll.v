/*
 * Scrolling logic for goose game
 * Area-optimized with synchronous reset
 */

`default_nettype none

module scroll (
    input wire halt,
    output reg [10:0] pos,
    output wire [23:0] speed,

    input wire [7:0] speed_change,
    input wire [7:0] move_amt,

    input wire game_rst,
    input wire clk,
    input wire sys_rst
);

localparam INITIAL_SPEED = 250000; // 10ms at 25MHz

reg [17:0] ctr;
reg [17:0] tick_time;

assign speed = {6'd0, tick_time};

always @(posedge clk) begin
    if (game_rst || sys_rst) begin
        pos <= 11'd0;
        ctr <= 18'd0;
        tick_time <= INITIAL_SPEED;
    end
    else if (!halt) begin
        ctr <= ctr + 18'd1;
        if (ctr >= tick_time) begin
            ctr <= 18'd0;
            tick_time <= tick_time - {10'd0, speed_change};
            pos <= pos + {3'd0, move_amt};
        end
    end
end

endmodule

