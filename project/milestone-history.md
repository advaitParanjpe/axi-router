# Milestone History

## Milestone 0 - Inherited-Repository Audit

Outcome: Established the baseline facts for the inherited project. Confirmed it
was a 1-input, 2-output AXI4-Stream subset router with fixed first-byte-LSB
routing, store-and-forward buffering, per-output FIFOs, directed tests, and
historical synthesis artifacts.

## Milestone 1 - Baseline Cleanup and Stabilization

Outcome: Added root build commands, filelists, `.gitignore`, optional waveform
generation, parameter-focused directed tests, Verilator-clean RTL, and Yosys
parse/elaboration/check compatibility while preserving externally visible 1x2
router behavior.

## Milestone 2 - Repository, Documentation, Git, and Codex Workflow Setup

Outcome: Added permanent project context documents, stable Codex instructions,
project status tracking, milestone history, Git hygiene, and repository helper
scripts. No meaningful RTL or verification-feature changes were made.

## Milestone 3 - Freeze the 2x4 AXI4-Stream Router Architecture

Outcome: Froze the planned generalized 2-input, 4-output AXI4-Stream subset
architecture in documentation. The specification defines `tdest` routing,
per-ingress packet buffering, store-and-forward forwarding, independent
per-output round-robin arbitration, packet-level output locking, invalid and
oversize packet drop behavior, reset behavior, parameterization scope, and the
future verification plan. No RTL, testbench, filelist, or regression behavior
was intentionally changed.

## Milestone 4 - Implement the Generalized 2x4 AXI4-Stream Router RTL

Outcome: Implemented the fixed 2-input, 4-output AXI4-Stream subset router as
the active synthesizable design. Added per-ingress store-and-forward packet
buffers, first-beat `tdest` routing, invalid-destination, oversize, and
malformed-packet drop counters, independent per-output round-robin arbitration,
packet-level output locking, synchronous reset clearing, focused directed
SystemVerilog tests, parameter tests, Verilator lint, and Yosys
parse/elaboration/check integration. The inherited 1x2 datapath is retired from
the active filelist. UVM, coverage closure, formal proof, and reproducible
Vivado results remain future work.
