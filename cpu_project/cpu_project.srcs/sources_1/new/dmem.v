`timescale 1ns / 1ps

module dmem(
    input clk, 
    input MemWrite,
    input [31:0] addr,
    input [31:0] write_data,
    output [31:0] read_data,
    
    // Debug: Data memory read/write
    input  dmem_dbg_en,
    input  dmem_wr_en,
    input  [31:0] dmem_dbg_addr,
    input  [31:0] dmem_wr_data,
    output [31:0] dmem_rd_data
    );
    
    (* ram_style = "block" *) reg [31:0] mem [0:4095]; 
    
    wire [13:0] final_addr = dmem_dbg_en ? dmem_dbg_addr[15:2] : addr[15:2];
    wire [31:0] final_din = dmem_dbg_en ? dmem_wr_data : write_data;
    wire final_we = dmem_dbg_en ? dmem_wr_en : MemWrite;
    
    reg [31:0] dout;
    assign read_data = dout;
    assign dmem_rd_data = dout;
    
    always @(negedge clk) begin
        if (final_we)
        begin
            mem[final_addr] <= final_din;
            dout <= final_din;
            end
            else begin
           
        dout <= mem[final_addr];
    end
    end
    integer i;
    initial begin
        for (i = 0; i < 4096; i = i+1) begin
            mem[i] = 32'b0;
        end
    end
endmodule