`timescale 1ns / 1ps

module pc(
    input clk,
    input rst,
    input cpu_halt,
    input cpu_step,
    input [31:0] nextPC,
    output reg [31:0] currentPC
    );
    
    reg step_s1, step_s2;
    
//reg step_q;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            step_s1 <= 1'b0;
            step_s2 <= 1'b0;
        end else begin
            step_s1 <= cpu_step;
            step_s2 <= step_s1;
        end
    end
    
//wire step_edge = cpu_step & ~step_q;
    
     wire step_pulse = step_s1 & ~step_s2; // rising edge of cpu_step
    
    always @(posedge clk or posedge rst) begin
        if (rst)
            currentPC <= 32'h0000_0000;
        else if (cpu_halt) begin
            if (step_pulse) currentPC <= nextPC;
        end else begin
            currentPC <= nextPC;
        end
    end
endmodule
