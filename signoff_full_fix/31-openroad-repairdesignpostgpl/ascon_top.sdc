###############################################################################
# Created by write_sdc
###############################################################################
current_design ascon_top
###############################################################################
# Timing Constraints
###############################################################################
create_clock -name clk -period 20.0000 [get_ports {clk}]
set_clock_transition 0.1500 [get_clocks {clk}]
set_clock_uncertainty 0.2500 clk
set_input_delay 4.0000 -clock [get_clocks {clk}] -add_delay [get_ports {cs_n}]
set_input_delay 4.0000 -clock [get_clocks {clk}] -add_delay [get_ports {mosi}]
set_input_delay 4.0000 -clock [get_clocks {clk}] -add_delay [get_ports {rst}]
set_input_delay 4.0000 -clock [get_clocks {clk}] -add_delay [get_ports {sclk}]
set_output_delay 4.0000 -clock [get_clocks {clk}] -add_delay [get_ports {miso}]
###############################################################################
# Environment
###############################################################################
set_load -pin_load 0.0729 [get_ports {miso}]
set_driving_cell -lib_cell gf180mcu_fd_sc_mcu7t5v0__inv_4 -pin {ZN} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {clk}]
set_driving_cell -lib_cell gf180mcu_fd_sc_mcu7t5v0__inv_1 -pin {ZN} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {cs_n}]
set_driving_cell -lib_cell gf180mcu_fd_sc_mcu7t5v0__inv_1 -pin {ZN} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {mosi}]
set_driving_cell -lib_cell gf180mcu_fd_sc_mcu7t5v0__inv_1 -pin {ZN} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {rst}]
set_driving_cell -lib_cell gf180mcu_fd_sc_mcu7t5v0__inv_1 -pin {ZN} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {sclk}]
###############################################################################
# Design Rules
###############################################################################
set_max_transition 3.0000 [current_design]
set_max_capacitance 0.2000 [current_design]
set_max_fanout 10.0000 [current_design]
