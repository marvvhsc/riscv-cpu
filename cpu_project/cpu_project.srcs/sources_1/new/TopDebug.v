`timescale 1ns / 1ps
module TopDebug(
    input  clk,
    input  rst_n,
    input  mode_sel,
    input  uart_rxd,
    output uart_txd
);
    wire cpu_clk;

    // UART interface wires
    wire [7:0]  rx_data;
    wire        rx_valid;
    wire [7:0]  tx_data;
    wire        tx_start;
    wire        tx_busy;
    // Debug-controller output wires
    wire        cpu_halt;
    wire        cpu_step;
    wire        cpu_reset;

    wire [4:0]  dbg_reg_addr;
    wire [31:0] dbg_reg_data_sc, dbg_reg_data_pl;

    wire        inst_dbg_en, inst_wr_en;
    wire [31:0] inst_dbg_addr, inst_wr_data;
    wire [31:0] inst_rd_data_sc, inst_rd_data_pl;
    wire [31:0] dbg_inst_data_sc, dbg_inst_data_pl;

    wire        dmem_dbg_en, dmem_wr_en;
    wire [31:0] dmem_dbg_addr, dmem_wr_data;
    wire [31:0] dmem_rd_data_sc, dmem_rd_data_pl;

    wire [31:0] dbg_pc_sc, dbg_pc_pl;

    // Mux read-back signals to DebugController based on mode_sel
    wire [31:0] dbg_reg_data = mode_sel ? dbg_reg_data_pl  : dbg_reg_data_sc;
    wire [31:0] inst_rd_data = mode_sel ? dbg_inst_data_pl : dbg_inst_data_sc;
    wire [31:0] dmem_rd_data = mode_sel ? dmem_rd_data_pl  : dmem_rd_data_sc;
    wire [31:0] dbg_pc       = mode_sel ? dbg_pc_pl        : dbg_pc_sc;

    // Clock divider 
    clk_div #(.period(10)) u_clk_div (
        .clk    (clk),
        .rst_n  (rst_n),
        .clk_out(cpu_clk)
    );

    // UART RX / TX
    UartRx #(.CLK_FREQ(100_000_000), .BAUD(115200)) u_UartRx (
        .clk     (clk),
        .rst_n   (rst_n),
        .rx_pin  (uart_rxd),
        .rx_data (rx_data),
        .rx_valid(rx_valid)
    );

    UartTx #(.CLK_FREQ(100_000_000), .BAUD(115200)) u_UartTx (
        .clk     (clk),
        .rst_n   (rst_n),
        .tx_data (tx_data),
        .tx_start(tx_start),
        .tx_busy (tx_busy),
        .tx_pin  (uart_txd)
    );

    // Debug Controller
    DebugController u_DebugCtrl (
        .clk          (clk),
        .rst_n        (rst_n),
        .rx_data      (rx_data),
        .rx_valid     (rx_valid),
        .tx_data      (tx_data),
        .tx_start     (tx_start),
        .tx_busy      (tx_busy),
        .cpu_halt     (cpu_halt),
        .cpu_step     (cpu_step),
        .cpu_reset    (cpu_reset),
        .dbg_reg_addr (dbg_reg_addr),
        .dbg_reg_data (dbg_reg_data),
        .inst_dbg_en  (inst_dbg_en),
        .inst_wr_en   (inst_wr_en),
        .inst_dbg_addr(inst_dbg_addr),
        .inst_wr_data (inst_wr_data),
        .inst_rd_data (inst_rd_data),
        .dmem_dbg_en  (dmem_dbg_en),
        .dmem_wr_en   (dmem_wr_en),
        .dmem_dbg_addr(dmem_dbg_addr),
        .dmem_wr_data (dmem_wr_data),
        .dmem_rd_data (dmem_rd_data),
        .dbg_pc       (dbg_pc)
    );

    // Clock domain crossing + reset stretcher (8 cpu_clk cycles)
    reg cpu_clk_q;
    always @(posedge clk) cpu_clk_q <= cpu_clk;
    wire cpu_tick = cpu_clk && ~cpu_clk_q;

    wire final_rst_request = (~rst_n) | cpu_reset;
    reg [4:0] rst_cnt;
    reg rst_sync;
    always @(posedge clk or posedge final_rst_request) begin
        if (final_rst_request) begin
            rst_sync <= 1'b1;
            rst_cnt  <= 5'd20;
        end else if (cpu_tick) begin
            if (rst_cnt > 0)
                rst_cnt <= rst_cnt - 1;
            else
                rst_sync <= 1'b0;
        end
    end

    reg step_sync;
    always @(posedge clk) begin
        if (cpu_step)      step_sync <= 1'b1;
        else if (cpu_tick) step_sync <= 1'b0;
    end

    // Single-cycle CPU
    cpu u_cpu_sc (
        .clk          (cpu_clk),
        .clk_100      (clk),
        .rst          (rst_sync),
        .cpu_halt     (cpu_halt),
        .cpu_step     (step_sync),
        .dbg_reg_addr (dbg_reg_addr),
        .dbg_reg_data (dbg_reg_data_sc),
        .dbg_pc       (dbg_pc_sc),
        .inst_dbg_en  (inst_dbg_en),
        .inst_wr_en   (inst_wr_en  & ~mode_sel),
        .inst_dbg_addr(inst_dbg_addr),
        .inst_wr_data (inst_wr_data),
        .inst_rd_data (dbg_inst_data_sc),
        .dmem_dbg_en  (dmem_dbg_en),
        .dmem_wr_en   (dmem_wr_en  & ~mode_sel),
        .dmem_dbg_addr(dmem_dbg_addr),
        .dmem_wr_data (dmem_wr_data),
        .dmem_rd_data (dmem_rd_data_sc)
    );

    // Pipeline CPU
    cpu_pipeline u_cpu_pl (
        .clk          (cpu_clk),
        .clk_100      (clk),
        .rst          (rst_sync),
        .cpu_halt     (cpu_halt),
        .cpu_step     (step_sync),
        .dbg_reg_addr (dbg_reg_addr),
        .dbg_reg_data (dbg_reg_data_pl),
        .dbg_pc       (dbg_pc_pl),
        .inst_dbg_en  (inst_dbg_en),
        .inst_wr_en   (inst_wr_en  & mode_sel),
        .inst_dbg_addr(inst_dbg_addr),
        .inst_wr_data (inst_wr_data),
        .inst_rd_data (dbg_inst_data_pl),
        .dmem_dbg_en  (dmem_dbg_en),
        .dmem_wr_en   (dmem_wr_en  & mode_sel),
        .dmem_dbg_addr(dmem_dbg_addr),
        .dmem_wr_data (dmem_wr_data),
        .dmem_rd_data (dmem_rd_data_pl)
    );

endmodule