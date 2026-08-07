// SPDX-FileCopyrightText: 2026 Chipathon 2026 workshop
// SPDX-License-Identifier: Apache-2.0
//
// chip_core: Integration wrapper connecting ascon_top to the GF180MCU Padring

`default_nettype none

module chip_core #(
    parameter NUM_INPUT_PADS  = 1,
    parameter NUM_BIDIR_PADS  = 20,
    parameter NUM_ANALOG_PADS = 60
    )(
    `ifdef USE_POWER_PINS
    inout  wire VDD,
    inout  wire VSS,
    `endif

    input  wire clk,       // Dedicated Clock pad
    input  wire rst_n,     // Dedicated Reset pad (active low)

    input  wire [NUM_INPUT_PADS-1:0] input_in,   // Input value
    output wire [NUM_INPUT_PADS-1:0] input_pu,   // Pull-up
    output wire [NUM_INPUT_PADS-1:0] input_pd,   // Pull-down

    input  wire [NUM_BIDIR_PADS-1:0] bidir_in,   // Input value
    output wire [NUM_BIDIR_PADS-1:0] bidir_out,  // Output value
    output wire [NUM_BIDIR_PADS-1:0] bidir_oe,   // Output enable (1=Output, 0=Input)
    output wire [NUM_BIDIR_PADS-1:0] bidir_cs,   // Input type (0=CMOS, 1=Schmitt)
    output wire [NUM_BIDIR_PADS-1:0] bidir_sl,   // Slew rate (0=fast, 1=slow)
    output wire [NUM_BIDIR_PADS-1:0] bidir_ie,   // Input enable (1=Enabled)
    output wire [NUM_BIDIR_PADS-1:0] bidir_pu,   // Pull-up
    output wire [NUM_BIDIR_PADS-1:0] bidir_pd,   // Pull-down

    inout  wire [NUM_ANALOG_PADS-1:0] analog     // Analog pass-through
);

    // =========================================================================
    // 1. PAD PULL-UP / PULL-DOWN & ELECTRICAL CONFIGURATION
    // =========================================================================
    // Disable internal pull-ups and pull-downs for all digital pads
    assign input_pu = '0;
    assign input_pd = '0;
    assign bidir_pu = '0;
    assign bidir_pd = '0;

    // Use fast slew rate and standard CMOS input thresholds for all bidir pads
    assign bidir_sl = '0;
    assign bidir_cs = '0;

    // =========================================================================
    // 2. SPI BIDIRECTIONAL PAD DIRECTION CONTROL (OE / IE)
    // =========================================================================
    // bidir[0] = SCLK (Input)
    // bidir[1] = MOSI (Input)
    // bidir[2] = MISO (Output)
    // bidir[19:3] = Unused (Configured as disabled inputs to prevent bus contention)
    assign bidir_oe = { {(NUM_BIDIR_PADS-3){1'b0}}, 1'b1, 1'b0, 1'b0 };
    assign bidir_ie = ~bidir_oe; // Input enable is complementary to output enable

    // =========================================================================
    // 3. ASCON TOP INSTANTIATION & PIN MAPPING
    // =========================================================================
    logic miso_wire;

    ascon_top u_ascon_top (
      .clk   (clk),
      .rst   (~rst_n),       // Invert active-low rst_n to active-high rst
      .cs_n  (input_in[0]),  // CS_N assigned to the single dedicated input pad
      .sclk  (bidir_in[0]),  // SCLK assigned to bidir pad 0 (input)
      .mosi  (bidir_in[1]),  // MOSI assigned to bidir pad 1 (input)
      .miso  (miso_wire)     // MISO driven out from SPI slave
    );

    // Wire MISO to bidir_out[2], drive 0 on all unused bidir output pins
    assign bidir_out = { {(NUM_BIDIR_PADS-3){1'b0}}, miso_wire, 2'b00 };

    // =========================================================================
    // 4. UNUSED PIN TIE-OFF (Prevents Yosys synthesis warnings/optimization)
    // =========================================================================
    logic _unused;
    assign _unused = &{1'b0, bidir_in[NUM_BIDIR_PADS-1:2]};

endmodule

`default_nettype wire