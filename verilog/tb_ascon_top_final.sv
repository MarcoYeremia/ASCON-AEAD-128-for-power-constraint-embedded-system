// ============================================================================
// File:        tb_ascon_top_kat.sv
// Description: Top-Level Automated NIST LWC Known Answer Test (KAT) Testbench
//              for Ascon-128 (Ascon-AEAD128) over 20 MHz SPI Protocol
// ============================================================================

`timescale 1ns/1ps

module tb_ascon_top_final;

  // ==========================================================================
  // 1. CLOCK & PHYSICAL SPI SIGNALS
  // ==========================================================================
  logic clk;
  logic rst;
  logic sclk;
  logic cs_n;
  logic mosi;
  logic miso;

  // SPI clock = 80 ns total period (relaxed timing: gives the DUT's
  // 2-flop sclk synchronizer a full clk period of margin on both the
  // low and high phases, instead of the original 10 ns low phase which
  // was shorter than one 50 MHz clk cycle and could be missed entirely).
  int spi_period = 80; 
  logic [7:0] rx_byte;

  // 50 MHz System clock = 20 ns period
  always #10 clk = ~clk; 

  // ==========================================================================
  // 2. DEVICE UNDER TEST (DUT) INSTANTIATION
  // ==========================================================================
  ascon_top dut (
    .clk(clk),
    .rst(rst),
    .sclk(sclk),
    .cs_n(cs_n),
    .mosi(mosi),
    .miso(miso)
  );

  // ==========================================================================
  // 3. CORE OUTPUT MONITORS & PULSE TRAPS (ROBUST AUTO-SORTING)
  // ==========================================================================
  logic [31:0] captured_words [$];
  logic [31:0] captured_ct [$];
  logic [31:0] captured_tag [$];
  logic [31:0] captured_dec_pt [$];
  
  logic final_auth_valid;
  logic final_auth_flag;
  bit   in_decryption_phase = 0;

  always_ff @(posedge clk) begin
    if (rst) begin
      final_auth_valid <= 1'b0;
      final_auth_flag  <= 1'b0;
    end else begin
      // Capture all valid outgoing words from the BDO interface
      if (dut.spi_ctrl.bdo_valid && dut.spi_ctrl.bdo_ready) begin
        if (!in_decryption_phase) begin
          // Explicit type routing, with fallback to catch all valid words
          if (dut.spi_ctrl.bdo_type == 4'd3)      captured_ct.push_back(dut.spi_ctrl.bdo);
          else if (dut.spi_ctrl.bdo_type == 4'd4) captured_tag.push_back(dut.spi_ctrl.bdo);
          else                                    captured_words.push_back(dut.spi_ctrl.bdo);
        end else begin
          captured_dec_pt.push_back(dut.spi_ctrl.bdo);
        end
      end
      
      // Latch the 1-cycle authentication flag from Ascon Core
      if (dut.pp_inst.core_inst.auth_valid) begin
        final_auth_valid <= 1'b1;
        final_auth_flag  <= dut.pp_inst.core_inst.auth;
      end
    end
  end

  // ==========================================================================
  // 4. SPI MASTER PROTOCOL TASKS (20 MHz ASYMMETRIC SYNCHRONIZER-SAFE TIMING)
  // ==========================================================================
  task spi_trx(input logic [7:0] tx_data, output logic [7:0] rx_data);
    rx_data = 8'h00;
    for (int i = 7; i >= 0; i--) begin
      mosi = tx_data[i]; 
      #40;                    // 40 ns SCLK Low phase (>= 2 clk periods:
                               // gives the 2-flop sclk synchronizer time
                               // to reliably resolve the low level before
                               // the rising edge, unlike the old 10 ns
                               // phase which was sub-one-clk-period and
                               // could be missed by the synchronizer)
      sclk = 1'b1;            // SCLK rising edge

      #38;    
      rx_data[i] = miso;      // Sample MISO after 2-stage sync settles
      #2;                     // Complete 80 ns SPI period

      sclk = 1'b0;
    end
  endtask

  task send_spi_payload(input logic [7:0] cmd, input byte payload[]);
    cs_n = 0; #(spi_period);
    spi_trx(cmd, rx_byte); 
    for (int i = 0; i < payload.size(); i++) begin
      spi_trx(payload[i], rx_byte); 
    end
    #50; cs_n = 1; #200; 
  endtask

  task flush_miso(input int bytes_to_read);
    cs_n = 0; #(spi_period);
    spi_trx(8'h60, rx_byte); // CMD 0x60: Read FIFO / BDO Data
    for (int i = 0; i < bytes_to_read; i++) begin
      spi_trx(8'h00, rx_byte);
    end
    #50; cs_n = 1; #200;
  endtask

  // ==========================================================================
  // 5. ASCII HEX & FILE-I/O HELPER FUNCTIONS
  // ==========================================================================
  function automatic logic [3:0] hex_char_to_nibble(byte c);
    if (c >= "0" && c <= "9") return c - "0";
    if (c >= "A" && c <= "F") return c - "A" + 10;
    if (c >= "a" && c <= "f") return c - "a" + 10;
    return 4'h0;
  endfunction

  function automatic void hex_str_to_bytes(input string str, output byte arr[]);
    int len = str.len();
    int byte_len = len / 2;
    arr = new[byte_len];
    for (int i = 0; i < byte_len; i++) begin
      arr[i] = (hex_char_to_nibble(str[2*i]) << 4) | hex_char_to_nibble(str[2*i+1]);
    end
  endfunction

  function automatic bit cmp_byte_arrays(input byte a[], input byte b[]);
    if (a.size() != b.size()) return 0;
    for (int i = 0; i < a.size(); i++) begin
      if (a[i] !== b[i]) return 0;
    end
    return 1;
  endfunction

  // ==========================================================================
  // 6. MAIN AUTOMATED NIST KAT FILE-I/O VERIFICATION LOOP
  // ==========================================================================
  integer fd;
  string  line;
  int     kat_count;
  string  key_str, nonce_str, pt_str, ad_str, ct_str;
  
  byte KEY_bytes[], NONCE_bytes[], AD_bytes[], PT_bytes[], RAW_CT_bytes[];
  byte expected_ct[], expected_tag[];
  byte dyn_CT[], dyn_TAG[], dyn_DEC_PT[];
byte mode_enc[], mode_dec[];
byte tx_CT[], tx_TAG[];

  int total_tested = 0;
  int total_passed = 0;
  int total_failed = 0;
  int timeout_cnt;
  int word_idx, byte_idx;
int exp_ct_words;
int w_base, w_len;

  initial begin
    mode_enc = new[1]; mode_enc[0] = 8'h01;
    mode_dec = new[1]; mode_dec[0] = 8'h02;

    $timeformat(-9, 0, " ns", 10); 
    clk = 0; rst = 1; sclk = 0; cs_n = 1; mosi = 0;
    #100; rst = 0; #100;

    $display("\n====================================================================");
    $display("       ASCON-128 TOP-LEVEL NIST KAT AUTOMATED VERIFICATION");
    $display("       System Clock: 50 MHz | SPI Clock: 20 MHz (40ns High Phase)");
    $display("====================================================================");

    fd = $fopen("D:/ACADS/CHIPATHON/2026/ASCON-AEAD-128-for-power-constraint-embedded-system/tb/LWC_AEAD_KAT_128_128.txt", "r");
    if (fd == 0) fd = $fopen("D:/ACADS/CHIPATHON/2026/ASCON-AEAD-128-for-power-constraint-embedded-system/tb/LWC_AEAD_KAT_128_128.txt", "r");
    
    if (fd == 0) begin
      $display(" [FATAL ERROR] Cannot open 'LWC_AEAD_KAT_128_128.txt'.");
      $display("               Ensure the file is generated inside your sim/ folder.");
      $finish;
    end

    while (!$feof(fd)) begin
      void'($fgets(line, fd));

      if (line.len() == 0 || line[0] == "#" || line[0] == "\n") continue;

      if ($sscanf(line, "Count = %d", kat_count) == 1) begin end
      else if ($sscanf(line, "Key = %s", key_str) == 1) begin end
      else if ($sscanf(line, "Nonce = %s", nonce_str) == 1) begin end
      else if (line.substr(0, 3) == "PT =") begin
        if ($sscanf(line, "PT = %s", pt_str) != 1) pt_str = ""; 
      end
      else if (line.substr(0, 3) == "AD =") begin
        if ($sscanf(line, "AD = %s", ad_str) != 1) ad_str = ""; 
      end
      else if ($sscanf(line, "CT = %s", ct_str) == 1) begin
        total_tested++;

        hex_str_to_bytes(key_str,   KEY_bytes);
        hex_str_to_bytes(nonce_str, NONCE_bytes);
        hex_str_to_bytes(ad_str,    AD_bytes);
        hex_str_to_bytes(pt_str,    PT_bytes);
        hex_str_to_bytes(ct_str,    RAW_CT_bytes);

        expected_ct  = new[RAW_CT_bytes.size() - 16];
        expected_tag = new[16];
        for (int i = 0; i < expected_ct.size(); i++)  expected_ct[i]  = RAW_CT_bytes[i];
        for (int i = 0; i < 16; i++)                  expected_tag[i] = RAW_CT_bytes[expected_ct.size() + i];

        // --------------------------------------------------------------------
        // PHASE 1: ENCRYPTION SCENARIO
        // --------------------------------------------------------------------
        rst = 1; #100; rst = 0; #100;
        in_decryption_phase = 0;
        captured_words.delete();
        captured_ct.delete();
        captured_tag.delete();

        send_spi_payload(8'h50, mode_enc);
        send_spi_payload(8'h10, KEY_bytes);
        send_spi_payload(8'h20, NONCE_bytes);
        #1000; // p12 initialization delay

       if (AD_bytes.size() > 0) send_spi_payload(8'h30, AD_bytes);
if (PT_bytes.size() > 0) send_spi_payload(8'h40, PT_bytes);
#1000;
flush_miso(PT_bytes.size() + 16);

        

        // AUTO-SORTING FALLBACK: If bdo_type routing missed words, sort from general capture
        exp_ct_words = (PT_bytes.size() + 3) / 4;
        if (captured_tag.size() == 0 && captured_words.size() >= 4) begin
          while (captured_ct.size() < exp_ct_words && captured_words.size() > 4) begin
            captured_ct.push_back(captured_words.pop_front());
          end
          while (captured_words.size() > 0) begin
            captured_tag.push_back(captured_words.pop_front());
          end
        end

        // Convert 32-bit captured words back to byte arrays for comparison
        dyn_CT  = new[PT_bytes.size()];
        dyn_TAG = new[captured_tag.size() * 4];

        for (int i = 0; i < dyn_CT.size(); i++) begin
          word_idx  = i / 4;
          byte_idx  = i % 4;
          if (word_idx < captured_ct.size())
            dyn_CT[i] = captured_ct[word_idx][byte_idx*8 +: 8];
        end
        foreach (captured_tag[i]) begin
  dyn_TAG[i*4]   = captured_tag[i][7:0]; 
  dyn_TAG[i*4+1] = captured_tag[i][15:8];
  dyn_TAG[i*4+2] = captured_tag[i][23:16];  
  dyn_TAG[i*4+3] = captured_tag[i][31:24];
end

// --------------------------------------------------------------------
// PHASE 2: DECRYPTION & RUP CHECK SCENARIO
// --------------------------------------------------------------------
rst = 1; #100; rst = 0; #100;
in_decryption_phase = 1;
captured_dec_pt.delete();

send_spi_payload(8'h50, mode_dec);
send_spi_payload(8'h10, KEY_bytes);
send_spi_payload(8'h20, NONCE_bytes);
#1000;

if (AD_bytes.size() > 0) begin
  send_spi_payload(8'h30, AD_bytes);
end

if (dyn_CT.size() > 0) begin
  send_spi_payload(8'h40, dyn_CT);
end else begin
  flush_miso(0);
end

#1000;
send_spi_payload(8'h45, dyn_TAG);

if (final_auth_flag) begin
  flush_miso(PT_bytes.size() + 16);
end

dyn_DEC_PT = new[PT_bytes.size()];
for (int i = 0; i < dyn_DEC_PT.size(); i++) begin
  word_idx = i / 4;
  byte_idx = i % 4; // INI SATU-SATUNYA PERBAIKAN YANG KITA BUTUHKAN
  if (word_idx < captured_dec_pt.size())
    dyn_DEC_PT[i] = captured_dec_pt[word_idx][byte_idx*8 +: 8];
end

        // --------------------------------------------------------------------
        // PHASE 3: VERIFICATION LOGGING & ABORT WATCHDOG
        // --------------------------------------------------------------------
        if (cmp_byte_arrays(dyn_CT, expected_ct) && 
            cmp_byte_arrays(dyn_TAG, expected_tag) && 
            cmp_byte_arrays(dyn_DEC_PT, PT_bytes) && 
            final_auth_flag == 1'b1) begin
          total_passed++;
          $display(" [PASS] Count = %03d | AD: %02d B | PT: %02d B | ENC & DEC Matched NIST Reference",
                   kat_count, AD_bytes.size(), PT_bytes.size());
        end else begin
          total_failed++;
          $display(" [FAIL] Count = %03d | AD: %02d B | PT: %02d B | Mismatch Detected!",
                   kat_count, AD_bytes.size(), PT_bytes.size());
          
          $display("        [DEBUG] Captured CT Words : %0d (Expected Bytes: %0d)", captured_ct.size(), expected_ct.size());
          $display("        [DEBUG] Captured Tag Words: %0d (Expected Bytes: 16)", captured_tag.size());

          if (!cmp_byte_arrays(dyn_CT, expected_ct)) begin
            $display("        -> Ciphertext mismatch");
            $write("           Expected CT: "); foreach(expected_ct[k]) $write("%02X", expected_ct[k]); $write("\n");
            $write("           Captured CT: "); foreach(dyn_CT[k])      $write("%02X", dyn_CT[k]);      $write("\n");
          end
          if (!cmp_byte_arrays(dyn_TAG, expected_tag)) begin
            $display("        -> Tag mismatch");
            $write("           Expected Tag: "); foreach(expected_tag[k]) $write("%02X", expected_tag[k]); $write("\n");
            $write("           Captured Tag: "); foreach(dyn_TAG[k])      $write("%02X", dyn_TAG[k]);      $write("\n");
          end
          if (!cmp_byte_arrays(dyn_DEC_PT, PT_bytes)) begin
            $display("        -> Decrypted Plaintext mismatch");
          end
          if (final_auth_flag != 1'b1) begin
            $display("        -> Decryption auth flag was rejected (0)");
          end
        end

        if (total_failed >= 5) begin
          $display("\n [ABORT] Reached 5 consecutive failures. Stopping simulation early.");
          $fclose(fd);
          $finish;
        end
      end
    end

    $fclose(fd);
    $display("--------------------------------------------------------------------");
    $display(" SUMMARY: %0d / %0d NIST KAT VECTORS PASSED", total_passed, total_tested);
    if (total_failed == 0 && total_tested > 0)
      $display(" STATUS : ✅ 100%% NIST LWC COMPLIANT (0 REGRESSION ERRORS)");
    else
      $display(" STATUS : ❌ ERRORS DETECTED");
    $display("====================================================================\n");
    $finish;
  end

  // ==========================================================================
  // 7. GLOBAL SIMULATION TIMEOUT WATCHDOG
  // ==========================================================================
  initial begin
    #300_000_000;
    $display("\n [ERROR] Global Simulation Timeout reached! FSM stalled.");
    $finish;
  end

endmodule
