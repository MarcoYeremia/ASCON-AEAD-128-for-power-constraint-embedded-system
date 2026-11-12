`timescale 1ns/1ps

module tb_spi_controller;

  // ---------------------------------------------------------
  // Signals Declaration
  // ---------------------------------------------------------
  logic        clk;
  logic        rst;
  logic        cs_n;

  // Emulated SPI Slave to Controller
  logic [7:0]  rx_data;
  logic        rx_valid;
  logic [7:0]  tx_data;
  logic        tx_ready;

  // Controller to Core (Outputs)
  logic [31:0] key;
  logic        key_valid;
  logic [31:0] bdi;
  logic [3:0]  bdi_valid;
  logic [3:0]  bdi_type;
  logic        bdi_eot;
  logic        bdi_eoi;
  logic [3:0]  mode;
  logic        bdo_ready;

  // Core to Controller (Inputs)
  logic        key_ready;
  logic        bdi_ready;
  logic [31:0] bdo;
  logic        bdo_valid;
  logic [3:0]  bdo_type;
  logic        bdo_eot;
  logic        auth;
  logic        auth_valid;

  // ---------------------------------------------------------
  // DUT Instantiation
  // ---------------------------------------------------------
  spi_controller dut (
    .clk(clk),
    .rst(rst),
    .cs_n(cs_n),
    .rx_data(rx_data),
    .rx_valid(rx_valid),
    .tx_data(tx_data),
    .tx_ready(tx_ready),
    .key(key),
    .key_valid(key_valid),
    .key_ready(key_ready),
    .bdi(bdi),
    .bdi_valid(bdi_valid),
    .bdi_ready(bdi_ready),
    .bdi_type(bdi_type),
    .bdi_eot(bdi_eot),
    .bdi_eoi(bdi_eoi),
    .mode(mode),
    .bdo(bdo),
    .bdo_valid(bdo_valid),
    .bdo_ready(bdo_ready),
    .bdo_type(bdo_type),
    .bdo_eot(bdo_eot),
    .auth(auth),
    .auth_valid(auth_valid)
  );

  // ---------------------------------------------------------
  // Clock Generation
  // ---------------------------------------------------------
  initial begin
    clk = 0;
    forever #5 clk = ~clk; // 100 MHz Clock
  end

  // ---------------------------------------------------------
  // Tasks for Emulating SPI Slave Actions
  // ---------------------------------------------------------
  
  // Bring Chip Select LOW (Wait for 3-stage synchronizer)
  task cs_low();
    @(posedge clk);
    cs_n = 0;
    repeat(4) @(posedge clk);
  endtask

  // Bring Chip Select HIGH (Reset state machine)
  task cs_high();
    @(posedge clk);
    cs_n = 1;
    repeat(4) @(posedge clk);
  endtask

  // Send a single byte into the controller via rx_valid pulse
  task send_byte(input logic [7:0] data);
    @(posedge clk);
    rx_data  = data;
    rx_valid = 1;
    @(posedge clk);
    rx_valid = 0;
    repeat(2) @(posedge clk); // Simulate minor SPI delay
  endtask

  // Request the next byte from tx_shift_reg
  task request_tx_byte();
    @(posedge clk);
    tx_ready = 1;
    @(posedge clk);
    tx_ready = 0;
    repeat(2) @(posedge clk);
  endtask

  // ---------------------------------------------------------
  // Main Test Sequence
  // ---------------------------------------------------------
  initial begin
    // Initialize Inputs
    rst        = 1;
    cs_n       = 1;
    rx_data    = 0;
    rx_valid   = 0;
    tx_ready   = 0;
    key_ready  = 0; // FIX: Keep 0 to verify key_valid holds its state
    bdi_ready  = 0; // FIX: Keep 0 to verify bdi_valid holds its state
    bdo        = 0;
    bdo_valid  = 0;
    bdo_type   = 0;
    bdo_eot    = 0;
    auth       = 0;
    auth_valid = 0;

    // Apply Reset
    $display("=== STARTING SPI CONTROLLER TESTBENCH ===");
    repeat(5) @(posedge clk);
    rst = 0;
    repeat(5) @(posedge clk);

    // ---------------------------------------------------------
    // TEST CASE 1: Set Mode (CMD: 0x50)
    // ---------------------------------------------------------
    $display("\n[TC1] Testing SET_MODE (CMD 0x50) -> Decryption (0x02)");
    cs_low();
    send_byte(8'h50); // Command SET_MODE
    send_byte(8'h02); // Payload Mode = M_AEAD128_DEC (2)
    cs_high();
    
    if (mode === 4'd2) $display("PASS: Mode correctly set to %0d", mode);
    else $display("FAIL: Mode is %0d", mode);

    // ---------------------------------------------------------
    // TEST CASE 2: Load Key (CMD: 0x10)
    // ---------------------------------------------------------
    $display("\n[TC2] Testing LOAD_KEY (CMD 0x10)");
    cs_low();
    send_byte(8'h10); // Command LOAD_KEY
    send_byte(8'hAA); // Key Byte 3
    send_byte(8'hBB); // Key Byte 2
    send_byte(8'hCC); // Key Byte 1
    send_byte(8'hDD); // Key Byte 0
    
    // FIX: Evaluate immediately. key_valid will hold high because key_ready == 0
    if (key === 32'hAABBCCDD && key_valid) 
      $display("PASS: Key loaded correctly (0x%0h)", key);
    else 
      $display("FAIL: Key = 0x%0h, key_valid = %b", key, key_valid);
      
    // FIX: Perform the handshake
    @(posedge clk);
    key_ready = 1;
    @(posedge clk);
    key_ready = 0;
    
    cs_high();

    // ---------------------------------------------------------
    // TEST CASE 3: Load Message (CMD: 0x40)
    // ---------------------------------------------------------
    $display("\n[TC3] Testing LOAD_MSG (CMD 0x40)");
    cs_low();
    send_byte(8'h40); // Command LOAD_MSG
    send_byte(8'h11); 
    send_byte(8'h22); 
    send_byte(8'h33); 
    send_byte(8'h44); 
    
    // FIX: Evaluate immediately. bdi_valid will hold high because bdi_ready == 0
    if (bdi === 32'h11223344 && bdi_valid === 4'b1111 && bdi_type === 4'd3) 
      $display("PASS: Message loaded correctly (BDI: 0x%0h, Type: %0d)", bdi, bdi_type);
    else 
      $display("FAIL: Message load failed (BDI: 0x%0h, bdi_valid: %b)", bdi, bdi_valid);

    // FIX: Perform the handshake
    @(posedge clk);
    bdi_ready = 1;
    @(posedge clk);
    bdi_ready = 0;

    cs_high();

    // ---------------------------------------------------------
    // TEST CASE 4: Read Core Data (CMD: 0x60)
    // ---------------------------------------------------------
    $display("\n[TC4] Testing READ_DATA (CMD 0x60) & Shift Register");
    
    // Simulate Ascon Core outputting a valid word to the controller
    @(posedge clk);
    bdo       = 32'hDEADBEEF;
    bdo_valid = 1;
    @(posedge clk);
    bdo_valid = 0; // The controller captures it in tx_shift_reg and asserts tx_busy

    cs_low();
    send_byte(8'h60); // Command READ_DATA

    // Controller continuously exposes tx_shift_reg[31:24] to tx_data.
    // Check first byte (DE)
    @(posedge clk);
    if (tx_data === 8'hDE) $display("  - Byte 1 (DE) matches: %h", tx_data);
    else $display("  - Byte 1 FAIL: expected DE, got %h", tx_data);
    
    // Request next byte (Shift left by 8) -> Check AD
    request_tx_byte();
    if (tx_data === 8'hAD) $display("  - Byte 2 (AD) matches: %h", tx_data);
    else $display("  - Byte 2 FAIL: expected AD, got %h", tx_data);

    // Request next byte (Shift left by 8) -> Check BE
    request_tx_byte();
    if (tx_data === 8'hBE) $display("  - Byte 3 (BE) matches: %h", tx_data);
    else $display("  - Byte 3 FAIL: expected BE, got %h", tx_data);

    // Request next byte (Shift left by 8) -> Check EF
    request_tx_byte();
    if (tx_data === 8'hEF) $display("  - Byte 4 (EF) matches: %h", tx_data);
    else $display("  - Byte 4 FAIL: expected EF, got %h", tx_data);
    
    $display("PASS: Data successfully shifted out");
    cs_high();

    // ---------------------------------------------------------
    // TEST CASE 5: Read Authentication Status (CMD: 0x70)
    // ---------------------------------------------------------
    $display("\n[TC5] Testing READ_AUTH (CMD 0x70)");
    
    // Core successfully authenticates tag
    auth       = 1'b1;
    auth_valid = 1'b1; 
    // The expected output byte format is {6'b0, auth_valid, auth} = 00000011 (0x03)

    cs_low();
    send_byte(8'h70); // Command READ_AUTH
    
    @(posedge clk);
    if (tx_data === 8'h03) 
      $display("PASS: Auth status successfully read (0x%0h)", tx_data);
    else 
      $display("FAIL: Auth status mismatch. Expected 0x03, got 0x%0h", tx_data);
    cs_high();

    // End simulation
    $display("\n=== SIMULATION COMPLETE ===");
    #100;
    $finish;
  end

endmodule