`timescale 1ns / 1ps

// For single cycle CPU, every instruction happens in one clock tick but the board clock is 100 MHz which is too fast, so we need to slow the cpu clock down

module clk_div(
    input clk, // 100 MHz input
    input rst_n, // active low reset
    output clk_out // slowed clock
    );
    
    // period = 4 --> 100 MHz / 4 = 25 MHz
    // period = 10 --> 100 MHz / 10 = 10 MHz (slower clock and better)
    
    parameter period = 4;
    
    reg [31:0] cnt;
    reg clk_out_reg;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt <= 0;
            clk_out_reg <= 0;
        end else begin
            if (cnt == (period >> 1) - 1) begin
                clk_out_reg <= ~clk_out_reg;
                cnt <= 0;
            end else begin
                cnt <= cnt+1;
            end
        end
    end
    
    BUFG BUFG_inst ( .O(clk_out), .I(clk_out_reg) );
    
endmodule
