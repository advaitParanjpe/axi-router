# Verification Plan

## Current Verification

The repository currently has an Icarus-compatible directed SystemVerilog
testbench for the inherited 1x2 router. It checks fixed first-byte-LSB routing,
packet integrity, per-output backpressure, a forced FIFO-space drop, and
post-drop recovery.

A focused parameter regression also checks:

- default `DATA_W=32`
- non-8-bit data width: `DATA_W=16`
- `MAX_PKT_BEATS=1`
- `OUT_FIFO_DEPTH=1`
- exact-full or near-full output FIFO behavior
- oversize packet handling
- output backpressure
- reset from idle

`make test` runs the directed tests, parameter tests, Verilator RTL lint, and
Yosys parse/elaboration/check.

## Remaining Gaps

- No AXI4-Stream assertion library yet.
- No randomized traffic or randomized backpressure.
- No reset-during-packet testing.
- No reusable source/sink BFMs.
- No reference model beyond directed expectations.
- No functional coverage model.
- No UVM environment.
- No reproducible Vivado flow.

## Future Layers

- Directed SystemVerilog tests for the frozen 2x4 architecture.
- Assertions for handshake stability, no data loss, packet atomicity, routing,
  drop semantics, and reset behavior.
- Reusable AXI4-Stream source and sink BFMs.
- UVM agents, sequences, monitors, scoreboard, reference model, coverage, and
  regression control.
- Parameter sweeps and randomized backpressure regressions.
