# Verification Plan

## Current Verification

The repository currently has Icarus-compatible directed SystemVerilog
testbenches for the implemented generalized 2x4 router. They check legal
`tdest` routing from both ingresses to all four outputs, packet integrity,
packet boundaries, simultaneous ingress traffic, concurrent different-output
transmission, same-output contention, deterministic round-robin ordering,
output backpressure, invalid-destination drops, malformed changing-`tdest`
drops, oversize drops, exact-capacity packets, reset recovery, selected
parameter cases, Verilator RTL lint, and Yosys parse/elaboration/check.

Milestone 5 adds a reusable conventional, non-UVM verification layer:

- `tb/axis_stream_if.sv` defines the supported AXI4-Stream subset interface
  and source, sink, and monitor modports.
- `tb/tb_axis_pkt_router_random.sv` provides source and sink BFM tasks,
  deterministic randomized traffic, reset-aware backpressure, ingress and
  egress monitors, an independent packet-level reference model, a scoreboard,
  bounded round-robin fairness checks, counter checks, timeouts, and explicit
  coverage counters.
- `tb/axis_stream_protocol_checker.sv` provides procedural protocol and
  packet-atomicity checks compatible with the current Icarus flow.

`make test` runs the directed tests, parameter tests, lint, and synthesis
sanity check. `make random` runs the deterministic seed list `1 7 23 101`, and
`make random-seed SEED=<n>` reproduces one randomized run. This remains
conventional verification, not UVM, formal proof, or coverage closure.

Milestone 6 adds a standards-oriented UVM environment under `tb/uvm/`.
It includes packet-level sequence items, configuration, active ingress agents,
active egress ready/backpressure agents, monitors, a virtual sequencer,
directed and lightly randomized virtual sequences, a reference model,
scoreboard, explicit coverage component, and UVM tests for smoke, routing,
concurrency, contention, backpressure, drops, reset, and randomized traffic.

Milestone 7 added a reproducible dependency setup path for the CHIPS Alliance
Verilator-compatible UVM source at
`https://github.com/chipsalliance/uvm-verilator.git`, ref `uvm-2017-1.1`,
pinned to commit `02da9d0e20062f15fe75363bebcc31246422c2c2`, and a
Verilator-oriented UVM runner that compiles the external UVM package, project
RTL, interfaces, UVM package, and top-level testbench into per-test build
directories under `build/`.

Confirmed local execution on 2026-06-26: `make uvm-smoke`, focused UVM
directed tests, UVM random seeds `1 7 23 101`, and `make uvm-failure-check`
pass with Verilator 5.048. The runner uses build-local generated compatibility
files to exclude unused UVM RAL and HDL-backdoor DPI sources by default,
because those parts of the pinned UVM source do not compile cleanly in this
local Verilator flow and this project does not use UVM RAL or HDL backdoor
access.

## Generalized 2x4 Verification Scope

The next verification layer should deepen the implemented 2-input, 4-output
AXI4-Stream subset architecture with reusable conventional components,
assertions, and broader randomized regressions before starting the full UVM
environment.

Planned directed and randomized categories:

- Interface protocol behavior for `tdata`, `tvalid`, `tready`, `tlast`, and
  `tdest`.
- Packet integrity across all outputs, including data order and `tlast`
  placement.
- Destination routing for `tdest` values 0, 1, 2, and 3.
- Simultaneous independent transfers when the two ingress ports target
  different outputs.
- Same-output contention when both ingress ports request one output.
- Round-robin fairness across repeated same-output contention.
- Packet lock behavior and no interleaving on every output.
- Randomized output backpressure on one or more outputs.
- Ingress backpressure when packet buffers are occupied or capacity is reached.
- Invalid destinations greater than 3.
- Oversize packets beyond `INGRESS_MAX_PKT_BEATS`.
- Malformed packets where `tdest` changes after the first accepted beat.
- Reset while idle.
- Reset during packet capture.
- Reset during output transmission.
- Minimum and boundary parameter cases, including minimum packet capacity and
  non-default data widths.
- Counter correctness for accepted, forwarded, invalid-destination, oversize,
  and malformed packets.
- Sustained randomized traffic with mixed destinations, packet lengths,
  backpressure, contention, and drops.

## Assertion Goals

Assertions should be added with the generalized RTL or immediately after the
first conventional tests are passing. They should cover:

- Stable `m_axis_tdata`, `m_axis_tdest`, and `m_axis_tlast` while output
  `tvalid` is high and `tready` is low.
- Stable ingress capture assumptions or checks where required by the source
  handshake.
- No output transfer without valid stored packet data.
- At most one ingress owner per output.
- No packet interleaving on an output.
- Output ownership remains stable until the accepted `tlast` beat.
- A packet is forwarded to at most one output.
- Round-robin priority advances only after a packet completes.
- Invalid, malformed, and oversize packets are not forwarded.
- Reset clears valid state, locks, buffer occupancy, arbitration priority, and
  counters.

## UVM Environment

The Milestone 6 UVM environment is a first reusable implementation adapted from
the Milestone 5 conventional semantics. Milestone 7 compiles and runs it in
the local Verilator flow, but it is not a coverage-closed verification signoff
flow. Implemented components include:

- Ingress agents with sequencer, driver, and monitor support.
- Egress agents with ready/backpressure driving and passive packet monitors.
- Packet transaction classes carrying payload beats, `tdest`, length, and
  expected drop classification.
- Directed and randomized virtual sequences for routing, contention,
  backpressure, malformed packets, oversize packets, reset-oriented tests, and
  randomized traffic.
- Environment configuration object for widths, packet limits, enabled agents,
  ready behavior, randomization seed, scoreboard enable, and coverage enable.
- Reference model that classifies observed ingress packets using the documented
  drop precedence and predicts legal output packets.
- Scoreboard comparing observed egress packets with expected packets and
  reporting missing, unexpected, duplicated, corrupted, or misrouted traffic.
- Explicit coverage counters in a UVM component.
- Protocol checker integration in the UVM top level using the existing
  reusable procedural checker.
- Virtual sequences coordinating both ingress ports and all egress ready
  drivers.
- Regression organization with smoke, directed, random, and forced-failure
  Make targets.

## Coverage Goals

Coverage goals are planning targets only; no coverage closure is claimed.

High-level functional coverpoints:

- Destination value per ingress: 0, 1, 2, 3, and invalid.
- Packet length bins: single-beat, small multi-beat, maximum legal, and
  oversize.
- Ingress pair behavior: one active ingress, both active same output, both
  active different outputs.
- Per-output grant source and grant transitions.
- Round-robin alternation under repeated contention.
- Output backpressure length bins and stalled-output combinations.
- Reset scenario: idle, capture, locked output transfer.
- Drop reason: invalid destination, oversize, malformed destination change.
- Counter increment events by counter type.
- Boundary parameter configurations.

Cross coverage should include ingress versus destination, contention versus
round-robin winner, backpressure versus packet lock, and drop reason versus
packet length.

## Remaining Gaps Until Future Milestones

- No full AXI4-Stream assertion library exists yet; the current checker layer
  is procedural and focused on the supported subset.
- The randomized regression is deterministic and bounded, not exhaustive.
- The current BFMs, reference model, scoreboard, and explicit coverage bins are
  exercised by both conventional and focused UVM flows, but no coverage closure
  is claimed.
- The Verilator UVM flow does not claim support for unused UVM RAL or HDL
  backdoor DPI features.
- No reproducible Vivado flow exists yet.
