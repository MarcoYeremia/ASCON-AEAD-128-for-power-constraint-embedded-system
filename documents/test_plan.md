# Test Plan — Track A Digital ASIC (Team A68 elka1)

**Team A68 (elka1) · IEEE SSCS Chipathon 2026 · GF180MCU (gf180mcuD)**
Drafted 2026-11-04. **DRAFT — every value marked `TODO` has no source in the provided files and must be filled in before the bench session; nothing here is invented.** Every number that is given is a pre-silicon simulation, synthesis, or post-PnR STA result, cited by file path. None of it is a measurement of silicon.

---

## 1. Scope

This is a **digital functional, security, and power characterization** plan for the die described in `info.yaml` (`project.title`): *"ASCON-AEAD128 for Power-Constrained Embedded System"* (Issue #139, top module `ascon_top`).

- Complete end-to-end AEAD-128 encryption and decryption are tested through the 4-wire SPI slave interface (`cs_n`, `sclk`, `mosi`, `miso`).
- Internal sub-blocks (`spi_slave`, `spi_controller`, `ascon_core`, `asconp`, and `postprocessor_rup`) have no dedicated analog or debug test pads; all internal states are stimulated and observed digitally via SPI transactions and `VDD` supply current.
- Release of Unverified Plaintext (RUP) protection (`postprocessor_rup`) is verified at the system level by injecting corrupted ciphertext/tag vectors and verifying that unverified plaintext is never shifted out on `miso`.
- Power consumption is measured across static (clock gated/halted) and active (continuous permutation) regimes to evaluate the power-constrained design target against post-PnR STA estimates.

## 2. Pin map

Exact names and types from `info.yaml` `pins:` (8 pads, in file order). The **package pin / bond map is TBD pending organizer packaging decision**.

| # | Pin (`info.yaml`) | `io_type` | Function | Package pin |
|---|---|---|---|---|
| 1 | `VSS` | ground | Digital ground (connects to DVSS) | TBD pending organizer packaging decision |
| 2 | `clk` | input_schmitt | System clock input for `ascon_core` and controllers (hysteresis enabled) | TBD pending organizer packaging decision |
| 3 | `rst` | input_cmos | Digital system reset (polarity: `TODO` check RTL active-high vs active-low) | TBD pending organizer packaging decision |
| 4 | `cs_n` | input_cmos | SPI Chip Select (active low) | TBD pending organizer packaging decision |
| 5 | `sclk` | input_schmitt | SPI Serial Clock input from master (hysteresis enabled) | TBD pending organizer packaging decision |
| 6 | `mosi` | input_cmos | SPI Master Out Slave In data input | TBD pending organizer packaging decision |
| 7 | `miso` | bidirectional | SPI Master In Slave Out data output (configured as output during readback) | TBD pending organizer packaging decision |
| 8 | `VDD` | power | Digital 5.0 V supply rail (connects to DVDD) | TBD pending organizer packaging decision |

Not available at any pad: internal state registers of `asconp`, handshake flags between `spi_controller` and `ascon_core`, and internal tag-comparison match signals inside `postprocessor_rup`.

**Physical and DRC/LVS status** (from `runs/RUN_2026-08-21_17-20-50/metrics.json`):
- Die area: $916.89\text{ }\mu\text{m} \times 934.81\text{ }\mu\text{m}$ ($857,118\text{ }\mu\text{m}^2$); Core area: $814,397\text{ }\mu\text{m}^2$ ($70.41\%$ stdcell utilization; $24,122$ stdcells).
- Signoff checks: $0$ Magic DRC errors, $0$ LVS errors, $0$ antenna violations ($8$ antenna diodes inserted), $0$ power grid violations.

## 3. Supply and operating conditions

| Quantity | Value | Source |
|---|---|---|
| `VDD` nominal | $5.0\text{ V}$ | `runs/RUN_2026-08-21_17-20-50/metrics.json` (corner `nom_tt_025C_5v00`) |
| `VDD` operating range (corners) | $4.5\text{ V}$ (SS, $125\text{ }^\circ\text{C}$) to $5.5\text{ V}$ (FF, $-40\text{ }^\circ\text{C}$) | `runs/RUN_2026-08-21_17-20-50/metrics.json` |
| `VDD` current limit (bench safety) | **$100\text{ mA}$** (`TODO` confirm team decision, $\approx 2\times$ simulated active current) | Derived from STA `power__total` |
| Simulated total power (STA) | **$236.36\text{ mW}$** ($0.236357\text{ W}$) at TT / $5.0\text{ V}$ / $25\text{ }^\circ\text{C}$ (Internal: $180.72\text{ mW}$, Switching: $55.63\text{ mW}$) | `runs/RUN_2026-08-21_17-20-50/metrics.json` |
| Simulated active current ($I_{\text{DD,active}}$) | **$47.27\text{ mA}$** at $\text{VDD} = 5.0\text{ V}$ (derived from $236.36\text{ mW} / 5.0\text{ V}$ at STA clock frequency) | `runs/RUN_2026-08-21_17-20-50/metrics.json` |
| Simulated leakage power / current | **$5.47\text{ }\mu\text{W}$** ($5.4726 \times 10^{-6}\text{ W}$), or **$1.09\text{ }\mu\text{A}$** at $\text{VDD} = 5.0\text{ V}$ | `runs/RUN_2026-08-21_17-20-50/metrics.json` |
| Simulated IR drop on `VDD` / `VSS` | Worst `VDD` drop: $1.02\text{ mV}$ (avg $0.27\text{ mV}$); Worst `VSS` bounce: $1.06\text{ mV}$ (avg $0.26\text{ mV}$) | `runs/RUN_2026-08-21_17-20-50/metrics.json` |
| System clock (`clk`) frequency | Nominal target: `TODO` MHz (from `51-openroad-fillinsertion/ascon_top.sdc`). Note: setup slack is $+4.87\text{ ns}$ (`nom_tt_025C_5v00`) and $-8.58\text{ ns}$ (`max_ss_125C_4v50`) | `runs/RUN_2026-08-21_17-20-50/metrics.json` |
| SPI clock (`sclk`) frequency | Nominal bench test: $1\text{ MHz}$ to `TODO` MHz (must satisfy synchronizer ratio against `clk`: `TODO`) | RTL `spi_slave` / `spi_controller` |
| Logic input levels (`clk`, `rst`, `cs_n`, `sclk`, `mosi`) | $V_{\text{IL}} = 0\text{ V}$, $V_{\text{IH}} = \text{VDD}$ ($5.0\text{ V}$ CMOS levels) | `info.yaml` |
| Power-up sequencing | **(1) Ground (`VSS`); (2) `VDD` = $5.0\text{ V}$ with current limit; (3) Assert `rst` and hold `cs_n` = $5.0\text{ V}$ (inactive); (4) Start `clk`; (5) De-assert `rst` after $\ge 10$ `clk` cycles; (6) Begin SPI transactions.** Power down in reverse. | Standard digital bring-up |

## 4. Required equipment

The exact make, model, and firmware/settings used during the bench session will be recorded per test in `results/`.

- **Microcontroller or FPGA board** acting as SPI Master and programmable clock/reset generator (with $5.0\text{ V}$ level translation if native I/O is $3.3\text{ V}$).
- **Logic Analyzer or Digital Storage Oscilloscope** (minimum 4 digital channels + 1 clock channel, sampling rate $\ge 100\text{ MSa/s}$) to capture `cs_n`, `sclk`, `mosi`, `miso`, and `clk` timing.
- **Source Measure Unit (SMU) or precision DC power supply + 6.5-digit Digital Multimeter (DMM)** on `VDD` to force $4.5\text{ V} - 5.5\text{ V}$ and measure static ($\mu\text{A}$ range) and dynamic ($\text{mA}$ range) supply currents.
- **Host PC** running automated test script (Python/C) to stream NIST LWC Known Answer Test vectors from `tb/LWC_AEAD_KAT_128_128.txt` and log responses.
- **Test PCB / socket** with local decoupling capacitors ($100\text{ nF} + 10\text{ }\mu\text{F}$ close to `VDD`/`VSS` pins): TBD pending organizer packaging decision.

## 5. Verification tests and success criteria

Every test is structured around verifiable pass/fail criteria (Goal-Driven Execution).

### 5.1 DC power & leakage characterization

**Goal:** Verify absence of power-rail shorts, measure static leakage current, and characterize active dynamic power as a function of `clk` frequency.

**Procedure:**
1. Power up per §3 with `clk` held low ($0\text{ V}$), `sclk` = $0\text{ V}$, `cs_n` = $5.0\text{ V}$, and `rst` asserted. Measure static supply current $I_{\text{DD,leak}}$ across $\text{VDD} = 4.5\text{ V}, 5.0\text{ V}, \text{ and } 5.5\text{ V}$.
2. Enable `clk` and sweep frequency from $1\text{ MHz}$ up to the target SDC frequency (`TODO` MHz) while keeping SPI idle (`cs_n` = $5.0\text{ V}$). Record $I_{\text{DD,idle}}(f)$.
3. Run continuous back-to-back ASCON-128 encryption blocks via SPI at each clock step and record average active supply current $I_{\text{DD,active}}(f)$.

**Expected:**
- $I_{\text{DD,leak}}$ (core): $\approx 1.09\text{ }\mu\text{A}$ ($5.47\text{ }\mu\text{W}$ at $5.0\text{ V}$, TT) plus pad-frame static current (`TODO` $\mu\text{A}$).
- $I_{\text{DD,active}}$ at STA clock frequency (TT, $5.0\text{ V}$): $\approx 47.27\text{ mA}$ ($236.36\text{ mW}$). Linear scaling of dynamic current with `clk` frequency ($I_{\text{dyn}} = C_{\text{eff}} \cdot \text{VDD} \cdot f$).

**Pass/fail limits:**
- **No supply short on bring-up; $I_{\text{DD,leak}}$ within expected pad + core leakage bounds** (`TODO` set upper limit, e.g., $< 100\text{ }\mu\text{A}$ including I/O pads).
- **Dynamic current scales monotonically and linearly with `clk` frequency; active current at nominal frequency within $\pm 30\%$ of STA simulation** (or lower if STA switching activity factor was conservative).

### 5.2 SPI interface & register read/write sanity check

**Goal:** Verify SPI slave physical layer (`sclk` Schmitt input, `mosi` sampling, `miso` bidirectional pad enable, `cs_n` framing) before executing cryptographic permutations.

**Procedure:**
1. Set $\text{VDD} = 5.0\text{ V}$ and `clk` = $10\text{ MHz}$ (safe margin above any SS setup violation).
2. Drive SPI at `sclk` = $1\text{ MHz}$ (SPI Mode: `TODO` specify CPOL/CPHA from `spi_slave` RTL).
3. Issue a status read or register loopback/echo command (`TODO` specify command byte from `spi_controller` RTL) and observe `miso` on the Logic Analyzer.
4. Verify that `miso` remains tri-stated (high-Z) when `cs_n` = $5.0\text{ V}$ and drives valid CMOS levels when `cs_n` = $0\text{ V}$ during read phases.

**Pass/fail limits:**
- **Zero bit errors over $1,000$ consecutive SPI command/readback frames at `sclk` = $1\text{ MHz}$.**
- **Clean `miso` enable/disable transitions aligned with `cs_n` and command phase without bus contention.**

### 5.3 ASCON-AEAD128 Known Answer Tests (KAT) — Encryption & Valid Decryption

**Goal:** Verify bit-exact cryptographic compliance of `ascon_core` and `asconp` against the committed NIST LWC test vectors (`tb/LWC_AEAD_KAT_128_128.txt`).

**Procedure:**
1. Using the MCU/FPGA SPI master, load a 128-bit Key, 128-bit Nonce, Associated Data (AD), and Plaintext (PT) from `tb/LWC_AEAD_KAT_128_128.txt` into `ascon_top`.
2. Trigger encryption, wait the required permutation cycles (`TODO` cycles, or poll status flag via SPI), and read back Ciphertext (CT) and the 128-bit Authentication Tag (T) over `miso`.
3. Load the same Key, Nonce, AD, and the generated CT + Tag into `ascon_top` in Decryption mode.
4. Read back the decrypted Plaintext ($\text{PT}_{\text{out}}$) and verification status.
5. Repeat across all test vectors in `tb/LWC_AEAD_KAT_128_128.txt` (covering empty PT, empty AD, partial blocks, and multi-block payloads).

**Pass/fail limits:**
- **$100\%$ bit-exact match between measured (CT, Tag) and golden vectors in `tb/LWC_AEAD_KAT_128_128.txt` for all encryption runs.**
- **$100\%$ bit-exact recovery of $\text{PT}_{\text{out}} = \text{PT}$ and valid authentication status for all unmodified decryption vectors.**

### 5.4 Release of Unverified Plaintext (RUP) security verification

**Goal:** Verify that `postprocessor_rup` blocks plaintext output whenever tag verification fails during decryption.

**Procedure:**
1. Select a valid decryption vector (Key, Nonce, AD, CT, Tag) from `tb/LWC_AEAD_KAT_128_128.txt`.
2. Flip 1 bit in the input Tag (tampered tag), run Decryption via SPI, and capture all bytes shifted out on `miso`.
3. Repeat with 1 bit flipped in the Ciphertext (tampered CT), and with 1 bit flipped in the Associated Data (tampered AD).
4. Test across $100$ randomized single-bit and multi-bit fault injections.

**Expected** (from `postprocessor_rup` RTL):
- Authentication failure is flagged, and the output buffer returns all-zeros (or remains gated/blocked: `TODO` confirm exact RUP zeroing behavior in `postprocessor_rup.v`) instead of releasing the decrypted plaintext bytes.

**Pass/fail limits:**
- **Zero plaintext leakage: in $100\%$ of tampered-tag, tampered-CT, and tampered-AD decryption tests, `miso` must never output the underlying unverified plaintext bytes.**

### 5.5 Maximum clock frequency & voltage corner shmoo (Timing characterization)

**Goal:** Determine the maximum operating `clk` frequency of silicon across $\text{VDD} = 4.5\text{ V}, 5.0\text{ V}, \text{ and } 5.5\text{ V}$, and evaluate the impact of the post-PnR SS setup violation.

**Background from STA** (`runs/RUN_2026-08-21_17-20-50/metrics.json`):
- At `nom_tt_025C_5v00`: Setup WNS = $0.0\text{ ns}$ (worst setup slack = $+4.872\text{ ns}$), Hold WNS = $0.0\text{ ns}$ (worst hold slack = $+0.507\text{ ns}$), $0$ violations.
- At `nom_ss_125C_4v50`: Setup WNS = $-7.030\text{ ns}$ ($2,441$ setup violations), Hold WNS = $0.0\text{ ns}$ (worst hold slack = $+0.139\text{ ns}$).
- At `max_ss_125C_4v50`: Setup WNS = $-8.581\text{ ns}$ ($2,442$ setup violations), Hold WNS = $0.0\text{ ns}$ (worst hold slack = $+0.00018\text{ ns}$).
- At `nom_ff_n40C_5v50`: Setup WNS = $0.0\text{ ns}$ (worst setup slack = $+10.232\text{ ns}$), Hold WNS = $0.0\text{ ns}$ (worst hold slack = $+0.220\text{ ns}$), $0$ violations.

**Procedure:**
1. Set $\text{VDD} = 4.5\text{ V}, 5.0\text{ V}, \text{ and } 5.5\text{ V}$ at room temperature.
2. At each voltage, sweep `clk` frequency upward from $1\text{ MHz}$ in $1\text{ MHz}$ steps while running a golden KAT encryption/decryption loop.
3. Record the maximum `clk` frequency ($f_{\text{max}}$) at which $100$ consecutive KAT vectors pass with zero bit errors.

**Pass/fail limits:**
- **Silicon passes all KAT vectors at the nominal clock frequency at $\text{VDD} = 5.0\text{ V}$** (where TT setup slack is $+4.872\text{ ns}$).
- **If setup failures occur at $4.5\text{ V}$ at nominal frequency (as predicted by the $-7.03\text{ ns}$ SS slack), the chip must pass when `clk` period is relaxed by $\ge 9\text{ ns}$.**

## 6. Results publishing

Matching the Chipathon testing commitment: the fabricated chip will be tested by Team A68 (elka1) and the measurement results published in this repository.

**Location and format:** a top-level **`results/`** directory. Each test (5.1 to 5.5) gets a **Markdown summary** and **raw data as CSV** (power sweeps, shmoo tables, and KAT pass/fail logs). Each summary records the **date**, **die sample number**, **ambient temperature**, and **exact equipment used** (make, model, settings).

## 7. Known pre-silicon gaps that limit these targets

From `runs/RUN_2026-08-21_17-20-50/metrics.json` and repo status:
- **Setup timing violations in the slow corner (SS, $125\text{ }^\circ\text{C}$, $4.5\text{ V}$):** WNS is $-7.03\text{ ns}$ (nom RC) to $-8.58\text{ ns}$ (max RC) across $2,442$ endpoints, which limits maximum `clk` frequency at low supply voltage or high temperature.
- **Max slew and max capacitance violations:** $6$ `max_slew` and $296$ `max_cap` violations at `nom_tt_025C_5v00` (rising to $551$ slew and $441$ cap violations at `max_ss_125C_4v50`).
- **Unannotated nets:** $492$ unannotated nets reported in STA (`timing__unannotated_net_filtered__count` = $0$).
- **XOR difference:** `design__xor_difference__count` = $3$ between Magic and KLayout streamout (`magic__drc_error__count` = $0$, LVS errors = $0$).

## 8. Values to fill in from RTL / SDC before bench bring-up (`TODO` checklist)

1. Target `clk` period / frequency from `51-openroad-fillinsertion/ascon_top.sdc`.
2. Active polarity of `rst` (active-high vs active-low) from `ascon_top.v`.
3. SPI mode (CPOL, CPHA), maximum `sclk`-to-`clk` ratio, and byte-level command/address framing from `spi_slave.v` and `spi_controller.v`.
4. Exact number of `clk` cycles per initialization, associated data, plaintext/ciphertext block, and finalization in `ascon_core.v`.
