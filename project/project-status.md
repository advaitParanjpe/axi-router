# Project Status

## Current Verified Baseline

- Active synthesizable RTL is the fixed 2-input, 4-output AXI4-Stream subset
  packet router in `rtl/axis_pkt_router.sv`.
- Supported stream signals are `tdata`, `tvalid`, `tready`, `tlast`, and
  `tdest`.
- Legal first-beat `tdest` values 0 through 3 route directly to outputs 0
  through 3.
- The implementation uses one store-and-forward packet buffer per ingress and
  one independent round-robin arbiter per output.
- Output ownership is locked for a full packet and released on the accepted
  `tlast` beat.
- Invalid-destination, oversize, and malformed changing-`tdest` packets are
  consumed, dropped, and counted once per packet.
- Synchronous active-high reset clears ingress buffers, output locks,
  arbitration priority, and counters.
- Focused conventional SystemVerilog directed and parameter regressions pass.
- Verilator RTL lint passes for the active generalized design.
- Yosys parse/elaboration/check passes for the generalized `axis_pkt_router`
  top level.
- Generated artifacts are placed under `build/`.

## Retired Inherited Baseline

- The inherited 1-input, 2-output first-byte-LSB router is no longer the active
  design.
- The inherited synchronous FIFO source remains in `rtl/axis_fifo_sync.sv` as
  retired, unused RTL. It is not included in `filelists/rtl.f` and is not part
  of lint or synthesis targets.

## Current Architectural Limitations

- No AXI4 memory-mapped or AXI4-Lite support.
- No `tkeep`, `tstrb`, `tid`, or `tuser` support.
- No partial final-beat representation.
- Structural shape is intentionally fixed at 2 ingress ports and 4 egress
  ports.
- No virtual output queues and no cut-through forwarding.
- Head-of-line blocking remains an accepted consequence of one packet buffer
  per ingress.
- No configurable routing table.
- No full assertion library yet.
- No reusable AXI-Stream interfaces or BFMs yet.
- No UVM environment or functional coverage implementation yet.
- No formal proof.
- No currently reproducible Vivado flow.

## Milestone 4 Specification Status

Milestone 4 implemented the frozen generalized 2x4 architecture with focused
conventional verification. The implementation follows the frozen decisions for
`tdest` routing, per-ingress buffering, store-and-forward forwarding,
independent per-output round-robin arbitration, packet-level output locking,
drop handling, reset behavior, and limited parameterization.

Drop precedence in the implemented ingress buffer is first detected reason:
invalid first-beat destination takes precedence for the packet; otherwise a
changing `tdest` detected before oversize is counted as malformed; otherwise an
oversize packet is counted as oversize. A packet is counted in only one drop
category.

## Immediate Next Objective

Strengthen conventional verification with reusable AXI-Stream interfaces/BFMs,
protocol assertions, and broader randomized regressions before building the
full UVM environment.
