# Project Status

## Current Verified Baseline

- Executable RTL remains the 1-input, 2-output AXI4-Stream subset router.
- Supported baseline stream signals: `tdata`, `tvalid`, `tready`, and `tlast`.
- Baseline routing remains fixed first-byte-LSB routing: `0` to `m0`, `1` to
  `m1`.
- Baseline architecture remains store-and-forward packet capture with one
  synchronous FIFO per output.
- Reset is synchronous active-high.
- Existing directed regression passes.
- Parameter regression passes for default `DATA_W=32`, `DATA_W=16`,
  `MAX_PKT_BEATS=1`, and `OUT_FIFO_DEPTH=1`.
- Verilator RTL lint is clean for synthesizable RTL.
- Yosys parse/elaboration/check passes.
- Generated artifacts are placed under `build/`.

## Current Architectural Limitations

- No AXI4 memory-mapped or AXI4-Lite support.
- Current executable RTL does not support `tkeep`, `tstrb`, `tid`, `tdest`, or
  `tuser`.
- No partial final-beat representation.
- No multiple ingress ports in the current executable RTL.
- No arbitration in the current executable RTL.
- No configurable routing table.
- No UVM environment or assertion suite yet.
- No currently reproducible Vivado flow.

## Milestone 3 Specification Status

Milestone 3 freezes the architecture and externally observable behavior for the
planned generalized router. The 2-input, 4-output architecture is specified but
not yet implemented.

Major frozen decisions:

- The generalized design targets an AXI4-Stream subset, not AXI4 memory-mapped
  or AXI4-Lite.
- Supported generalized stream signals are `tdata`, `tvalid`, `tready`,
  `tlast`, and `tdest`.
- `tkeep`, `tstrb`, `tid`, and `tuser` are omitted from the first generalized
  implementation.
- The first generalized structural shape is fixed at 2 ingress ports and 4
  egress ports.
- `tdest` is sampled on the first accepted beat and values 0 through 3 map
  directly to outputs 0 through 3.
- Invalid destinations, oversize packets, and packets with changing `tdest` are
  consumed, dropped, and counted.
- The buffering model is one packet-capable ingress buffer per input, with no
  virtual output queues and no cut-through mode.
- Head-of-line blocking is an accepted tradeoff of the per-ingress buffering
  model.
- Each output has an independent round-robin arbiter.
- Output ownership is locked for a full packet and released only after the
  accepted `tlast` beat.
- Synchronous active-high reset aborts packet activity, clears buffers, releases
  locks, resets arbiters, and clears counters.
- Parameterization is limited to data width, destination width, ingress packet
  capacity, and counter width for the first generalized implementation.

## Immediate Next Objective

Implement the generalized 2-input, 4-output RTL and focused conventional
SystemVerilog tests for the frozen architecture. Do not begin the full UVM
environment until the generalized RTL and conventional verification baseline are
stable.
