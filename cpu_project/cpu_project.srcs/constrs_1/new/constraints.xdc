# clock signal (100 MHz)
set_property IOSTANDARD LVCMOS33 [get_ports clk]
set_property PACKAGE_PIN P17 [get_ports clk]
create_clock -period 10.000 -name clk [get_ports clk]

# reset button
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]
set_property PACKAGE_PIN P15 [get_ports rst_n]

# uart rx and tx
set_property IOSTANDARD LVCMOS33 [get_ports uart_rxd]
set_property PACKAGE_PIN N5 [get_ports uart_rxd]
set_property IOSTANDARD LVCMOS33 [get_ports uart_txd]
set_property PACKAGE_PIN T4 [get_ports uart_txd]

set_property IOSTANDARD LVCMOS33 [get_ports mode_sel]
set_property PACKAGE_PIN R1 [get_ports mode_sel]