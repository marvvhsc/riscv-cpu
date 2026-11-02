`timescale 1ns / 1ps
module controller(
    input  [31:0] inst,
    output [4:0]  rs1,
    output [4:0]  rs2,
    output [4:0]  rd,
    output reg [3:0] alu_ctrl,
    // alu_ctrl codes (based on funct3 and funct7):
    //   4'b0000 = AND
    //   4'b0001 = SLL
    //   4'b0010 = SRA
    //   4'b0011 = SRL
    //   4'b0100 = ADD
    //   4'b0101 = SUB
    //   4'b0110 = LUI (pass immediate through)
    //   4'b0111 = SLT
    //   4'b1000 = SLTU
    //   4'b1001 = XOR
    //   4'b1010 = OR
    //   4'b1111 = NOP/unused
    // ALU source (same as your original)
    output reg ALUSrc,       // 0 = use rs2,  1 = use immediate
    output reg RegWrite,     // 1 = write result to rd
    output reg MemRead,      // 1 = read from data memory (LW)
    output reg MemWrite,     // 1 = write to data memory (SW)
    output reg MemToReg,     // 1 = writeback from memory, 0 = from ALU
    output reg Branch,       // 1 = this is a branch instruction
    output reg Jal,          // 1 = JAL instruction
    output reg Jalr,         // 1 = JALR instruction
    output reg Auipc,        // 1 = AUIPC instruction
    output reg [2:0] BranchType, // 000=BEQ, 001=BNE, 100=BLT
    output reg Ecall
);
    assign rs1 = inst[19:15];
    assign rs2 = inst[24:20];
    assign rd = inst[11:7];
    wire [6:0] opcode = inst[6:0];
    wire [2:0] f3 = inst[14:12];
    wire [6:0] f7 = inst[31:25];
    
    always @(*) begin
    
        //default
        RegWrite = 0;
        ALUSrc = 0;
        MemRead = 0;
        MemWrite = 0;
        MemToReg = 0;
        Branch = 0;
        Jal = 0;
        Jalr = 0;
        Auipc = 0;
        Ecall = 0;
        BranchType = 3'b000;
        alu_ctrl = 4'b1111; // NOP
        
        case(opcode)
        
            // R TYPE
            7'b0110011: begin
                RegWrite = 1;
                ALUSrc = 0; // use rs2
                alu_ctrl = 4'b0100; // ADD fallback
                case ({f7, f3})
                     10'b00000100100: alu_ctrl = 4'b1011; // PACK
                     10'b00000011110: alu_ctrl = 4'b1100; // MAX
                     default: begin
                        case (f3)
                            3'b000: alu_ctrl = f7[5] ? 4'b0101 : 4'b0100; // SUB / ADD
                            3'b001: alu_ctrl = 4'b0001; // SLL
                            3'b010: alu_ctrl = 4'b0111; // SLT
                            3'b011: alu_ctrl = 4'b1000; // SLTU
                            3'b100: alu_ctrl = 4'b1001; // XOR
                            3'b101: alu_ctrl = f7[5] ? 4'b0010 : 4'b0011; // SRA / SRL
                            3'b110: alu_ctrl = 4'b1010; // OR
                            3'b111: alu_ctrl = 4'b0000; // AND
                            default: alu_ctrl = 4'b0100;
                        endcase
                     end
                endcase
            end
            
            // I TYPE (ALU)
            7'b0010011: begin
                RegWrite = 1;
                ALUSrc = 1; // use immediate
                case(f3)
                    3'b000: alu_ctrl = 4'b0100; // ADDI
                    3'b001: alu_ctrl = 4'b0001; // SLLI
                    3'b010: alu_ctrl = 4'b0111; // SLTI
                    3'b011: alu_ctrl = 4'b1000; // SLTIU
                    3'b100: alu_ctrl = 4'b1001; // XORI
                    3'b101: alu_ctrl = f7[5] ? 4'b0010 : 4'b0011; // SRAI / SRLI
                    3'b110: alu_ctrl = 4'b1010; // ORI
                    3'b111: alu_ctrl = 4'b0000; // ANDI
                endcase
            end
            
            // LUI
            7'b0110111: begin
                RegWrite = 1;
                ALUSrc = 1;
                alu_ctrl = 4'b0110; // pass immediate through
            end
            
            // AUIPC
            7'b0010111: begin
                RegWrite = 1;
                ALUSrc   = 1;
                Auipc    = 1;
                alu_ctrl = 4'b0100; // ADD (PC + imm)
            end
            
            // JAL
            7'b1101111: begin
                RegWrite = 1;
                Jal      = 1;
                alu_ctrl = 4'b1111;
            end
            
            // JALR
            7'b1100111: begin
                RegWrite = 1;
                ALUSrc   = 1;
                Jalr     = 1;
                alu_ctrl = 4'b0100; // use ALU for ADD (rs1 + imm) for jump target
            end
            
            // LOAD
            7'b0000011: begin
                RegWrite = 1;
                ALUSrc = 1;   // base + offset
                MemRead  = 1;
                MemToReg = 1;   // writeback from memory not ALU
                alu_ctrl = 4'b0100; // ADD (base + offset)
            end
            
            // STORE
            7'b0100011: begin
                RegWrite  = 0;
                ALUSrc = 1;   // base + offset
                MemWrite = 1;
                alu_ctrl = 4'b0100; // ADD (base + offset)
            end
            
            // BRANCH
            7'b1100011: begin
                RegWrite = 0;
                ALUSrc = 0;   // compare rs1 vs rs2
                Branch = 1;
                BranchType = f3;  // 000=BEQ, 001=BNE, 100=BLT
//                alu_ctrl = 4'b0101; // SUB (to compare)
                case(f3)
                    3'b000, 3'b001: alu_ctrl = 4'b0101; // BEQ/BNE use SUB
                    3'b100, 3'b101: alu_ctrl = 4'b0111; // BLT/BGE use SLT
                    3'b110, 3'b111: alu_ctrl = 4'b1000; // BLTU/BGEU use SLTU
                endcase
            end
            7'b1110011: begin Ecall=1; end  
        endcase
    end
endmodule