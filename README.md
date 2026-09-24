# async-fifo-cdc
SystemVerilog asynchronous FIFO with Gray-code pointers, dual-clock CDC synchronization, and self-checking verification.

<br>

## Overview

This repository contains an asynchronous FIFO RTL implementation written in SystemVerilog.
The module is designed to transfer data between two independent clock domains:
- Write clock domain: `wr_clk`
- Read clock domain: `rd_clk`

Because the write and read clocks can run at different frequencies and phases, pointer information must cross the clock-domain boundary safely.
This implementation uses binary pointers for FIFO memory addressing, converts the pointers to Gray code for clock-domain crossing, and synchronizes each Gray-code pointer with a two-flop synchronizer in the destination clock domain.

<br>

## Block Diagram

![Asynchronous FIFO Block Diagram](docs/Async_FIFO%20block%20diagram.png)

<br>

## Features

| Item | Spec |
|---|---|
| RTL language | SystemVerilog |
| Module name | `async_fifo` |
| FIFO type | Asynchronous FIFO |
| Default data width | Parameterized data width |
| Default FIFO depth | Parameterized FIFO depth |
| Memory addressing | Binary pointers |
| CDC pointer transfer | Gray-code pointers |
| CDC synchronizer | Two flip-flop synchronizer |
| Write protection | Write operation is blocked when `full = 1` |
| Read protection | Read operation is blocked when `empty = 1` |
| Reset input | Active-low reset, `rst_n` |
| Read-data style | Show-ahead / FWFT combinational read path |

<br>

### Module Parameters

| Parameter | Default | Description |
|---|---:|---|
| `WIDTH` | 8 | FIFO data width in bits |
| `DEPTH` | 16 | FIFO depth. Must be a power of two |

#### Design Constraints

- `DEPTH` must be a power of two.
- The default configuration is `WIDTH = 8` and `DEPTH = 16`.

<br>

### Interface

| Signal | Direction | Clock Domain | Description |
|---|---|---|---|
| `rst_n`    | Input  | Both | Active-low reset |
| `wr_clk`   | Input  | Write | Write clock |
| `wr_en`    | Input  | Write | Write enable |
| `wr_data`  | Input  | Write | Write data |
| `full`     | Output | Write | FIFO full status |
| `rd_clk`   | Input  | Read | Read clock |
| `rd_en`    | Input  | Read | Read enable |
| `rd_data`  | Output | Read | Read data |
| `empty`    | Output | Read | FIFO empty status |

#### Read Interface

This FIFO uses a show-ahead / FWFT read interface.
- `rd_data` is valid when `empty = 0` and invalid when `empty = 1`.
- `rd_en` consumes the current entry and advances the read pointer on the next `rd_clk` edge.

<br>

## Directory Structure

```text
.
├── LICENSE
├── README.md
├── rtl/
│   └── async_fifo.sv
├── tb/
│   └── tb_async_fifo.sv
└── docs/
    ├── Async_FIFO block diagram.png
    ├── verification_results.md
    └── waveform/
        ├── full_empty_boundary.png
        └── cdc_sync.png
```

<br>

## How to Simulate

Example simulation flow using Questa/ModelSim:

```bash
vlib work
vlog rtl/async_fifo.sv
vlog tb/tb_async_fifo.sv
vsim -c tb_async_fifo -do "run -all; quit"
```

<br>

## Verification

The design is verified with a directed, self-checking testbench using a queue-based scoreboard. Test scenarios cover full/empty boundary conditions, simultaneous read/write, non-aligned clock phases, and reset assertion during transactions.

![CDC synchronization waveform](docs/waveform/cdc_sync.png)

See [verification_results.md](docs/verification_results.md) for full test cases and results.

<br>

## Synthesis Results

The design was synthesized successfully using Intel Quartus Prime Pro Edition.
| Item | Result |
|---|---|
| Tool | Intel Quartus Prime Pro Edition 18.0.0 Build 219 |
| Target family | Cyclone 10 GX |
| Target device | 10CX220YF780I5G |
| Top-level entity | async_fifo |
| Compilation status | Successful |
| Logic utilization | 29 / 80,330 ALMs (< 1%) |
| Register utilization | 53 registers |
| Block memory utilization | 128 / 12,021,760 bits (< 1%) |
| `wr_clk` Fmax | 466.2MHz |
| `rd_clk` Fmax | 568.5MHz |
| Setup timing (`wr_clk`) | Passed, worst-case slack: 7.855 ns |
| Setup timing (`rd_clk`) | Passed, worst-case slack: 12.241 ns |
| Hold timing (`wr_clk`) | Passed, worst-case slack: 0.071 ns |
| Hold timing (`rd_clk`) | Passed, worst-case slack: 0.057 ns |

The wr_clk and rd_clk domains are constrained as asynchronous clock groups in the SDC file.

<br>

## Design Decisions

### Binary and Gray-code pointers

The FIFO maintains both binary and Gray-code pointers in each clock domain.

- Binary pointers are used for indexing the FIFO memory.
- Gray-code pointers are used when pointer values cross between clock domains.
- A Gray-code pointer changes only one bit between adjacent count values, reducing the risk of sampling multiple changing bits during asynchronous transfer.

### Two-flop synchronizers

Each Gray-code pointer is transferred into the opposite clock domain through a two-stage flip-flop synchronizer.

- The write clock domain synchronizes the read Gray-code pointer.
- The read clock domain synchronizes the write Gray-code pointer.
- The synchronizers reduce the probability that metastability propagates into local control logic.

### Pointer width

The pointers use one additional bit beyond the memory address width.

```text
Address width = $clog2(DEPTH)
Pointer width = $clog2(DEPTH) + 1
```

The pointers include one additional bit beyond the memory address width to distinguish pointer wrap-around from a simple address match. In binary-pointer terms, matching address bits with the same wrap state indicate an empty FIFO, while matching address bits with the write pointer one wrap ahead indicate a full FIFO.

For Gray-code full detection, the write pointer is compared with the synchronized read pointer after inverting the two most-significant Gray-code bits. This is the Gray-code equivalent of detecting that the write pointer has advanced by one complete FIFO depth relative to the read pointer.

### Status flags

- `empty` is generated in the read clock domain by comparing the read pointer with the synchronized write pointer.
- `full` is generated in the write clock domain by comparing the write pointer with the synchronized read pointer.
- Comparisons use the synchronized (not raw) pointer values, since the raw pointer from the opposite clock domain has not passed through the two-flop synchronizer and could otherwise propagate metastability into the flag-generation logic.
- Write operations occur only when `wr_en && !full`.
- Read pointer updates occur only when `rd_en && !empty`.

### Reset strategy

The design uses a common active-low reset input, `rst_n`.

Reset assertion is asynchronous through sensitivity to the active-low reset. Reset release is locally synchronized in the write and read clock domains through `wr_rst_sync1/wr_rst_sync2` and `rd_rst_sync1/rd_rst_sync2`. Synchronizing the reset release separately in each domain avoids reset recovery/removal timing violations that could otherwise occur if a shared reset signal were released asynchronously relative to each domain's local clock.

<br>

## Limitations & Future Work

### Current Limitations

- No SystemVerilog Assertions (SVA) are currently included.
- No formal verification has been performed.
- No static CDC lint analysis (e.g., SpyGlass CDC or Questa CDC) has been performed.
- No functional or code coverage results are currently collected.
- The `DEPTH` parameter must be a power of two; non-power-of-two values are not supported.
- Quartus synchronizer identification and metastability optimization settings have not yet been reviewed.

### Future Work

- Review CDC synchronizer recognition and metastability-related settings in Quartus, and verify the Gray-pointer synchronizer chains and reset-domain-crossing timing in the TimeQuest Timing Analyzer.
- Optionally extend the directed testbench with randomized read/write enable patterns and varied clock ratios.
- Consider a dedicated CDC lint tool (e.g., SpyGlass CDC, Questa CDC) for a more rigorous static CDC verification pass, if access becomes available.
