`timescale 1ns / 1ps

module ifetch(
    input cpu_clk,
    input clk_100,
    input rst,
    input [31:0] next_pc,  // from PC: where to jump
    output [31:0] instruction, // output to the rest of the CPU
    
    // Debug: instruction memory read/write
    input  inst_dbg_en,  // 1 = Use debug address (read or write)
    input  inst_wr_en,   // 1 = Write enable (only valid when inst_dbg_en = 1)
    input  [31:0] inst_dbg_addr,    // Byte address
    input  [31:0] inst_wr_data,     // Data to write    
    output [31:0] inst_rd_data      // Data to read
    );
    
    // During reset, pre-fetch address 0 so the first post-reset instruction is mem[0].
    // Otherwise pre-fetch next_pc so cpu_inst = mem[pc_out] when PC updates.
    wire [31:0] fetch_addr = rst ? 32'b0 : next_pc;

    wire [31:0] uart_inst_out;
    
    imem urom (
        .cpu_clk(cpu_clk),
        // CPU fetch
        .cpu_addr(fetch_addr),
        .cpu_inst(instruction),
        .clk_100(clk_100),
        // UART debug
        .uart_WriteEnable(inst_dbg_en & inst_wr_en), // only write if in debug mode
        .uart_addr(inst_dbg_addr),
        .uart_data(inst_wr_data),
        .uart_inst(uart_inst_out)
    );
    
    assign inst_rd_data = uart_inst_out;
    
endmodule
