`timescale 1ns / 1ps

module imem(
    input cpu_clk,
    input [31:0] cpu_addr,
    output reg [31:0] cpu_inst,
    input clk_100,
    input uart_WriteEnable, // write enable from UART
    input inst_dbg_en, // 
    input [31:0] uart_addr, // address from UART
    input [31:0] uart_data, // instruction data from UART
    output reg [31:0] uart_inst // read data back to UART
    );
    
    (* ram_style = "block" *) reg [31:0] mem [0:4095]; // 4K instructions
    
    initial begin
        $readmemh("batch_test.txt", mem);
    end
    
    // Address mux: debug mode reads/writes via uart_addr, else normal fetch
    
    // Read: cpu_clk domain
    always @(posedge cpu_clk) begin
        cpu_inst <= mem[cpu_addr[13:2]];
    end

    // Write + debug read: 100 MHz domain
    always @(posedge clk_100) begin
        if (uart_WriteEnable)
            mem[uart_addr[13:2]] <= uart_data;
        uart_inst <= mem[uart_addr[13:2]];
    end
endmodule
