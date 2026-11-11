`timescale 1ns/1ps
`include "config.sv"

module postprocessor_rup (
  input logic clk,
  input logic rst,
  
  input logic [CCW-1:0] key,
  input logic key_valid,
  output logic key_ready,
  input logic [CCW-1:0] bdi,
  input logic [CCW/8-1:0] bdi_valid,
  output logic bdi_ready,
  input logic [3:0] bdi_type,
  input logic bdi_eot,
  input logic bdi_eoi,
  input logic [3:0] mode,
  
  output logic [CCW-1:0] safe_bdo,
  output logic safe_bdo_valid,
  input logic safe_bdo_ready,
  output logic [3:0] safe_bdo_type,
  output logic safe_bdo_eot,
  
  output logic auth,
  output logic auth_valid
);

  logic [CCW-1:0] core_bdo;
  logic core_bdo_valid;
  logic core_bdo_ready;
  logic [3:0] core_bdo_type;
  logic core_bdo_eot;
  logic core_bdo_eoo;

  // 128 words (512 bytes): holds up to 64 words of quarantined plaintext (DEC)
  // or up to 64 words of ciphertext + 4 words of authentication tag (ENC).
  // Synchronous read and an unreset memory array permit FPGA RAM inference.
  (* ram_style = "block" *) logic [CCW+4:0] fifo_mem [0:127];
  logic [7:0] wr_ptr, rd_ptr;
  logic release_buffer;
  logic [CCW+4:0] read_word;
  logic read_valid;
  logic auth_seen;

  // Deteksi mode dekripsi untuk RUP quarantine
  logic is_decrypt;
  assign is_decrypt = (mode == 4'd2);

  wire can_release = is_decrypt ? release_buffer : 1'b1;
  wire fifo_full   = ((wr_ptr - rd_ptr) >= 8'd128);
  wire write_word  = core_bdo_valid && core_bdo_ready;
  wire fetch_word  = can_release && !read_valid && (rd_ptr != wr_ptr);
  assign core_bdo_eoo = 1'b0;

  ascon_core core_inst (
    .clk(clk), .rst(rst),
    .key(key), .key_valid(key_valid), .key_ready(key_ready),
    .bdi(bdi), .bdi_valid(bdi_valid), .bdi_ready(bdi_ready),
    .bdi_type(bdi_type), .bdi_eot(bdi_eot), .bdi_eoi(bdi_eoi),
    .mode(mode),
    .bdo(core_bdo), .bdo_valid(core_bdo_valid), .bdo_ready(core_bdo_ready),
    .bdo_type(core_bdo_type), .bdo_eot(core_bdo_eot), .bdo_eoo(core_bdo_eoo),
    .auth(auth), .auth_valid(auth_valid)
  );

  assign safe_bdo       = read_word[CCW-1:0];
  assign safe_bdo_type  = read_word[CCW+3:CCW];
  assign safe_bdo_eot   = read_word[CCW+4];
  assign safe_bdo_valid = read_valid;
  assign core_bdo_ready = !fifo_full && (!is_decrypt || !release_buffer);

  // No reset on RAM contents or its read-data register. Valid/pointer state
  // prevents stale data from being transferred. This is logical discard,
  // not physical zeroization of plaintext memory.
  always_ff @(posedge clk) begin
    if (!rst && write_word)
      fifo_mem[wr_ptr[6:0]] <= {core_bdo_eot, core_bdo_type, core_bdo};
  end

  // Host contract: mode remains stable for the message; starting a new key
  // load cleanly resets the FIFO for the next message.
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      wr_ptr         <= 8'd0;
      rd_ptr         <= 8'd0;
      release_buffer <= 1'b0;
      read_word      <= '0;
      read_valid     <= 1'b0;
      auth_seen      <= 1'b0;
    end else if (key_valid && key_ready) begin
      wr_ptr         <= 8'd0;
      rd_ptr         <= 8'd0;
      release_buffer <= 1'b0;
      read_word      <= '0;
      read_valid     <= 1'b0;
      auth_seen      <= 1'b0;
    end else begin
      auth_seen <= auth_valid;
      if (write_word) wr_ptr <= wr_ptr + 8'd1;
      if (fetch_word) read_word <= fifo_mem[rd_ptr[6:0]];

      if (is_decrypt && auth_valid && !auth_seen) begin
        if (auth) begin
          release_buffer <= (wr_ptr != rd_ptr);
        end else begin
          wr_ptr         <= 8'd0;
          rd_ptr         <= 8'd0;
          release_buffer <= 1'b0;
          read_valid     <= 1'b0;
        end
      end else if (fetch_word) begin
        rd_ptr     <= rd_ptr + 8'd1;
        read_valid <= 1'b1;
      end else if (read_valid && safe_bdo_ready) begin
        read_valid <= 1'b0;
        if ((rd_ptr == wr_ptr) && !write_word) begin
          // Reclaim all capacity after the LAST output handshake.
          wr_ptr         <= 8'd0;
          rd_ptr         <= 8'd0;
          release_buffer <= 1'b0;
        end
      end
    end
  end
endmodule
