# Project Status

## Current Verified Baseline

- 1-input, 2-output AXI4-Stream subset router.
- Supported stream signals: `tdata`, `tvalid`, `tready`, and `tlast`.
- Fixed first-byte-LSB routing: `0` to `m0`, `1` to `m1`.
- Store-and-forward packet capture.
- Per-output synchronous FIFO buffering.
- Synchronous active-high reset.
- Existing directed regression passes.
- Parameter regression passes for default `DATA_W=32`, `DATA_W=16`,
  `MAX_PKT_BEATS=1`, and `OUT_FIFO_DEPTH=1`.
- Verilator RTL lint is clean for synthesizable RTL.
- Yosys parse/elaboration/check passes.
- Generated artifacts are placed under `build/`.

## Current Architectural Limitations

- No AXI4 memory-mapped or AXI4-Lite support.
- No `tkeep`, `tstrb`, `tid`, `tdest`, or `tuser`.
- No partial final-beat representation.
- No multiple ingress ports.
- No arbitration.
- No configurable routing table.
- No UVM environment or assertion suite yet.
- No currently reproducible Vivado flow.

## Intended Direction

The planned portfolio target is a 2-input, 4-output AXI4-Stream packet router
with destination-based routing, packet-level arbitration, backpressure,
SystemVerilog assertions, and UVM verification. That architecture is not yet
frozen.

## Latest Milestone State

Milestone 2 repository documentation, Git hygiene, and Codex workflow setup are
implemented. Validation should be rerun after any follow-up edits.
