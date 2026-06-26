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
- A reusable non-UVM conventional verification layer now provides AXI-Stream
  subset interfaces, source/sink BFM tasks, monitors, an independent
  packet-level reference model, scoreboard checks, procedural protocol
  checkers, deterministic randomized regression, bounded fairness checks, and
  explicit coverage counters.
- A standards-oriented UVM source tree now exists under `tb/uvm/` with packet
  transactions, configuration, ingress and egress agents, virtual sequencer,
  virtual sequences, reference model, scoreboard, coverage component, focused
  tests, and a UVM top-level testbench.
- UVM execution is currently blocked in this local environment because no
  installed `uvm_pkg.sv` or validated UVM-capable simulator flow was found.
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
- No full assertion library yet; current protocol checks are procedural and
  scoped to the implemented subset.
- The UVM environment has not yet been executed with a UVM-capable simulator in
  this repository state.
- Current coverage is explicit scenario-bin counting in the conventional
  testbench and UVM coverage component counters, not coverage closure.
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

## Milestone 5 Verification Status

Milestone 5 strengthened the conventional verification baseline without
changing synthesizable RTL. The default randomized seed list is `1 7 23 101`.
`make random-seed SEED=<value>` reproduces one run, `make random` runs the
seed list, and `make failure-check` validates that an intentionally forced
scoreboard failure exits nonzero. The random regression checks routing,
packet integrity, drops, resets, stalls, bounded fairness, counter behavior,
and explicit coverage bins using only public DUT interface handshakes as the
correctness oracle.

## Milestone 6 UVM Environment Status

Milestone 6 added a reusable UVM architecture without changing synthesizable
RTL. The environment adapts the Milestone 5 conventional verification semantics
into packet sequence items, active ingress drivers, active egress ready
drivers, public-interface monitors, a reference model, scoreboard, coverage
component, virtual sequencer, focused virtual sequences, and smoke/routing/
concurrency/contention/backpressure/drop/reset/random tests.

Local tool assessment confirmed Icarus Verilog 13.0, Verilator 5.048, and
Yosys 0.66. No installed `uvm_pkg.sv` or validated UVM simulator flow was
found, so the UVM Make targets explicitly report the blocker and return
nonzero. Existing conventional validation remains operational.

## Immediate Next Objective

Install or select a UVM-capable simulator/library, execute and debug the UVM
tests, then expand UVM constrained-random depth, coverage measurement,
assertions, and regression automation toward verification closure.
