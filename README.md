# AXI4-Stream Packet Router

This repository contains a milestone-driven AXI4-Stream packet router project.
The active synthesizable RTL is a fixed 2-input, 4-output AXI4-Stream subset
packet router with destination-based routing, store-and-forward ingress packet
buffers, packet-level output arbitration, backpressure, focused conventional
SystemVerilog tests, a reusable non-UVM random testbench layer, a focused UVM
regression flow, Verilator lint, and Yosys parse/elaboration/check.

Coverage closure, formal proof, and a reproducible Vivado flow remain future
work.

## Current Design

- Protocol: AXI4-Stream subset.
- Input ports: two arrayed ingress ports with `tdata`, `tvalid`, `tready`,
  `tlast`, and `tdest`.
- Output ports: four arrayed egress ports with `tdata`, `tvalid`, `tready`,
  `tlast`, and `tdest`.
- Routing: first-beat `tdest`; values 0 through 3 map directly to outputs 0
  through 3.
- Architecture: one store-and-forward packet buffer per ingress and one
  independent round-robin arbiter per output.
- Reset: synchronous active-high `rst`.
- Counters: accepted packet count per ingress, forwarded packet count per
  output, and invalid-destination, oversize, and malformed drop counts per
  ingress.

Unsupported in this implementation: `tkeep`, `tstrb`, `tid`, `tuser`, partial
final beats, arbitrary ingress/egress counts, virtual output queues,
cut-through forwarding, configurable route tables, AXI4 memory-mapped, and
AXI4-Lite.

## Repository Structure

- `rtl/` - synthesizable SystemVerilog RTL.
- `tb/` - directed SystemVerilog testbenches.
- `filelists/` - explicit source and testbench filelists.
- `docs/` - architecture notes, verification plan, decisions, results, and
  historical report documentation.
- `project/` - current milestone, project status, and milestone history.
- `scripts/` - repository workflow helpers.
- `reports/` - historical checked-in artifacts from the inherited project.
- `build/` - generated outputs; ignored by Git.

## Commands

```sh
make sim          # compile and run the focused 2x4 directed regression
make waves        # run directed regression and write build/tb_axis_pkt_router.vcd
make lint         # Verilator lint on synthesizable RTL
make synth-check  # Yosys read/elaborate/check of synthesizable RTL
make test         # normal regression: directed tests, parameter tests, lint, synth check
make random       # deterministic non-UVM randomized regression, seeds 1 7 23 101
make random-seed SEED=<n> # reproduce one randomized run
make regression   # normal regression plus randomized regression
make uvm-smoke    # run the UVM smoke test
make uvm-test TEST=<test-name> SEED=<n> # run one UVM test
make uvm-random SEED=<n> # run the randomized UVM test
make uvm-regression # run focused UVM directed tests plus random seeds
make uvm-failure-check # confirm the UVM failure path returns nonzero
make setup-uvm    # fetch pinned Verilator-compatible UVM sources under build/deps/uvm
make clean        # remove build artifacts while preserving build/deps
make distclean    # remove all build outputs, including external dependencies
```

Generated files are written under `build/`. The `reports/` directory contains
historical checked-in simulation and synthesis artifacts; it is not used as the
normal build output directory.

## UVM Environment

Milestone 6 adds a standards-oriented UVM source tree under `tb/uvm/` with
packet transactions, configuration, two ingress agents, four egress agents, a
virtual sequencer, focused virtual sequences, an independent packet-level
reference model, scoreboard, coverage component, tests, and a UVM top-level
testbench.

Milestone 7 added `scripts/setup-uvm.sh` and a Verilator-oriented
`scripts/run-uvm.sh` flow. The setup script is pinned by default to the
CHIPS Alliance Verilator-compatible UVM source at
`https://github.com/chipsalliance/uvm-verilator.git`, ref
`uvm-2017-1.1`, and installs it under `build/deps/uvm`.

The current local open-source tool assessment found Icarus Verilog 13.0,
Verilator 5.048, and Yosys 0.66. Milestone 7 validates a local UVM checkout at
commit `02da9d0e20062f15fe75363bebcc31246422c2c2` under `build/deps/uvm`.
`make uvm-smoke`, `make uvm-regression`, and `make uvm-failure-check` pass.

The Verilator UVM runner uses build-local generated compatibility files under
`build/uvm/` to exclude unused UVM RAL and HDL-backdoor DPI code by default,
because those parts of the pinned UVM source do not compile cleanly in this
local Verilator 5.048 flow and the project UVM environment does not use them.
No functional coverage closure or full UVM feature-support claim is made.

## Milestone Workflow

Development is driven by `project/current-milestone.md`. Codex and human
contributors should treat that file as the only active implementation
assignment, while using `docs/` and `project/project-status.md` for context.

To run Codex with the repository workflow prompt:

```sh
scripts/run-codex.sh
```

The runner refuses to start on a dirty Git tree by default. Use
`scripts/run-codex.sh --allow-dirty` only when intentionally continuing from
local edits.

For a fast repository housekeeping check:

```sh
scripts/check-repo.sh
```
