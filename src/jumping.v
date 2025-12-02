/*
 * Jump physics for goose game
 */

`default_nettype none

module jumping (
    input wire jump,
    input wire halt,
    input wire [23:0] speed,
    output reg [6:0] jump_pos,
    input wire game_rst,
    input wire clk,
    input wire sys_rst
);

reg [23:0] ctr;
reg [5:0] frame;
reg in_air;
reg [6:0] y_table[25:0];

wire [4:0] table_idx = (frame <= 6'd25) ? frame[4:0] : (5'd50 - frame[4:0]);

always @(posedge clk) begin
    if (game_rst || sys_rst) begin
        ctr <= 24'd0;
        frame <= 6'd0;
        in_air <= 1'b0;
        jump_pos <= 7'd0;
    end
    else begin
        jump_pos <= y_table[table_idx];
        if (!halt) begin
            if (in_air) begin
                ctr <= ctr + 24'd1;
                if (ctr == speed) begin
                    ctr <= 24'd0;
                    frame <= frame + 6'd1;
                    if (frame + 6'd1 >= 6'd50) begin
                        frame <= 6'd0;
                        in_air <= 1'b0;
                    end
                end
            end
            else if (jump)
                in_air <= 1'b1;
        end
    end
end

initial begin
    y_table[0]  = 7'd0;   y_table[1]  = 7'd8;   y_table[2]  = 7'd16;  y_table[3]  = 7'd23;
    y_table[4]  = 7'd30;  y_table[5]  = 7'd36;  y_table[6]  = 7'd43;  y_table[7]  = 7'd49;
    y_table[8]  = 7'd56;  y_table[9]  = 7'd61;  y_table[10] = 7'd66;  y_table[11] = 7'd70;
    y_table[12] = 7'd75;  y_table[13] = 7'd79;  y_table[14] = 7'd83;  y_table[15] = 7'd87;
    y_table[16] = 7'd90;  y_table[17] = 7'd92;  y_table[18] = 7'd95;  y_table[19] = 7'd98;
    y_table[20] = 7'd99;  y_table[21] = 7'd100; y_table[22] = 7'd101; y_table[23] = 7'd103;
    y_table[24] = 7'd103; y_table[25] = 7'd104;
end

endmodule
