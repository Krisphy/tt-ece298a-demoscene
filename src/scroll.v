/*
 * Scrolling logic for goose game
 */

`default_nettype none

module scroll (
    input wire halt,
    input wire [3:0] speed_level,
    output reg [10:0] pos,
    input wire game_rst,
    input wire clk,
    input wire sys_rst
);

localparam [10:0] MOVE_STEP = 11'd2;

reg [17:0] ctr;
reg [17:0] current_period;

always @(*) begin
    if (speed_level >= 4'd8)
        current_period = 18'd10000;
    else case (speed_level[2:0])
        3'd0: current_period = 18'd125000;
        3'd1: current_period = 18'd110000;
        3'd2: current_period = 18'd95000;
        3'd3: current_period = 18'd80000;
        3'd4: current_period = 18'd65000;
        3'd5: current_period = 18'd50000;
        3'd6: current_period = 18'd35000;
        default: current_period = 18'd20000;
    endcase
end

always @(posedge clk) begin
    if (game_rst || sys_rst) begin
        pos <= 11'd0;
        ctr <= 18'd0;
    end
    else if (!halt) begin
        if (ctr >= current_period) begin
            ctr <= 18'd0;
            pos <= pos + MOVE_STEP;
        end
        else begin
            ctr <= ctr + 18'd1;
        end
    end
end

endmodule
