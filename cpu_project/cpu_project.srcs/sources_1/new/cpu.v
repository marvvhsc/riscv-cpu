`timescale 1ns / 1ps

module cpu(
    input clk,
    input clk_100,
    input rst,

    // Debug Interface (Mandatory for Difftest/Random Test)
    input cpu_halt,
    input cpu_step,
    input [4:0]  dbg_reg_addr,
    output [31:0] dbg_reg_data,
    output [31:0] dbg_pc,
    
    // Instruction Memory Debug
    input inst_dbg_en,
    input inst_wr_en,
    input [31:0] inst_dbg_addr,
    input [31:0] inst_wr_data,
    output [31:0] inst_rd_data,
    
    // Data Memory Debug
    input dmem_dbg_en,
    input dmem_wr_en,
    input [31:0] dmem_dbg_addr,
    input [31:0] dmem_wr_data,
    output [31:0] dmem_rd_data
    );

    wire [31:0] pc_out, next_pc, instruction;
    wire [31:0] rs1_data, rs2_data, alu_result, dmem_data, write_back_data;
    wire [31:0] imm;
    wire [31:0] alu_input_b;
    wire [3:0]  alu_ctrl;
    wire [2:0]  branch_type;
    wire        reg_write, alu_src, mem_read, mem_write, mem_to_reg, branch, jal, jalr, auipc, alu_zero;
    wire ecall;

    assign dbg_pc = pc_out;

    // funct3 for load size selection
    wire [2:0] funct3 = instruction[14:12];

    // BRANCH DECISION
    reg take_branch;
always @(*) begin
        case(branch_type)
            3'b000: take_branch = alu_zero;        // BEQ
            3'b001: take_branch = !alu_zero;       // BNE
            3'b100: take_branch = alu_result[0];   // BLT -SLT result
            3'b101: take_branch = !alu_result[0];  // BGE
            3'b110: take_branch = alu_result[0];   // BLTU - SLTU result
            3'b111: take_branch = !alu_result[0];  // BGEU
            default: take_branch = 1'b0;
        endcase
    end
    
    // COMPUTATION OF NEXT PC
    wire [31:0] branch_target = pc_out + imm;
    wire [31:0] jalr_target   = (rs1_data + imm) & ~32'h1;
    
    assign next_pc = jal  ? (pc_out + imm) :
                     jalr ? jalr_target     :
                     (branch & take_branch) ? branch_target :
                     (pc_out + 32'd4);
    
   // nih i cb gnti
   wire [31:0] wb_data_safe;
    assign wb_data_safe = reg_write ? write_back_data : 32'b0;
    
    pc u_pc (
        .clk(clk), 
        .rst(rst), 
        .cpu_halt(cpu_halt), 
        .cpu_step(cpu_step), 
        .nextPC(next_pc), 
        .currentPC(pc_out)
    );
    
    ifetch u_ifetch (
        .cpu_clk(clk),
        .clk_100(clk_100),
        .rst(rst), 
        .next_pc(next_pc), 
        .instruction(instruction), 
        .inst_dbg_en(inst_dbg_en), 
        .inst_wr_en(inst_wr_en),
        .inst_dbg_addr(inst_dbg_addr), 
        .inst_wr_data(inst_wr_data),
        .inst_rd_data(inst_rd_data)
    );

    controller u_ctrl (
        .inst(instruction), 
        .rs1(), 
        .rs2(), 
        .rd(), 
        .alu_ctrl(alu_ctrl), 
        .ALUSrc(alu_src), 
        .RegWrite(reg_write), 
        .MemRead(mem_read), 
        .MemWrite(mem_write), 
        .MemToReg(mem_to_reg), 
        .Branch(branch), 
        .BranchType(branch_type),
        .Ecall(ecall), 
        .Jal(jal), 
        .Jalr(jalr), 
        .Auipc(auipc)
    );

    imm_gen u_immgen (
        .inst(instruction),
        .imm(imm)
    );

    regs u_regs (
        .clk(clk), 
        .rst(rst),
        .rs1(instruction[19:15]), 
        .rs2(instruction[24:20]), 
        .rd(instruction[11:7]),
        // nih
        // .rd_data(write_back_data), 
        .rd_data(wb_data_safe),
        // .RegWrite(reg_write & ~rst),
        .RegWrite(reg_write),
        .rs1_data(rs1_data), 
        .rs2_data(rs2_data),
        .dbg_reg_addr(dbg_reg_addr), 
        .dbg_reg_data(dbg_reg_data)
    );

    // ALU inputs
    assign alu_input_b = alu_src ? imm : rs2_data;
    wire [31:0] alu_input_a = auipc ? pc_out : rs1_data;

    alu u_alu (
        .a(alu_input_a), 
        .b(alu_input_b), 
        .alu_ctrl(alu_ctrl),
        .result(alu_result), 
        .zero(alu_zero)
    );

    dmem u_dmem (
        .clk(clk), 
        .MemWrite(mem_write), 
        .addr(alu_result),
        .write_data(rs2_data), 
        .read_data(dmem_data),
        .dmem_dbg_en(dmem_dbg_en), 
        .dmem_wr_en(dmem_wr_en),
        .dmem_dbg_addr(dmem_dbg_addr), 
        .dmem_wr_data(dmem_wr_data),
        .dmem_rd_data(dmem_rd_data)
    );

    // Load data extraction based on funct3
    // LB=000, LH=001, LW=010, LBU=100, LHU=101
    wire [31:0] load_data;
    assign load_data =
        (funct3 == 3'b000) ? {{24{dmem_data[7]}},  dmem_data[7:0]}  : // LB  sign-extend
        (funct3 == 3'b001) ? {{16{dmem_data[15]}}, dmem_data[15:0]} : // LH  sign-extend
        (funct3 == 3'b100) ? {24'b0, dmem_data[7:0]}                : // LBU zero-extend
        (funct3 == 3'b101) ? {16'b0, dmem_data[15:0]}               : // LHU zero-extend
                              dmem_data;                               // LW  full word

    // Write-back MUX
    wire [31:0] pc_plus_4 = pc_out + 32'd4;
    assign write_back_data = (jal | jalr) ? pc_plus_4 :
                              mem_to_reg  ? load_data  :
                                            alu_result;

endmodule