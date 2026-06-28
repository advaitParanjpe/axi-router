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
8. Verification closure, synthesis results, and release polish.
9. Optional future refinement.
10. Optional final release follow-up.

## Implemented Architecture Summary

Milestone 3 froze the 2x4 router architecture. Milestone 4 implemented that
architecture as the active executable RTL.

The generalized architecture uses `tdest` for packet routing, supports
`tdata`, `tvalid`, `tready`, `tlast`, and `tdest`, fixes the first generalized
structural shape at 2 ingress ports and 4 egress ports, uses one
packet-capable ingress buffer per input, forwards packets store-and-forward,
arbitrates independently per output with round-robin priority, and locks output
ownership for a full packet.

The next verification milestone should strengthen the conventional
SystemVerilog test layer with reusable AXI-Stream interfaces/BFMs, protocol
assertions, and broader randomized regressions. Full UVM work remains deferred
until that conventional verification baseline is stronger.

## Milestone 8 Closure Summary

Milestone 8 completed a bounded release-polish pass without redesigning the
router. The project now has strengthened procedural protocol checks, broader
explicit scenario coverage gates in the conventional random bench, 16-seed
conventional and UVM closure targets, a reproducible generic Yosys synthesis
report flow, a source-controlled Mermaid architecture diagram, and updated
current-facing documentation.

Remaining optional future work is separate from the implemented baseline:
commercial simulator validation, fuller concurrent-SVA coverage where tool
support allows, formal verification, `tkeep`, virtual output queues,
cut-through routing, arbitrary port-count parameterization, and a reproducible
FPGA implementation flow.
