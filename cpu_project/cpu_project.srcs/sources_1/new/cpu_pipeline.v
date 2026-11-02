`timescale 1ns / 1ps
 module cpu_pipeline (
    input  clk,
    input  clk_100,
    input  rst,

    // Debug Interface
    input        cpu_halt,
    input        cpu_step,
    input  [4:0]  dbg_reg_addr,
    output [31:0] dbg_reg_data,
    output [31:0] dbg_pc,

    // Instruction Memory Debug
    input        inst_dbg_en,
    input        inst_wr_en,
    input  [31:0] inst_dbg_addr,
    input  [31:0] inst_wr_data,
    output [31:0] inst_rd_data,

    // Data Memory Debug
    input        dmem_dbg_en,
    input        dmem_wr_en,
    input  [31:0] dmem_dbg_addr,
    input  [31:0] dmem_wr_data,
    output [31:0] dmem_rd_data
);

//CLOCk ENABLE
localparam NOP_INST = 32'h0000_0013;
reg step_s1, step_s2;
always @(posedge clk or posedge rst) begin
    if (rst) begin step_s1 <= 0; step_s2 <= 0; end
    else     begin step_s1 <= cpu_step; step_s2 <= step_s1; end
end
wire step_pulse = step_s1 & ~step_s2;
wire pipe_en    = cpu_halt ? step_pulse : 1'b1;

//IF STAGE
reg  [31:0] IF_pc;
wire [31:0] pc_next;
wire stall;
wire flush_IF_ID;
wire flush_ID_EX;

always @(posedge clk or posedge rst) begin
    if (rst)
        IF_pc <= 32'h0000_0000;
    else if (pipe_en && !stall)
        IF_pc <= pc_next;
end

assign dbg_pc = IF_pc;

wire [31:0] IF_instruction;

ifetch u_ifetch (
    .cpu_clk      (clk),
    .clk_100      (clk_100),
    .rst          (rst),
    .next_pc      (pc_next),
    .instruction  (IF_instruction),
    .inst_dbg_en  (inst_dbg_en),
    .inst_wr_en   (inst_wr_en),
    .inst_dbg_addr(inst_dbg_addr),
    .inst_wr_data (inst_wr_data),
    .inst_rd_data (inst_rd_data)
);

//IF/ID PIPELINE REGISTER
reg [31:0] IF_ID_pc;
reg [31:0] IF_ID_inst;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        IF_ID_pc   <= 32'b0;
        IF_ID_inst <= NOP_INST;
    end else if (pipe_en) begin
        if (flush_IF_ID) begin
            IF_ID_pc   <= 32'b0;
            IF_ID_inst <= NOP_INST;
        end else if (!stall) begin
            IF_ID_pc   <= IF_pc;
            IF_ID_inst <= IF_instruction;
        end
    end
end

//ID STAGE
wire [4:0]  ID_rs1_addr = IF_ID_inst[19:15];
wire [4:0]  ID_rs2_addr = IF_ID_inst[24:20];
wire [4:0]  ID_rd_addr  = IF_ID_inst[11:7];
wire [2:0]  ID_funct3   = IF_ID_inst[14:12];

wire [3:0]  ID_alu_ctrl;
wire        ID_alu_src, ID_reg_write, ID_mem_read, ID_mem_write;
wire        ID_mem_to_reg, ID_branch, ID_jal, ID_jalr, ID_auipc;
wire [2:0]  ID_branch_type;

controller u_ctrl (
    .inst      (IF_ID_inst),
    .rs1       (),
    .rs2       (),
    .rd        (),
    .alu_ctrl  (ID_alu_ctrl),
    .ALUSrc    (ID_alu_src),
    .RegWrite  (ID_reg_write),
    .MemRead   (ID_mem_read),
    .MemWrite  (ID_mem_write),
    .MemToReg  (ID_mem_to_reg),
    .Branch    (ID_branch),
    .Jal       (ID_jal),
    .Jalr      (ID_jalr),
    .Auipc     (ID_auipc),
    .BranchType(ID_branch_type)
);

wire [31:0] ID_imm;
imm_gen u_immgen (
    .inst(IF_ID_inst),
    .imm (ID_imm)
);

wire        WB_reg_write;
wire [4:0]  WB_rd_addr;
wire [31:0] WB_write_data;

wire [31:0] ID_rs1_data, ID_rs2_data;

regs u_regs (
    .clk         (clk),
    .rst         (rst),
    .rs1         (ID_rs1_addr),
    .rs2         (ID_rs2_addr),
    .rd          (WB_rd_addr),
    .rd_data     (WB_write_data),
    .RegWrite    (WB_reg_write & ~rst),
    .rs1_data    (ID_rs1_data),
    .rs2_data    (ID_rs2_data),
    .dbg_reg_addr(dbg_reg_addr),
    .dbg_reg_data(dbg_reg_data)
);

// WB->ID bypass
wire [31:0] ID_rs1_data_bypassed =
    (WB_reg_write && WB_rd_addr != 5'b0 && WB_rd_addr == ID_rs1_addr)
    ? WB_write_data : ID_rs1_data;

wire [31:0] ID_rs2_data_bypassed =
    (WB_reg_write && WB_rd_addr != 5'b0 && WB_rd_addr == ID_rs2_addr)
    ? WB_write_data : ID_rs2_data;

//HAZARD DETECTION
wire        EX_mem_read;
wire [4:0]  EX_rd_addr;

assign stall = (EX_mem_read && (EX_rd_addr != 5'b0) &&
               ((EX_rd_addr == ID_rs1_addr) || (EX_rd_addr == ID_rs2_addr)));

//ID/EX PIPELINE REGISTER
reg [31:0] ID_EX_pc;
reg [31:0] ID_EX_rs1_data, ID_EX_rs2_data;
reg [31:0] ID_EX_imm;
reg [4:0]  ID_EX_rs1_addr, ID_EX_rs2_addr, ID_EX_rd_addr;
reg [3:0]  ID_EX_alu_ctrl;
reg [2:0]  ID_EX_funct3;
reg        ID_EX_alu_src;
reg        ID_EX_reg_write, ID_EX_mem_read, ID_EX_mem_write, ID_EX_mem_to_reg;
reg        ID_EX_branch, ID_EX_jal, ID_EX_jalr, ID_EX_auipc;
reg [2:0]  ID_EX_branch_type;

assign EX_mem_read = ID_EX_mem_read;
assign EX_rd_addr  = ID_EX_rd_addr;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        ID_EX_pc          <= 32'b0;
        ID_EX_rs1_data    <= 32'b0;
        ID_EX_rs2_data    <= 32'b0;
        ID_EX_imm         <= 32'b0;
        ID_EX_rs1_addr    <= 5'b0;
        ID_EX_rs2_addr    <= 5'b0;
        ID_EX_rd_addr     <= 5'b0;
        ID_EX_alu_ctrl    <= 4'b1111;
        ID_EX_funct3      <= 3'b0;
        ID_EX_alu_src     <= 1'b0;
        ID_EX_reg_write   <= 1'b0;
        ID_EX_mem_read    <= 1'b0;
        ID_EX_mem_write   <= 1'b0;
        ID_EX_mem_to_reg  <= 1'b0;
        ID_EX_branch      <= 1'b0;
        ID_EX_jal         <= 1'b0;
        ID_EX_jalr        <= 1'b0;
        ID_EX_auipc       <= 1'b0;
        ID_EX_branch_type <= 3'b0;
    end else if (pipe_en) begin
        if (stall || flush_ID_EX) begin
            ID_EX_pc          <= 32'b0;
            ID_EX_rs1_data    <= 32'b0;
            ID_EX_rs2_data    <= 32'b0;
            ID_EX_imm         <= 32'b0;
            ID_EX_rs1_addr    <= 5'b0;
            ID_EX_rs2_addr    <= 5'b0;
            ID_EX_rd_addr     <= 5'b0;
            ID_EX_alu_ctrl    <= 4'b1111;
            ID_EX_funct3      <= 3'b0;
            ID_EX_alu_src     <= 1'b0;
            ID_EX_reg_write   <= 1'b0;
            ID_EX_mem_read    <= 1'b0;
            ID_EX_mem_write   <= 1'b0;
            ID_EX_mem_to_reg  <= 1'b0;
            ID_EX_branch      <= 1'b0;
            ID_EX_jal         <= 1'b0;
            ID_EX_jalr        <= 1'b0;
            ID_EX_auipc       <= 1'b0;
            ID_EX_branch_type <= 3'b0;
        end else begin
            ID_EX_pc          <= IF_ID_pc;
            ID_EX_rs1_data    <= ID_rs1_data_bypassed;
            ID_EX_rs2_data    <= ID_rs2_data_bypassed;
            ID_EX_imm         <= ID_imm;
            ID_EX_rs1_addr    <= ID_rs1_addr;
            ID_EX_rs2_addr    <= ID_rs2_addr;
            ID_EX_rd_addr     <= ID_rd_addr;
            ID_EX_alu_ctrl    <= ID_alu_ctrl;
            ID_EX_funct3      <= ID_funct3;
            ID_EX_alu_src     <= ID_alu_src;
            ID_EX_reg_write   <= ID_reg_write;
            ID_EX_mem_read    <= ID_mem_read;
            ID_EX_mem_write   <= ID_mem_write;
            ID_EX_mem_to_reg  <= ID_mem_to_reg;
            ID_EX_branch      <= ID_branch;
            ID_EX_jal         <= ID_jal;
            ID_EX_jalr        <= ID_jalr;
            ID_EX_auipc       <= ID_auipc;
            ID_EX_branch_type <= ID_branch_type;
        end
    end
end

//EX STAGE
wire        MEM_reg_write;
wire [4:0]  MEM_rd_addr;
wire [31:0] MEM_alu_result;
wire        WB_reg_write_fw;
wire [31:0] WB_write_data_fw;

reg [1:0] forward_a, forward_b;
always @(*) begin
    if (MEM_reg_write && (MEM_rd_addr != 5'b0) && (MEM_rd_addr == ID_EX_rs1_addr))
        forward_a = 2'b10;
    else if (WB_reg_write_fw && (WB_rd_addr != 5'b0) && (WB_rd_addr == ID_EX_rs1_addr))
        forward_a = 2'b01;
    else
        forward_a = 2'b00;

    if (MEM_reg_write && (MEM_rd_addr != 5'b0) && (MEM_rd_addr == ID_EX_rs2_addr))
        forward_b = 2'b10;
    else if (WB_reg_write_fw && (WB_rd_addr != 5'b0) && (WB_rd_addr == ID_EX_rs2_addr))
        forward_b = 2'b01;
    else
        forward_b = 2'b00;
end

reg [31:0] EX_fwd_a, EX_fwd_b_raw;
always @(*) begin
    case (forward_a)
        2'b10:   EX_fwd_a = MEM_alu_result;
        2'b01:   EX_fwd_a = WB_write_data_fw;
        default: EX_fwd_a = ID_EX_rs1_data;
    endcase
    case (forward_b)
        2'b10:   EX_fwd_b_raw = MEM_alu_result;
        2'b01:   EX_fwd_b_raw = WB_write_data_fw;
        default: EX_fwd_b_raw = ID_EX_rs2_data;
    endcase
end

wire [31:0] EX_alu_b = ID_EX_alu_src ? ID_EX_imm : EX_fwd_b_raw;
wire [31:0] EX_alu_a = ID_EX_auipc   ? ID_EX_pc  : EX_fwd_a;

wire [31:0] EX_alu_result;
wire        EX_alu_zero;

alu u_alu (
    .a       (EX_alu_a),
    .b       (EX_alu_b),
    .alu_ctrl(ID_EX_alu_ctrl),
    .result  (EX_alu_result),
    .zero    (EX_alu_zero)
);

reg EX_take_branch;
always @(*) begin
    case (ID_EX_branch_type)
        3'b000: EX_take_branch = EX_alu_zero;
        3'b001: EX_take_branch = !EX_alu_zero;
        3'b100: EX_take_branch = EX_alu_result[0];
        3'b101: EX_take_branch = !EX_alu_result[0];
        3'b110: EX_take_branch = EX_alu_result[0];
        3'b111: EX_take_branch = !EX_alu_result[0];
        default: EX_take_branch = 1'b0;
    endcase
end

wire [31:0] EX_branch_target = ID_EX_pc + ID_EX_imm;
wire [31:0] EX_jalr_target   = (EX_fwd_a + ID_EX_imm) & ~32'h1;
wire [31:0] EX_jal_target    = ID_EX_pc + ID_EX_imm;
wire        EX_redirect       = ID_EX_jal | ID_EX_jalr | (ID_EX_branch & EX_take_branch);

assign pc_next =
    ID_EX_jal                       ? EX_jal_target    :
    ID_EX_jalr                      ? EX_jalr_target   :
    (ID_EX_branch & EX_take_branch) ? EX_branch_target :
                                      (IF_pc + 32'd4);

assign flush_IF_ID = pipe_en & EX_redirect;
assign flush_ID_EX = pipe_en & EX_redirect;

wire [31:0] EX_pc_plus4 = ID_EX_pc + 32'd4;

// EX/MEM PIPELINE REGISTER
reg [31:0] EX_MEM_alu_result;
reg [31:0] EX_MEM_rs2_data;
reg [31:0] EX_MEM_pc_plus4;
reg [4:0]  EX_MEM_rd_addr;
reg [2:0]  EX_MEM_funct3;
reg        EX_MEM_reg_write, EX_MEM_mem_read, EX_MEM_mem_write, EX_MEM_mem_to_reg;
reg        EX_MEM_jal, EX_MEM_jalr;

assign MEM_reg_write      = EX_MEM_reg_write;
assign MEM_rd_addr        = EX_MEM_rd_addr;
assign MEM_alu_result     = EX_MEM_alu_result;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        EX_MEM_alu_result  <= 32'b0;
        EX_MEM_rs2_data    <= 32'b0;
        EX_MEM_pc_plus4    <= 32'b0;
        EX_MEM_rd_addr     <= 5'b0;
        EX_MEM_funct3      <= 3'b0;
        EX_MEM_reg_write   <= 1'b0;
        EX_MEM_mem_read    <= 1'b0;
        EX_MEM_mem_write   <= 1'b0;
        EX_MEM_mem_to_reg  <= 1'b0;
        EX_MEM_jal         <= 1'b0;
        EX_MEM_jalr        <= 1'b0;
    end else if (pipe_en) begin
        EX_MEM_alu_result  <= EX_alu_result;
        EX_MEM_rs2_data    <= EX_fwd_b_raw;
        EX_MEM_pc_plus4    <= EX_pc_plus4;
        EX_MEM_rd_addr     <= ID_EX_rd_addr;
        EX_MEM_funct3      <= ID_EX_funct3;
        EX_MEM_reg_write   <= ID_EX_reg_write;
        EX_MEM_mem_read    <= ID_EX_mem_read;
        EX_MEM_mem_write   <= ID_EX_mem_write;
        EX_MEM_mem_to_reg  <= ID_EX_mem_to_reg;
        EX_MEM_jal         <= ID_EX_jal;
        EX_MEM_jalr        <= ID_EX_jalr;
    end
end

// MEM STAGE
wire [31:0] MEM_dmem_read_data;

dmem u_dmem (
    .clk          (clk),
    .MemWrite     (EX_MEM_mem_write),
    .addr         (EX_MEM_alu_result),
    .write_data   (EX_MEM_rs2_data),
    .read_data    (MEM_dmem_read_data),
    .dmem_dbg_en  (dmem_dbg_en),
    .dmem_wr_en   (dmem_wr_en),
    .dmem_dbg_addr(dmem_dbg_addr),
    .dmem_wr_data (dmem_wr_data),
    .dmem_rd_data (dmem_rd_data)
);

//MEM/WB PIPELINE REGISTER
reg [31:0] MEM_WB_alu_result;
reg [31:0] MEM_WB_dmem_data;
reg [31:0] MEM_WB_pc_plus4;
reg [4:0]  MEM_WB_rd_addr;
reg [2:0]  MEM_WB_funct3;
reg        MEM_WB_reg_write, MEM_WB_mem_to_reg;
reg        MEM_WB_jal, MEM_WB_jalr;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        MEM_WB_alu_result  <= 32'b0;
        MEM_WB_dmem_data   <= 32'b0;
        MEM_WB_pc_plus4    <= 32'b0;
        MEM_WB_rd_addr     <= 5'b0;
        MEM_WB_funct3      <= 3'b0;
        MEM_WB_reg_write   <= 1'b0;
        MEM_WB_mem_to_reg  <= 1'b0;
        MEM_WB_jal         <= 1'b0;
        MEM_WB_jalr        <= 1'b0;
    end else if (pipe_en) begin
        MEM_WB_alu_result  <= EX_MEM_alu_result;
        MEM_WB_dmem_data   <= MEM_dmem_read_data;
        MEM_WB_pc_plus4    <= EX_MEM_pc_plus4;
        MEM_WB_rd_addr     <= EX_MEM_rd_addr;
        MEM_WB_funct3      <= EX_MEM_funct3;
        MEM_WB_reg_write   <= EX_MEM_reg_write;
        MEM_WB_mem_to_reg  <= EX_MEM_mem_to_reg;
        MEM_WB_jal         <= EX_MEM_jal;
        MEM_WB_jalr        <= EX_MEM_jalr;
    end
end

// WB STAGE
assign WB_rd_addr      = MEM_WB_rd_addr;
assign WB_reg_write    = MEM_WB_reg_write;
assign WB_reg_write_fw = MEM_WB_reg_write;

wire [31:0] WB_load_data;
assign WB_load_data =
    (MEM_WB_funct3 == 3'b000) ? {{24{MEM_WB_dmem_data[7]}},  MEM_WB_dmem_data[7:0]}  :
    (MEM_WB_funct3 == 3'b001) ? {{16{MEM_WB_dmem_data[15]}}, MEM_WB_dmem_data[15:0]} :
    (MEM_WB_funct3 == 3'b100) ? {24'b0, MEM_WB_dmem_data[7:0]}                        :
    (MEM_WB_funct3 == 3'b101) ? {16'b0, MEM_WB_dmem_data[15:0]}                       :
                                  MEM_WB_dmem_data;

assign WB_write_data =
    (MEM_WB_jal | MEM_WB_jalr) ? MEM_WB_pc_plus4 :
    MEM_WB_mem_to_reg           ? WB_load_data    :
                                  MEM_WB_alu_result;

assign WB_write_data_fw = WB_write_data;

endmodule