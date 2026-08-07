# Chipathon 2026 A68 - Ascon-128 AEAD Cryptographic Core

## Design Objective
**Owner:** Corryn

Build a high-throughput, secure digital cryptographic core for the Ascon-128 AEAD (Authenticated Encryption with Associated Data) algorithm, driven by a standard SPI slave interface.

*   Implement the Ascon-128 sponge construction utilizing a 320-bit internal state, 128-bit Key, and 128-bit Nonce, in compliance with the NIST Lightweight Cryptography standard.
*   Integrate an SPI Slave controller to handle continuous serial data streaming (loading the Key, Nonce, Associated Data, and Plaintext) and readout (Ciphertext and 128-bit Authentication Tag).
*   Implement the four distinct Ascon operational phases inside the main FSM: Initialization (12-round permutation), Associated Data processing (6-round), Plaintext Processing (6-round), and Finalization (12-round).
*   Employ a robust clocking architecture: The SPI interface deserializes data using `spi_sclk`, while a faster system `clk` drives the 320-bit permutation logic to execute multi-round calculations efficiently.
*   Verify hardware output (Ciphertext and Tag validity) against the official Ascon software golden model using comprehensive SPI bus transactions.

### Target Specifications

| Parameter | Target specs |
| :--- | :--- |
| **Power** | 5mW (Dynamic power consumption)<br>≤ 500µW (Static/Leakage Power) |
| **Performance** | Internal clk: 50 MHz<br>Serial sclk: 20 MHz (Max) |
| **Area** | < 500µm × 500µm (210µm × 210µm × 210µm) |
| **Pin Count** | 6 Signal Pins<br>2 Power Pins* |
| **Internal Data Width** | 320-bit Sponge State<br>32-bit Data Bus |

*\*VDD and VSS pins are added separately, total used pins are 8 pins.*

---

## System Overview
**Owner:** Raegrand

### Block Functionality

| Block | Component | Core Function | Complexity | Critical Notes |
| :--- | :--- | :--- | :--- | :--- |
| `ascon_core` | Executes the Ascon-128 AEAD algorithm. Maintains 320-bit state, absorbs Key/Nonce/AD/Plaintext, performs permutations, generates Ciphertext & Tag. | High (320-bit Sequential FSM, Iterative Sponge Construction) | • Operates synchronously on high-speed system `clk`.<br>• Uses complex 18-state FSM.<br>• Multi-cycle permutations based on phase. |
| `spi_controller` | Command-driven protocol hub. Decodes 8-bit SPI commands (e.g., 0x10 for Key, 0x20 for Nonce), forms 32-bit words, manages handshaking. | Medium (Command Decoder FSM, Parallel-to-Serial Buffer) | • System orchestrator for 32-bit batching.<br>• Generates transaction boundary flags (`bdi_type`, `bdi_eot`, `bdi_eoi`). |
| `spi_slave` | Physical Layer. Handles raw serial bit-shifting. Deserializes `mosi` into 8-bit bytes and serializes outgoing bytes to `miso`. | Low-Medium (Dual-Clock Domain, CDC Synchronizer) | • Synchronized entirely to system `clk`.<br>• Directly clocked by external `sclk`.<br>• Multi-stage synchronizers for CDC.<br>• Drives `miso` on `negedge` of `sclk`. |

### Signal Flow

| Protocol Phase | Active Clock Domain | Cycle Budget | Key Pin & Bus Activity | Operational Purpose & Power Status |
| :--- | :--- | :--- | :--- | :--- |
| **1. Transaction Initiation** | Asynchronous | <1 clk | `spi_cs_n` pulled LOW (0) | Wakes interface FSM on next rising edge of `spi_sclk`. Core registers hold reset values. |
| **2. Key & Nonce Loading (Initialization)** | External Serial Clock (`posedge spi_sclk`) | Serial Cycles | Bit count reset, `spi_mosi` streams bits. Shift registers load Key/Nonce. | Streams 128-bit Key & Nonce. Core executes p[12] permutation to initialize 320-bit sponge. |
| **3. Associated Data (AD) Processing** | External Serial Clock (`posedge spi_sclk`) | Variable | AD absorbed in blocks. | AD blocks XORed into sponge state, followed by p[6] permutations. No ciphertext produced. |
| **4. Plaintext/Ciphertext Processing** | External Serial Clock (`posedge spi_sclk`) | Variable | PT streamed via MOSI, CT streamed via MISO. | Plaintext XORed into state, serialized out as Ciphertext. Each block followed by p[6] permutation. |
| **5. Finalization & Tag Generation** | External Serial Clock (`posedge spi_sclk`) | 12 internal + Serial read | `data_ready` asserted, `spi_miso` streams Tag. | Core executes final p[12] using Key. 128-bit Auth Tag shifted out for verification. |

### Power Domains
**Single Power Domain (1.8V)**
The custom Ascon AEAD-128 cryptographic ASIC operates entirely within a Single Power Domain at a nominal supply voltage of 1.8V (VDD / GND). To maintain design simplicity, minimize chip area, and allow packaging in a compact footprint, all internal sub-modules (`spi_slave`, `spi_controller`, and `ascon_core`) are connected to a unified 1.8V power rail.

The chip uses **Architectural State Freezing and FSM Power Management** instead of power-switch cells. The controller FSM remains in IDLE when the SPI bus is idle, preventing permutation rounds and freezing the 320-bit flip-flop array. This eliminates unnecessary flip-flop toggling, dropping active dynamic power to near zero.

### Clock Domains
**Dual-Clock Architecture**
*   **Serial Interface Domain (`sclk`):** External asynchronous domain driven by host MCU (10-20 MHz) for serial packet ingestion/readout.
*   **Main System Domain (`clk`):** High-speed internal domain (50-100 MHz) for primary FSM and multi-cycle execution of `ascon_core`.

**Clock Domain Crossing (CDC) & Synchronization:**
Incoming asynchronous signals (`sclk`, `cs_n`, `mosi`) pass through multi-bit shift register synchronizers (e.g., `sclk_sync[2:0]`) clocked by `clk`. Data is batched into parallel 8-bit registers before signaling `rx_valid` to the controller.

**Dynamic Frequency Scaling (DFS):**
Architecture supports DFS. Users can scale down the internal `clk` frequency to conserve power, provided it remains 3x-4x faster than `sclk` to satisfy the Nyquist sampling theorem.

---

## Schematic Summary
**Owner:** Ken

### Purpose
Physical integration between the SPI Slave communication interface (`spi_slave` & `spi_controller`), the post-processing buffer (`postprocessor_rup`), and the `ascon_core`. Provides a robust, area-efficient, and secure hardware accelerator for AEAD, fortified against Release of Unverified Plaintext (RUP) attacks.

### Inputs and Outputs
**Communication Protocol:** Command-driven SPI Slave interface (SPI Mode 0).

**Encryption Data Flow:**
1.  Master asserts `cs_n` LOW.
2.  Master transmits 8-bit command (e.g., 0x10 Key, 0x20 Nonce, 0x30 AD, 0x40 Message).
3.  `spi_controller` deserializes incoming payload on `mosi` into 32-bit parallel words and handles handshaking.
4.  `ascon_core` absorbs data into 320-bit sponge state, executing permutations synchronized to `clk`.
5.  During decryption, output data is held in a 64-word FIFO buffer (`postprocessor_rup`) which destroys plaintext if the Tag is invalid (prevents RUP leakage).
6.  For valid transactions, data is fetched via 0x60 command and shifted out serially via `miso`.

**Reset Condition:** Synchronous active-high reset (`rst`) clears all internal FSMs, shift registers, sponge state, and RUP FIFO pointers.

### Important Design Decisions
1.  **Command-Based SPI Protocol:** Handles variable-length AD and Plaintext without hardcoded packet limits (NIST standard compliant).
2.  **RUP Protection:** `postprocessor_rup` FIFO automatically flushes and destroys buffered plaintext if tag verification fails.
3.  **Decoupled Clock Domains:** SPI shifting operates on external `sclk` domain using multi-stage synchronizers; permutations run independently on high-speed `clk`.

### Interfaces to Other Blocks
*Internal modules communicate through a robust 32-bit valid-ready handshake bus:*
1.  `bdi[31:0]` & `bdo[31:0]`: 32-bit parallel data buses connecting SPI controller to Ascon Core.
2.  **Handshake Control:** `valid`, `ready`, `type`, `eot` (End of Turn), `eoi` (End of Input) ensure pipeline synchronization.
3.  `auth` & `auth_valid`: Core-to-controller signals asserting mathematical validity of the processed Tag.

### External Pin Function

| Name | Pin | Type | Direction | Description |
| :--- | :--- | :--- | :--- | :--- |
| VDD | 1 | Power | Input | Primary power supply voltage (e.g., 1.8V) |
| GND | 2 | Ground | Input | Common reference ground |
| clk | 3 | Clock | Input | External system clock driving FSM, RUP FIFO, core logic |
| rst | 4 | Reset | Input | Synchronous active-high reset |
| sclk | 5 | Clock | Input | Serial SPI clock provided by Master |
| mosi | 6 | Data | Input | Master Out Slave In |
| miso | 7 | Data | Output | Master In Slave Out |
| cs_n | 8 | Control | Input | Active-low Chip Select |

---

## Design Assumptions
**Owner:** Raegrand

| Parameters | Assumptions | Notes |
| :--- | :--- | :--- |
| **Supply voltages** | 1.8V (Typical) | Standard logic voltage for 130nm CMOS nodes. External LDO needed for 3.3V host. |
| **Temperature range** | 0°C to 85°C | Commercial grade standard operating temperature. |
| **Process corners** | SS, TT, FF (130nm CMOS) | Synthesis and STA verified across Slow-Slow, Typical, and Fast-Fast using SkyWater 130nm PDK. |
| **Expected loads** | 10 pF to 15 pF | Capacitive load on output pins (`miso`) from standard PCB trace and MCU receiver pin. |
| **External circuitry** | Host Microcontroller | Assumes external MCU sending SPI commands and performing voltage level shifting. |

---

## Verification Status
**Owner:** micel

- [ ] Functional simulations completed
- [ ] Corner simulations
- [ ] Monte Carlo (if applicable)
- [ ] ERC status
- [ ] LVS status
- [ ] DRC status (if layout exists)

*(Include links to simulation results here)*

---

## Design Checklist
**Owner:** micel

### Functionality
- [ ] Requirements implemented
- [ ] Reset behavior verified
- [ ] Startup verified
- [ ] Power sequencing considered

### Digital
- [ ] Timing reviewed
- [ ] State machine behavior verified
- [ ] Clock crossings identified
- [ ] Reset strategy documented

---

## Open Issues
*List unresolved items with:*
*   Description
*   Impact
*   Proposed solution
*   Owner

---

## Questions for Reviewers
*Explicitly request feedback on items such as:*
*   Architecture
*   Device sizing
*   Bias strategy
*   Reliability
*   Verification completeness
*   Manufacturability

---

## Review Outcome
*(To be filled)*

## Appendix
*(To be filled)*
