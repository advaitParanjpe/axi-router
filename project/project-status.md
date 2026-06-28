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
- Milestone 7 added `scripts/setup-uvm.sh`, pinned by default to the CHIPS
  Alliance Verilator-compatible UVM source
  `https://github.com/chipsalliance/uvm-verilator.git` at ref
  `uvm-2017-1.1`, commit
  `02da9d0e20062f15fe75363bebcc31246422c2c2`, and replaced the blocked UVM
  runner with a Verilator compile/run script.
- The focused UVM smoke, directed, randomized, and forced-failure paths execute
  locally with Verilator 5.048.
- Milestone 8 added release-oriented checker and coverage strengthening,
  conventional and UVM 16-seed closure regression targets, a reproducible
  generic Yosys synthesis report, a source-controlled Mermaid architecture
  diagram, and current-facing README/results documentation.
- Verilator RTL lint passes for the active generalized design.
- Yosys parse/elaboration/check passes for the generalized `axis_pkt_router`
  top level.
- `make synth-report` generates detailed reports under `build/` and the
  concise tracked summary `docs/synthesis-summary.md`.
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
- The UVM environment executes locally in the focused Verilator flow, with
  generated build-local compatibility files for unused UVM RAL and HDL-backdoor
  DPI limitations.
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
Yosys 0.66. Milestone 6 initially found no installed `uvm_pkg.sv` or validated
UVM simulator flow. Existing conventional validation remains operational.

## Milestone 7 UVM Execution Status

Milestone 7 is complete for the active assignment. Implemented workflow
changes include:

- `scripts/setup-uvm.sh` creates an idempotent pinned dependency checkout under
  `build/deps/uvm`, verifies the expected UVM package and include files, and
  checks the exact pinned commit
  `02da9d0e20062f15fe75363bebcc31246422c2c2`.
- `scripts/run-uvm.sh` now invokes Verilator with the external UVM package,
  project RTL, UVM filelist, `+UVM_TESTNAME`, seed propagation, per-test build
  directories, and per-test logs under `build/`.
- The runner generates build-local compatibility files to omit unused UVM RAL
  and HDL-backdoor DPI sources by default in this Verilator 5.048 flow.
- The UVM random seed list now includes `1 7 23 101`.
- `make clean` preserves `build/deps`, recreates `build/tmp`, and `distclean`
  removes all generated outputs including external dependencies.

Validation on 2026-06-26 confirmed Verilator 5.048, conventional `make test`,
`make random`, `make regression`, `make lint`, and `make synth-check` pass.
UVM validation confirmed `make clean`, `scripts/setup-uvm.sh`,
`make uvm-smoke`, focused UVM directed tests, UVM random seeds `1 7 23 101`,
and `make uvm-failure-check` pass. Scoreboard summaries report zero pending
and zero unexpected packets in normal runs, and the forced UVM scoreboard error
path returns nonzero as expected.

## Immediate Next Objective

Final human review and public GitHub release are the recommended next steps.
Optional future work should stay separate from the completed baseline:
commercial simulator validation, fuller concurrent-SVA support, formal
verification, `tkeep`, virtual output queues, cut-through routing, arbitrary
port-count parameterization, and reproducible FPGA implementation.
