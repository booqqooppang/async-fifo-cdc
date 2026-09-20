# Verification Results

Simulation was performed using a self-checking SystemVerilog testbench with independent write and read clock domains.

| Test Case | Result |
|---|---|
| Reset initialization | PASS |
| Basic write and read | PASS |
| FIFO data ordering | PASS |
| Full condition | PASS |
| Empty condition | PASS |
| Write blocked while full | PASS |
| Read blocked while empty | PASS |
| Independent write/read clocks | PASS |
| Simultaneous read and write | PASS |


## How to Simulate

A complete testbench has not yet been uploaded.

The planned simulation environment is Questa/ModelSim. After adding `tb/tb_async_fifo3.sv`, the intended command sequence is:

```bash
vlib work
vlog rtl/async_fifo3.sv
vlog tb/tb_async_fifo3.sv
vsim -c tb_async_fifo3 -do "run -all; quit"
```

Example expected testbench configuration:

| Item | Example Setting |
|---|---|
| Write clock period | 10 ns |
| Read clock period | 14 ns |
| Write clock frequency | 100 MHz |
| Read clock frequency | approximately 71.4 MHz |
| Reset | Assert `rst_n = 0`, then release reset before transactions |
| Data check | Queue-based scoreboard |

Different clock frequencies and non-aligned clock phases should be used to exercise the asynchronous clock-domain-crossing behavior.

## Verification

### Current Status

| Verification Item | Status |
|---|---|
| RTL source upload | Complete |
| Manual RTL review | In progress |
| Directed simulation testbench | Planned |
| Self-checking scoreboard | Planned |
| Full-condition test | Planned |
| Empty-condition test | Planned |
| Simultaneous read/write test | Planned |
| Randomized test | Planned |
| SystemVerilog Assertions | Planned |
| CDC analysis | Planned |
| Reset-domain-crossing review | Planned |

### Planned Test Cases

- Reset both clock domains and confirm that the FIFO starts in the empty state.
- Write data while `full = 0` and verify that the write pointer advances.
- Read data while `empty = 0` and verify that the read pointer advances.
- Verify first-in, first-out data ordering with a queue-based scoreboard.
- Fill the FIFO to verify `full` assertion behavior.
- Attempt writes while `full = 1` and verify that no additional data is accepted.
- Drain the FIFO to verify `empty` assertion behavior.
- Attempt reads while `empty = 1` and verify that the read pointer does not advance.
- Apply different write/read clock periods and clock phases.
- Exercise simultaneous write and read activity.
- Assert and release reset during or around FIFO transactions.
- Add assertions to detect overflow and underflow attempts.
