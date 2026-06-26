# Development Plan

1. Baseline audit.
2. Baseline cleanup and stabilization.
3. Repository and Codex workflow setup.
4. Freeze the 2-input/4-output router architecture.
5. Implement the generalized 2-input/4-output RTL and focused conventional
   SystemVerilog tests.
6. Add directed verification depth and protocol assertions for the generalized
   router.
7. UVM environment foundation.
8. Constrained-random verification, functional coverage, and regressions.
9. Synthesis, performance analysis, and refinement.
10. Documentation, GitHub polish, and final release.

## Frozen Architecture Summary

Milestone 3 freezes the 2x4 router architecture but does not implement it. The
current executable RTL remains the inherited 1-input, 2-output AXI4-Stream
subset baseline.

The frozen generalized architecture uses `tdest` for packet routing, supports
`tdata`, `tvalid`, `tready`, `tlast`, and `tdest`, fixes the first generalized
structural shape at 2 ingress ports and 4 egress ports, uses one
packet-capable ingress buffer per input, forwards packets store-and-forward,
arbitrates independently per output with round-robin priority, and locks output
ownership for a full packet.

The next implementation milestone should build the generalized 2x4 RTL and a
focused conventional SystemVerilog test layer. Full UVM work remains deferred
until that RTL and conventional verification baseline are stable.

## Later Verification Considerations

After the 2x4 RTL exists, add reusable source/sink BFMs, randomized
backpressure, reset-during-packet testing, parameter sweeps,
handshake-stability assertions, no-data-loss checks, packet-atomicity checks,
and drop-semantics checks.

These are roadmap items, not Milestone 3 implementation work.
