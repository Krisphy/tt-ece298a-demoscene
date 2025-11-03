/*
 * Jump physics for goose game
 * Area-optimized with synchronous reset
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
reg [8:0] frame;
reg in_air;

reg [6:0] y_table[50:0];

always @(posedge clk) begin
    if (game_rst || sys_rst) begin
        ctr <= 24'd0;
        frame <= 9'd0;
        in_air <= 1'b0;
        jump_pos <= 7'd0;
    end
    else begin
        jump_pos <= y_table[frame];

        if (!halt) begin
            if (in_air) begin
                ctr <= ctr + 24'd1;
                if (ctr == speed) begin
                    ctr <= 24'd0;
                    frame <= frame + 9'd1;

                    if (frame + 9'd1 >= 9'd50) begin
                        frame <= 9'd0;
                        in_air <= 1'b0;
                    end
                end
            end
            else if (jump) begin
                in_air <= 1'b1;
            end
        end
    end
end

// Precomputed jump arc (parabolic trajectory)
initial begin
    y_table[0]  = 7'd0;
    y_table[1]  = 7'd6;
    y_table[2]  = 7'd12;
    y_table[3]  = 7'd18;
    y_table[4]  = 7'd23;
    y_table[5]  = 7'd28;
    y_table[6]  = 7'd33;
    y_table[7]  = 7'd38;
    y_table[8]  = 7'd43;
    y_table[9]  = 7'd47;
    y_table[10] = 7'd51;
    y_table[11] = 7'd54;
    y_table[12] = 7'd58;
    y_table[13] = 7'd61;
    y_table[14] = 7'd64;
    y_table[15] = 7'd67;
    y_table[16] = 7'd69;
    y_table[17] = 7'd71;
    y_table[18] = 7'd73;
    y_table[19] = 7'd75;
    y_table[20] = 7'd76;
    y_table[21] = 7'd77;
    y_table[22] = 7'd78;
    y_table[23] = 7'd79;
    y_table[24] = 7'd79;
    y_table[25] = 7'd80;  // Peak of jump
    y_table[26] = 7'd79;
    y_table[27] = 7'd79;
    y_table[28] = 7'd78;
    y_table[29] = 7'd77;
    y_table[30] = 7'd76;
    y_table[31] = 7'd75;
    y_table[32] = 7'd73;
    y_table[33] = 7'd71;
    y_table[34] = 7'd69;
    y_table[35] = 7'd67;
    y_table[36] = 7'd64;
    y_table[37] = 7'd61;
    y_table[38] = 7'd58;
    y_table[39] = 7'd54;
    y_table[40] = 7'd51;
    y_table[41] = 7'd47;
    y_table[42] = 7'd43;
    y_table[43] = 7'd38;
    y_table[44] = 7'd33;
    y_table[45] = 7'd28;
    y_table[46] = 7'd23;
    y_table[47] = 7'd18;
    y_table[48] = 7'd12;
    y_table[49] = 7'd6;
    y_table[50] = 7'd0;
end

endmodule

