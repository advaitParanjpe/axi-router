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

## Milestone 5 - Verification Hardening, BFMs, Assertions, and Random Regression

Outcome: Added a reusable conventional non-UVM verification layer for the
implemented 2x4 router. The layer includes an AXI-Stream subset interface,
source/sink BFM tasks, public-interface ingress and egress monitors, an
independent packet-level reference model, scoreboard checks, procedural
protocol and packet-atomicity checkers, deterministic randomized regression
with seeds `1 7 23 101`, single-seed reproduction, forced-failure validation,
bounded same-output fairness checks, timeout detection, counter checks, and
explicit functional scenario bins. No synthesizable RTL changes were required.
UVM, formal proof, coverage closure, and reproducible Vivado flow remain future
work.

## Milestone 6 - Build the UVM Verification Environment

Outcome: Added a standards-oriented UVM environment source tree for the
implemented 2x4 AXI4-Stream subset router. The tree includes packet
transactions, configuration, active ingress agents, active egress
ready/backpressure agents, monitors, a virtual sequencer, focused virtual
sequences, an independent packet-level reference model, scoreboard, explicit
coverage component, UVM tests, a UVM top-level testbench, filelist, and Make
targets. Local tool assessment found Icarus Verilog 13.0, Verilator 5.048,
and Yosys 0.66, but no installed `uvm_pkg.sv` or validated UVM-capable
simulator flow, so UVM execution remains blocked and is not claimed. Existing
conventional regressions, lint, and synthesis sanity checks remain the
executable validation baseline.

## Milestone 7 - Execute and Debug the UVM Environment

Outcome: Completed the focused local Verilator + UVM execution flow. Added an
idempotent `scripts/setup-uvm.sh` pinned by default to the CHIPS Alliance
Verilator-compatible UVM source
`https://github.com/chipsalliance/uvm-verilator.git` at ref `uvm-2017-1.1`,
commit `02da9d0e20062f15fe75363bebcc31246422c2c2`, and updated the UVM runner
to compile and run the project UVM environment with `+UVM_TESTNAME`, seed
propagation, per-test build directories, logs under `build/`, generated
build-local compatibility files for unused UVM RAL and HDL-backdoor DPI
limitations, and UVM report-summary failure detection. Fixed UVM sequence-item
sequencing, Verilator virtual-interface compatibility issues, and cleaned-state
`build/tmp` handling. `make clean`, `scripts/setup-uvm.sh`, `make uvm-smoke`,
focused UVM directed tests, UVM random seeds `1 7 23 101`,
`make uvm-failure-check`, `make test`, `make random`, `make regression`,
`make lint`, and `make synth-check` pass. No synthesizable RTL changes were
required. No coverage closure, full UVM feature-support, or formal proof claim
is made.

## Milestone 8 - Verification Closure, Synthesis Results, and Release Polish

Outcome: Completed a bounded release-polish pass without redesigning the
router or restructuring the working UVM environment. Strengthened procedural
protocol checks for unknown output controls, stalled payload/metadata
stability, legal output destinations, packet destination stability, and
packet-boundary consistency. Broadened conventional random coverage gates for
ingress by destination, both contention winners, round-robin transitions,
post-drop valid traffic, reset near a final beat, counter wrap, and
head-of-line blocking. Added 16-seed conventional and UVM closure targets,
`make full-regression`, a reproducible generic Yosys synthesis report flow,
`docs/synthesis-summary.md`, `docs/architecture.mmd`, and current-facing
README/results/status documentation. No synthesizable RTL behavior changes were
required. No formal proof, coverage closure, timing closure, full UVM
feature-support, ASIC area, FPGA implementation, or full AXI4-Stream
compliance claim is made.
