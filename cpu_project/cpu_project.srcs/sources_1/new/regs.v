`timescale 1ns / 1ps

module regs(
    input clk, 
    input rst,
    input [4:0] rs1, // read register 1 
    input [4:0] rs2, // read register 2 
    input [4:0] rd, // write register
    input [31:0] rd_data, // write data
    input RegWrite,
    output [31:0] rs1_data, // read data 1
    output [31:0] rs2_data, // read data 2
    
    // Debug: register read
    input  [4:0]  dbg_reg_addr,
    output [31:0] dbg_reg_data
    );
    
    reg [31:0] registers[31:1]; // x1 to x31 only since x0 is hardwired for zero
    
    integer i;
    initial begin
        for (i = 1; i < 32; i = i+1) begin
            registers[i] = 32'b0;
        end
    end
    
    assign rs1_data = (rs1 == 5'b0) ? 32'b0 : registers[rs1];
    assign rs2_data = (rs2 == 5'b0) ? 32'b0 : registers[rs2];
    
    // Debug: register read
    assign dbg_reg_data = (dbg_reg_addr == 5'd0) ? 32'b0 : registers[dbg_reg_addr];
    
    // write logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 1; i < 32; i = i+1) begin
                registers[i] <= 32'b0;
            end
            registers[3] <= 32'h00004000;
        end else
        if (RegWrite && rd != 5'b0) begin
            registers[rd] <= rd_data;
        end
    end
endmodule
