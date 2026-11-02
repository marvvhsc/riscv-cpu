`timescale 1ns / 1ps

module alu(
    input [31:0] a,
    input [31:0] b,
    input [3:0] alu_ctrl,
    output reg [31:0] result,
    output zero
    );
    
    assign zero = (result == 32'b0);
        
    always @(*) begin
        case(alu_ctrl)
            4'b0000: result = a & b;                            // AND, ANDI
            4'b0001: result = a << b[4:0];                      // SLL, SLLI
            4'b0010: result = $signed(a) >>> b[4:0];            // SRA, SRAI
            4'b0011: result = a >> b[4:0];                      // SRL, SRLI
            4'b0100: result = a + b;                            // ADD, ADDI, LOAD, STORE, AUIPC, JALR target
            4'b0101: result = a - b;                            // SUB, Branch compare
            4'b0110: result = b;                                // LUI (pass immediate through)
            4'b0111: result = ($signed(a) < $signed(b)) ? 1 : 0; // SLT, SLTI
            4'b1000: result = (a < b) ? 1 : 0;                   // SLTU, SLTIU
            4'b1001: result = a ^ b;                            // XOR, XORI
            4'b1010: result = a | b;                            // OR, ORI
            4'b1011: result = {a[15:0], b[15:0]};
            4'b1100: result = ($signed(a) > $signed(b)) ? a : b; // MAX
            default: result = 32'b0;
        endcase
    end
endmodule
