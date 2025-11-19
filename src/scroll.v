/*
 * Scrolling logic for goose game
 * Area-optimized with synchronous reset
 */

`default_nettype none

module scroll (
    input wire halt,
    output reg [10:0] pos,

    input wire game_rst,
    input wire clk,
    input wire sys_rst
);

localparam [17:0] SCROLL_PERIOD = 18'd250000; // 10ms at 25MHz
localparam [10:0] MOVE_STEP = 11'd2;          // Pixels per tick

reg [17:0] ctr;

always @(posedge clk) begin
    if (game_rst || sys_rst) begin
        pos <= 11'd0;
        ctr <= 18'd0;
    end
    else if (!halt) begin
        if (ctr >= SCROLL_PERIOD) begin
            ctr <= 18'd0;
            pos <= pos + MOVE_STEP;
        end
        else begin
            ctr <= ctr + 18'd1;
        end
    end
end

endmodule
