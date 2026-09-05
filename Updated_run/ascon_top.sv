`timescale 1ns/1ps

module ascon_top (
  // 1. Pin Input Fungsional
  input  logic clk,
  input  logic rst,
  input  logic sclk,
  input  logic cs_n,
  input  logic mosi,

  // 2. Kontrol Resistive Pulling Input (0 0 = Normal CMOS)
  output logic clk_PU,   output logic clk_PD,
  output logic rst_PU,   output logic rst_PD,
  output logic cs_n_PU,  output logic cs_n_PD,
  output logic sclk_PU,  output logic sclk_PD,
  output logic mosi_PU,  output logic mosi_PD,

  // 3. Pin MISO dan Kontrol I/O Pad-nya
  output logic miso_OUT,
  input  logic miso_IN,
  output logic miso_IE,
  output logic miso_OE,
  output logic miso_PU,
  output logic miso_PD,
  output logic miso_CS,
  output logic miso_SL,
  output logic miso_PDRV1,
  output logic miso_PDRV0
);
 (* keep = 1 *) logic dummy_sink;
assign dummy_sink = miso_IN;
  // ==========================================
  // GF180MCU DIGITAL I/O PAD TIE-OFFS
  // ==========================================

  assign clk_PU  = 1'b0; assign clk_PD  = 1'b0;
  assign rst_PU  = 1'b0; assign rst_PD  = 1'b0;
  assign cs_n_PU = 1'b0; assign cs_n_PD = 1'b0;
  assign sclk_PU = 1'b0; assign sclk_PD = 1'b0;
  assign mosi_PU = 1'b0; assign mosi_PD = 1'b0;

  assign miso_IE    = 1'b0; 
  assign miso_OE    = 1'b1; 
  assign miso_PU    = 1'b0; 
  assign miso_PD    = 1'b0; 
  assign miso_CS    = 1'b0; 
  assign miso_SL    = 1'b0; 
  assign miso_PDRV1 = 1'b0; 
  assign miso_PDRV0 = 1'b1; 

  // ==========================================
  // LOGIKA INTERNAL ASLI (TIDAK ADA YANG DIHAPUS)
  // ==========================================

  logic [7:0] rx_data;
  logic       rx_valid;
  logic [7:0] tx_data;
  logic       tx_ready;

  logic [31:0] key;
  logic        key_valid;
  logic        key_ready;
  logic [31:0] bdi;
  logic [3:0]  bdi_valid;
  logic        bdi_ready;
  logic [3:0]  bdi_type;
  logic        bdi_eot;
  logic        bdi_eoi;
  logic [3:0]  mode;
  logic [31:0] bdo;
  logic        bdo_valid;
  logic        bdo_ready;
  logic [3:0]  bdo_type;
  logic        bdo_eot;
  logic        auth;
  logic        auth_valid;

  spi_slave spi_phy (
    .clk(clk),
    .rst(rst),
    .sclk(sclk),
    .cs_n(cs_n),
    .mosi(mosi),
    .miso(miso_OUT), // <--- INI SATU-SATUNYA YANG BERUBAH DARI LOGIKAMU
    .rx_data(rx_data),
    .rx_valid(rx_valid),
    .tx_data(tx_data),
    .tx_ready(tx_ready)
  );

  spi_controller spi_ctrl (
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

  postprocessor_rup pp_inst (
    .clk(clk),
    .rst(rst),
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
    .safe_bdo(bdo),
    .safe_bdo_valid(bdo_valid),
    .safe_bdo_ready(bdo_ready),
    .safe_bdo_type(bdo_type),
    .safe_bdo_eot(bdo_eot),
    .auth(auth),
    .auth_valid(auth_valid)
  );

endmodule