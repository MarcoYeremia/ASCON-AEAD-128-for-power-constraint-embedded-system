create_clock [get_ports $::env(CLOCK_PORT)] -name $::env(CLOCK_PORT) -period $::env(CLOCK_PERIOD)

set input_delay_value [expr $::env(CLOCK_PERIOD) * 0.2]
set output_delay_value [expr $::env(CLOCK_PERIOD) * 0.2]

set clk_indx [lsearch [all_inputs] [get_ports $::env(CLOCK_PORT)]]
set all_inputs_wo_clk [lreplace [all_inputs] $clk_indx $clk_indx]

set_input_delay $input_delay_value -clock [get_clocks $::env(CLOCK_PORT)] $all_inputs_wo_clk
set_output_delay $output_delay_value -clock [get_clocks $::env(CLOCK_PORT)] [all_outputs]

set_driving_cell -lib_cell gf180mcu_fd_sc_mcu7t5v0__inv_2 -pin ZN $all_inputs_wo_clk
set_load 0.05 [all_outputs]
set_clock_uncertainty 0.25 [get_clocks $::env(CLOCK_PORT)]