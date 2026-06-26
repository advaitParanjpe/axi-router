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

`make test` runs the current directed tests, parameter tests, lint, and
synthesis sanity check. This is focused conventional verification, not UVM,
formal proof, or coverage closure.

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

## Future UVM Environment

The full UVM environment is deferred until after the generalized RTL and
conventional verification baseline are stable. Required components are expected
to include:

- Ingress agents with sequencer, driver, and monitor support.
- Egress agents or passive monitors with ready-driving capability.
- Packet transaction classes carrying payload beats, `tdest`, length, and
  expected drop classification.
- Directed and randomized sequences for routing, contention, backpressure,
  malformed packets, oversize packets, resets, and long randomized traffic.
- Environment configuration object for widths, packet limits, enabled agents,
  ready behavior, and randomization controls.
- Reference model that applies first-beat `tdest` routing, malformed detection,
  oversize detection, packet-level arbitration expectations, and reset effects.
- Scoreboard comparing observed egress packets and counters against the
  reference model.
- Functional coverage model.
- Assertion binding or integration plan.
- Virtual sequences coordinating both ingress ports and all egress ready
  drivers.
- Regression organization with smoke, directed, parameter, randomized, and
  seed-replay groups.

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

- No AXI4-Stream assertion library exists yet.
- No broad randomized traffic or randomized backpressure regression exists yet.
- No reusable source/sink BFMs exist yet.
- No reference model beyond current directed expectations exists yet.
- No functional coverage implementation exists yet.
- No UVM environment exists yet.
- No reproducible Vivado flow exists yet.
