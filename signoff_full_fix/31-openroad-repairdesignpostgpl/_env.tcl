set ::env(RSZ_CORNER_0) "nom_tt_025C_5v00 /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/lib/gf180mcu_fd_sc_mcu7t5v0__tt_025C_5v00.lib"
set ::env(RSZ_CORNER_1) "nom_ss_125C_4v50 /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/lib/gf180mcu_fd_sc_mcu7t5v0__ss_125C_4v50.lib"
set ::env(RSZ_CORNER_2) "nom_ff_n40C_5v50 /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/lib/gf180mcu_fd_sc_mcu7t5v0__ff_n40C_5v50.lib"
set ::env(STEP_ID) OpenROAD.RepairDesignPostGPL
set ::env(TECH_LEF) /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/techlef/gf180mcu_fd_sc_mcu7t5v0__nom.tlef
set ::env(MACRO_LEFS) ""
set ::env(STD_CELL_LIBRARY) gf180mcu_fd_sc_mcu7t5v0
set ::env(VDD_PIN) VDD
set ::env(VDD_PIN_VOLTAGE) 5.00
set ::env(GND_PIN) VSS
set ::env(TECH_LEFS) "\"nom_*\" /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/techlef/gf180mcu_fd_sc_mcu7t5v0__nom.tlef \"min_*\" /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/techlef/gf180mcu_fd_sc_mcu7t5v0__min.tlef \"max_*\" /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/techlef/gf180mcu_fd_sc_mcu7t5v0__max.tlef"
set ::env(PRIMARY_GDSII_STREAMOUT_TOOL) magic
set ::env(DEFAULT_CORNER) nom_tt_025C_5v00
set ::env(STA_CORNERS) "nom_tt_025C_5v00 nom_ss_125C_4v50 nom_ff_n40C_5v50 min_tt_025C_5v00 min_ss_125C_4v50 min_ff_n40C_5v50 max_tt_025C_5v00 max_ss_125C_4v50 max_ff_n40C_5v50"
set ::env(FP_TRACKS_INFO) /foss/pdks/gf180mcuD/libs.tech/openlane/gf180mcu_fd_sc_mcu7t5v0/tracks.info
set ::env(FP_TAPCELL_DIST) 20
set ::env(FP_IO_HLAYER) Metal3
set ::env(FP_IO_VLAYER) Metal2
set ::env(RT_MIN_LAYER) Metal2
set ::env(RT_MAX_LAYER) Metal5
set ::env(SCL_GROUND_PINS) "VSS VPW"
set ::env(SCL_POWER_PINS) "VDD VNW"
set ::env(TRISTATE_CELLS) "\"gf180mcu_fd_sc_mcu7t5v0__bufz*\""
set ::env(FILL_CELL) "\"gf180mcu_fd_sc_mcu7t5v0__fill_*\""
set ::env(DECAP_CELL) "\"gf180mcu_fd_sc_mcu7t5v0__fillcap_*\""
set ::env(LIB) "\"*_tt_025C_5v00\" /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/lib/gf180mcu_fd_sc_mcu7t5v0__tt_025C_5v00.lib \"*_ss_125C_4v50\" /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/lib/gf180mcu_fd_sc_mcu7t5v0__ss_125C_4v50.lib \"*_ff_n40C_5v50\" /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/lib/gf180mcu_fd_sc_mcu7t5v0__ff_n40C_5v50.lib"
set ::env(CELL_LEFS) /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/lef/gf180mcu_fd_sc_mcu7t5v0.lef
set ::env(CELL_GDS) /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/gds/gf180mcu_fd_sc_mcu7t5v0.gds
set ::env(CELL_VERILOG_MODELS) "/foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/verilog/gf180mcu_fd_sc_mcu7t5v0.v /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/verilog/primitives.v"
set ::env(CELL_SPICE_MODELS) /foss/pdks/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/spice/gf180mcu_fd_sc_mcu7t5v0.spice
set ::env(SYNTH_EXCLUDED_CELL_FILE) /foss/pdks/gf180mcuD/libs.tech/openlane/gf180mcu_fd_sc_mcu7t5v0/no_synth.cells
set ::env(PNR_EXCLUDED_CELL_FILE) /foss/pdks/gf180mcuD/libs.tech/openlane/gf180mcu_fd_sc_mcu7t5v0/drc_exclude.cells
set ::env(OUTPUT_CAP_LOAD) 72.91
set ::env(MAX_FANOUT_CONSTRAINT) 10
set ::env(MAX_TRANSITION_CONSTRAINT) 3
set ::env(MAX_CAPACITANCE_CONSTRAINT) 0.2
set ::env(CLOCK_UNCERTAINTY_CONSTRAINT) 0.25
set ::env(CLOCK_TRANSITION_CONSTRAINT) 0.1499999999999999944488848768742172978818416595458984375
set ::env(TIME_DERATING_CONSTRAINT) 5
set ::env(IO_DELAY_CONSTRAINT) 20
set ::env(SYNTH_DRIVING_CELL) gf180mcu_fd_sc_mcu7t5v0__inv_1/ZN
set ::env(SYNTH_CLK_DRIVING_CELL) gf180mcu_fd_sc_mcu7t5v0__inv_4/ZN
set ::env(SYNTH_TIEHI_CELL) gf180mcu_fd_sc_mcu7t5v0__tieh/Z
set ::env(SYNTH_TIELO_CELL) gf180mcu_fd_sc_mcu7t5v0__tiel/ZN
set ::env(SYNTH_BUFFER_CELL) gf180mcu_fd_sc_mcu7t5v0__buf_1/I/Z
set ::env(WELLTAP_CELL) gf180mcu_fd_sc_mcu7t5v0__filltie
set ::env(ENDCAP_CELL) gf180mcu_fd_sc_mcu7t5v0__endcap
set ::env(PLACE_SITE) GF018hv5v_mcu_sc7
set ::env(CELL_PAD_EXCLUDE) "gf180mcu_fd_sc_mcu7t5v0__filltie \"gf180mcu_fd_sc_mcu7t5v0__fill_*\" gf180mcu_fd_sc_mcu7t5v0__endcap"
set ::env(DIODE_CELL) gf180mcu_fd_sc_mcu7t5v0__antenna/I
set ::env(DESIGN_NAME) ascon_top
set ::env(CLOCK_PERIOD) 20.0
set ::env(CLOCK_PORT) clk
set ::env(DIE_AREA) "0 0 1000 1000"
set ::env(FALLBACK_SDC_FILE) /usr/local/lib/python3.12/dist-packages/openlane/scripts/base.sdc
set ::env(PDN_CONNECT_MACROS_TO_GRID) 1
set ::env(PDN_ENABLE_GLOBAL_CONNECTIONS) 1
set ::env(GRT_ADJUSTMENT) 0.299999999999999988897769753748434595763683319091796875
set ::env(GRT_MACRO_EXTENSION) 0
set ::env(GRT_LAYER_ADJUSTMENTS) "0 0 0 0 0"
set ::env(GRT_ALLOW_CONGESTION) 0
set ::env(GRT_ANTENNA_ITERS) 3
set ::env(GRT_OVERFLOW_ITERS) 50
set ::env(GRT_ANTENNA_MARGIN) 10
set ::env(PL_OPTIMIZE_MIRRORING) 1
set ::env(PL_MAX_DISPLACEMENT_X) 500
set ::env(PL_MAX_DISPLACEMENT_Y) 100
set ::env(DPL_CELL_PADDING) 0
set ::env(RSZ_DONT_TOUCH_RX) "\$^"
set ::env(DESIGN_REPAIR_BUFFER_INPUT_PORTS) 1
set ::env(DESIGN_REPAIR_BUFFER_OUTPUT_PORTS) 1
set ::env(DESIGN_REPAIR_TIE_FANOUT) 1
set ::env(DESIGN_REPAIR_TIE_SEPARATION) 0
set ::env(DESIGN_REPAIR_MAX_WIRE_LENGTH) 0
set ::env(DESIGN_REPAIR_MAX_SLEW_PCT) 20
set ::env(DESIGN_REPAIR_MAX_CAP_PCT) 20
set ::env(DESIGN_REPAIR_REMOVE_BUFFERS) 0
set ::env(CURRENT_ODB) /foss/designs/ascon_top_layout/runs/RUN_2026-08-21_17-20-50/27-openroad-globalplacement/ascon_top.odb
set ::env(SAVE_ODB) /foss/designs/ascon_top_layout/runs/RUN_2026-08-21_17-20-50/31-openroad-repairdesignpostgpl/ascon_top.odb
set ::env(SAVE_DEF) /foss/designs/ascon_top_layout/runs/RUN_2026-08-21_17-20-50/31-openroad-repairdesignpostgpl/ascon_top.def
set ::env(SAVE_SDC) /foss/designs/ascon_top_layout/runs/RUN_2026-08-21_17-20-50/31-openroad-repairdesignpostgpl/ascon_top.sdc
set ::env(SAVE_NETLIST) /foss/designs/ascon_top_layout/runs/RUN_2026-08-21_17-20-50/31-openroad-repairdesignpostgpl/ascon_top.nl.v
set ::env(SAVE_POWERED_NETLIST) /foss/designs/ascon_top_layout/runs/RUN_2026-08-21_17-20-50/31-openroad-repairdesignpostgpl/ascon_top.pnl.v
