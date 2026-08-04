`timescale 1ns/1ps

module spi_controller (
  input  logic        clk,
  input  logic        rst,
  input  logic        cs_n,

  input  logic [7:0]  rx_data,
  input  logic        rx_valid,
  output logic [7:0]  tx_data,
  input  logic        tx_ready,

  output logic [31:0] key,
  output logic        key_valid,
  input  logic        key_ready,

  output logic [31:0] bdi,
  output logic [3:0]  bdi_valid,
  input  logic        bdi_ready,
  output logic [3:0]  bdi_type,
  output logic        bdi_eot,
  output logic        bdi_eoi,
  output logic [3:0]  mode,

  input  logic [31:0] bdo,
  input  logic        bdo_valid,
  output logic        bdo_ready,
  input  logic [3:0]  bdo_type,
  input  logic        bdo_eot,

  input  logic        auth,
  input  logic        auth_valid
);

  typedef enum logic [3:0] {
    S_IDLE, S_GET_CMD, S_SET_MODE, S_LOAD_KEY, S_LOAD_NONCE, S_LOAD_AD,
    S_LOAD_MSG, S_LOAD_TAG, S_READ_DATA, S_READ_AUTH
  } state_t;
  state_t state, next_state;

  logic [31:0] word_buf;
  logic [1:0]  byte_cnt;
  logic [2:0]  word_cnt;

  // FIX: AD/MSG words can't be committed to bdi/bdi_eot the instant 4 bytes
  // arrive, because at that point we don't yet know if more bytes are
  // coming (i.e. whether this word is really the *last* one -- needed for
  // correct bdi_eot/bdi_eoi). So a completed AD/MSG word is buffered here
  // and only released either (a) when the *next* byte proves it wasn't
  // the last word, or (b) when cs_n rises, proving it (or a leftover
  // partial word) really was the last one.
  logic [31:0] pend_word;
  logic [2:0]  pend_wcnt;
  logic [3:0]  pend_type;
  logic        pend_valid;

  // NEW: mode register. Default = M_AEAD128_ENC (4'd1) supaya kompatibel
  // dengan host lama yang belum pernah kirim SET_MODE.
  logic [3:0]  mode_reg;

  // ---------------------------------------------------------
  // HAZARD FIX: Synchronize CS_N and add 1-cycle pipeline match
  // ---------------------------------------------------------
  logic [2:0] cs_n_sync;
  logic       cs_rise_comb;
  logic       cs_rise;

  always_ff @(posedge clk or posedge rst) begin
    if (rst) cs_n_sync <= 3'b111;
    else     cs_n_sync <= {cs_n_sync[1:0], cs_n};
  end
  
  // Triggers when the spi_slave considers the transaction over
  assign cs_rise_comb = (cs_n_sync[2:1] == 2'b01);

  // Delay by exactly 1 clock cycle to match the rx_valid flip-flop in spi_slave
  always_ff @(posedge clk or posedge rst) begin
    if (rst) cs_rise <= 1'b0;
    else     cs_rise <= cs_rise_comb;
  end

  // ---------------------------------------------------------
  // MISO BDO ROUTING FIX: 32-bit Shift Register
  // ---------------------------------------------------------
  logic [31:0] tx_shift_reg;
  logic [1:0]  tx_byte_cnt;
  logic        tx_busy;

  // FIX (word-boundary race): previously bdo_ready only went high once
  // ALL 4 bytes of the current word had been shifted out (tx_busy==0),
  // giving the core ~0ns of lead time to present the next word before
  // spi_slave's own byte-boundary reload asks for it -- a real race:
  // whichever event's clock edge landed first "won", and the loser was
  // a stale/zero byte silently substituted in. A staging register lets
  // the core hand off the next word as soon as it's ready (in practice
  // within a cycle or two), fully decoupled from when the *current*
  // word finishes physically shifting out over MISO -- giving up to a
  // full byte-period (~640ns @ typical SPI rates) of margin instead.
  logic [31:0] tx_stage;
  logic        tx_stage_valid;

  // FIX (first-byte-of-burst loss): when the very first word of a read
  // burst is only ready *after* spi_slave has already committed to
  // transmitting a (necessarily stale/zero) byte -- which is always the
  // case right after a command whose response can only be computed once
  // the command itself has been seen, e.g. the AD=0/PT=0 finalization
  // path -- the tx_ready that ends that already-in-flight stale byte
  // still looks, from spi_controller's point of view, like "byte 0 of
  // the new word was just sent", and unconditionally shifts to byte 1.
  // Byte 0 is silently lost, permanently, no matter how much lead time
  // preceded the load. This flag marks a freshly (same-cycle) loaded
  // word so the very next tx_ready is treated as "closing out the stale
  // byte that was already committed" rather than "byte 0 was sent" --
  // consuming that one pulse without advancing, so byte 0 is genuinely
  // transmitted on the following (real) transfer.
  logic tx_fresh;

  assign bdo_ready = ~tx_stage_valid;

  // NEW: byte laporan status auth, dibaca lewat command 0x70 (READ_AUTH)
  logic [7:0] auth_byte;
  assign auth_byte = {6'b0, auth_valid, auth};

  // FIX (byte order): bdo words are packed little-endian internally
  // (matching the Ascon reference), so the first logical byte of each
  // word is in bits[7:0], not bits[31:24]. Send that one first.
  assign tx_data = (state == S_READ_AUTH) ? auth_byte : tx_shift_reg[7:0];

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      tx_shift_reg   <= 32'd0;
      tx_byte_cnt    <= 2'd0;
      tx_busy        <= 1'b0;
      tx_stage       <= 32'd0;
      tx_stage_valid <= 1'b0;
      tx_fresh       <= 1'b0;
    end else begin
      // FIX (first-word race): the very first word of a burst has the
      // exact same one-cycle-late problem as the word-to-word case --
      // routing it through the stage register first (tx_stage_valid<=1
      // this cycle, promoted only next cycle) is one cycle too slow for
      // spi_slave's reload. When nothing is active yet, load directly
      // into the active register on the same cycle bdo arrives instead.
      if (!tx_busy && bdo_valid && bdo_ready) begin
        tx_shift_reg <= bdo;
        tx_busy      <= 1'b1;
        tx_byte_cnt  <= 2'd0;
        tx_fresh     <= 1'b1;
      end else if (bdo_valid && bdo_ready) begin
        // Active register busy with a previous word -- stage this one
        // for the word-boundary handoff below.
        tx_stage       <= bdo;
        tx_stage_valid <= 1'b1;
      end

      if (tx_busy && tx_ready && (state == S_READ_DATA || state == S_LOAD_MSG)) begin
        if (tx_fresh) begin
          // This tx_ready closes out a byte that was already committed
          // to transmission (necessarily stale) before our fresh word
          // was loaded -- absorb the pulse, don't advance byte_cnt or
          // shift, so byte 0 of the fresh word is genuinely sent next.
          tx_fresh <= 1'b0;
        end else if (tx_byte_cnt == 2'd3) begin
          // FIX (word-boundary race): promote the staged word on this
          // SAME cycle, not one cycle later via the !tx_busy branch
          // above. Promoting a cycle late was the actual bug -- it
          // doesn't matter how far in advance the word was staged, the
          // handoff to spi_slave was always exactly one cycle too slow,
          // which is enough for spi_slave's own byte-boundary reload to
          // sample the stale/zeroed tx_data instead of the new word.
          if (tx_stage_valid) begin
            tx_shift_reg   <= tx_stage;
            tx_byte_cnt    <= 2'd0;
            tx_stage_valid <= 1'b0;
            // tx_busy stays asserted -- no gap at all between words.
          end else begin
            tx_shift_reg <= {8'h00, tx_shift_reg[31:8]};
            tx_busy      <= 1'b0;
          end
        end else begin
          tx_shift_reg <= {8'h00, tx_shift_reg[31:8]};
          tx_byte_cnt  <= tx_byte_cnt + 2'd1;
        end
      end
    end
  end

  // ---------------------------------------------------------
  // State Machine & Core Interaction Logic
  // ---------------------------------------------------------
  always_ff @(posedge clk or posedge rst) begin
    if (rst) state <= S_IDLE;
    else if (cs_rise) state <= S_IDLE;
    else state <= next_state;
  end

  always_comb begin
    next_state = state;
    case (state)
      S_IDLE: if (cs_n == 1'b0) next_state = S_GET_CMD;
      S_GET_CMD: begin
        if (rx_valid) begin
          case (rx_data)
            8'h10: next_state = S_LOAD_KEY;
            8'h20: next_state = S_LOAD_NONCE;
            8'h30: next_state = S_LOAD_AD;   
            8'h40: next_state = S_LOAD_MSG;
            8'h45: next_state = S_LOAD_TAG;   // NEW: dekripsi - load tag 128-bit
            8'h50: next_state = S_SET_MODE;   // NEW: set mode ENC/DEC
            8'h60: next_state = S_READ_DATA;
            8'h70: next_state = S_READ_AUTH;  // NEW: baca status auth
            default: next_state = S_IDLE;
          endcase
        end
      end
      default: next_state = state;
    endcase
  end

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      byte_cnt   <= 0;
      word_cnt   <= 0;
      key_valid  <= 0;
      bdi_valid  <= 0;
      bdi_type   <= 0;
      bdi_eot    <= 0;
      bdi_eoi    <= 0;
      key        <= 0;
      bdi        <= 0;
      mode_reg   <= 4'd0;  // default: M_AEAD128_ENC, backward-compatible
      pend_valid <= 0;
      pend_word  <= 0;
      pend_wcnt  <= 0;
      pend_type  <= 0;
    end else begin
      if (key_valid && key_ready) key_valid <= 0;
      if (bdi_valid != 0 && bdi_ready) bdi_valid <= 0;

      // Default: bdi_eoi is a single-cycle pulse. It used to never be
      // cleared at all once set, and was hardcoded to 0 on the NONCE/AD
      // paths -- both fixed here.
      bdi_eoi <= 1'b0;

      // NEW: tangkap payload byte SET_MODE (0x01=ENC, 0x02=DEC)
      if (state == S_SET_MODE && rx_valid) begin
        mode_reg <= rx_data[3:0];
      end

      // FIX (empty-input deadlock): if the host jumps straight to
      // READ_DATA (0x60) without ever sending AD or MSG, the core would
      // otherwise sit forever in KADD_2/ABS_MSG waiting for data that is
      // never coming (e.g. AD=0 & PT=0, or AD>0 & PT=0). Pulse bdi_eoi so
      // ascon_core's escape-hatch (added there) can finalize instead.
      // Harmless if the core has already progressed past that point.
      if (state == S_GET_CMD && rx_valid && rx_data == 8'h60) begin
        bdi_eoi <= 1'b1;
      end

      if (cs_rise) begin
        byte_cnt <= 0;
        word_cnt <= 0;

        // A previously-buffered *complete* AD/MSG word turns out to be
        // the true last word of this segment now that CS has risen.
        if (pend_valid) begin
          bdi        <= pend_word;
          bdi_valid  <= 4'b1111;
          bdi_type   <= pend_type;
          bdi_eot    <= 1'b1;
          bdi_eoi    <= (pend_type == 4'd3) ? 1'b1 : 1'b0;  // D_MSG => end of input
          pend_valid <= 1'b0;
        end
        // A partial (1-3 byte) word was sitting in word_buf with no
        // chance yet to be buffered as a full word -- flush it now with
        // only the actually-received bytes marked valid.
        else if (byte_cnt != 0 && (state == S_LOAD_AD || state == S_LOAD_MSG)) begin
          bdi <= word_buf;
          case (byte_cnt)
            // FIX (byte order): with LSB-first packing, N valid bytes
            // occupy the LOW N byte lanes (val[0], val[1], ...), not the
            // high ones.
            2'd1: bdi_valid <= 4'b0001;
            2'd2: bdi_valid <= 4'b0011;
            2'd3: bdi_valid <= 4'b0111;
            default: bdi_valid <= 4'b0000;
          endcase
          bdi_type <= (state == S_LOAD_MSG) ? 4'd3 : 4'd2;
          bdi_eot  <= 1'b1;
          bdi_eoi  <= (state == S_LOAD_MSG) ? 1'b1 : 1'b0;
        end

      end else if ((state == S_LOAD_KEY || state == S_LOAD_NONCE || state == S_LOAD_AD
                    || state == S_LOAD_MSG || state == S_LOAD_TAG) && rx_valid) begin

        // A new byte just arrived, proving a previously-buffered AD/MSG
        // word was NOT the last word after all -- release it now as a
        // normal (non-final) word.
        if (pend_valid) begin
          bdi        <= pend_word;
          bdi_valid  <= 4'b1111;
          bdi_type   <= pend_type;
          bdi_eot    <= (pend_wcnt == 3'd3) ? 1'b1 : 1'b0;
          bdi_eoi    <= 1'b0;
          pend_valid <= 1'b0;
        end

        // FIX (byte order): Ascon (per the NIST SP 800-232 reference)
        // packs each byte-string into its 64-bit state words LITTLE-ENDIAN
        // -- the first byte received becomes the LOW byte of the word, not
        // the high byte. Pack LSB-first here so key/nonce/AD/msg/tag values
        // land in the state the way the core expects.
        if (byte_cnt == 0) word_buf[7:0]   <= rx_data;
        if (byte_cnt == 1) word_buf[15:8]  <= rx_data;
        if (byte_cnt == 2) word_buf[23:16] <= rx_data;
        if (byte_cnt == 3) begin

          key <= {rx_data, word_buf[23:0]};

          if (state == S_LOAD_KEY) begin
             key_valid <= 1;
          end else if (state == S_LOAD_NONCE) begin
             // NONCE is always exactly 16 bytes -- no ambiguity, commit directly.
             bdi       <= {rx_data, word_buf[23:0]};
             bdi_valid <= 4'b1111;
             bdi_type  <= 4'd1;
             bdi_eot   <= (word_cnt == 3) ? 1'b1 : 1'b0;
             bdi_eoi   <= 0;
          end else if (state == S_LOAD_AD) begin
             // FIX: don't commit yet -- we don't know if more AD bytes
             // are coming. Buffer it; release happens above.
             pend_word  <= {rx_data, word_buf[23:0]};
             pend_wcnt  <= word_cnt;
             pend_type  <= 4'd2;
             pend_valid <= 1'b1;
          end else if (state == S_LOAD_MSG) begin
             // FIX: same deferred-commit treatment as AD.
             pend_word  <= {rx_data, word_buf[23:0]};
             pend_wcnt  <= word_cnt;
             pend_type  <= 4'd3;
             pend_valid <= 1'b1;
          end else if (state == S_LOAD_TAG) begin
             // TAG is always exactly 16 bytes -- no ambiguity, commit directly.
             bdi       <= {rx_data, word_buf[23:0]};
             bdi_valid <= 4'b1111;
             bdi_type  <= 4'd4;  // D_TAG
             bdi_eot   <= (word_cnt == 3) ? 1'b1 : 1'b0;
             bdi_eoi   <= 0;
          end
          word_cnt <= word_cnt + 1;
        end
        byte_cnt <= byte_cnt + 1;
      end
    end
  end

  assign mode = mode_reg;  // was hardcoded 4'd1 (ENC-only)

endmodule