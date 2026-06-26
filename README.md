# AXI4-Stream Packet Router

This repository contains a milestone-driven AXI4-Stream packet router project.
The active synthesizable RTL is a fixed 2-input, 4-output AXI4-Stream subset
packet router with destination-based routing, store-and-forward ingress packet
buffers, packet-level output arbitration, backpressure, focused conventional
SystemVerilog tests, Verilator lint, and Yosys parse/elaboration/check.

The full UVM environment, coverage closure, formal proof, and reproducible
Vivado flow remain future work.

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
make clean        # remove build artifacts
```

Generated files are written under `build/`. The `reports/` directory contains
historical checked-in simulation and synthesis artifacts; it is not used as the
normal build output directory.

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
