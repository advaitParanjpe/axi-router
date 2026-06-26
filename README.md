# AXI4-Stream Packet Router

This repository contains a stabilized AXI4-Stream packet router baseline and a
milestone-driven plan for growing it into a portfolio-quality router project.
The current implemented RTL is intentionally narrow: one AXI4-Stream input is
routed to one of two AXI4-Stream outputs using the least significant bit of the
first byte in the first packet beat.

The planned future direction is a 2-input, 4-output AXI4-Stream packet router
with destination-based routing, packet-level arbitration, backpressure,
SystemVerilog assertions, and UVM verification. That generalized 2x4 design and
UVM environment are planned, not yet implemented.

## Current Design

- Protocol: AXI4-Stream subset.
- Input ports: `s_axis_tdata`, `s_axis_tvalid`, `s_axis_tready`, `s_axis_tlast`.
- Output ports: `m0_axis_*` and `m1_axis_*` with the same supported signals.
- Routing: first byte LSB. `0` routes to `m0`; `1` routes to `m1`.
- Architecture: store-and-forward packet capture, packet-level admission check,
  and one synchronous FIFO per output.
- Reset: synchronous active-high `rst`.
- Counters: packets sent to `m0`, packets sent to `m1`, and dropped packets.

Unsupported in this baseline: `tkeep`, `tstrb`, `tid`, `tdest`, `tuser`,
partial final beats, multiple inputs, arbitration, configurable route tables,
AXI4 memory-mapped, and AXI4-Lite.

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
make sim          # compile and run the original directed regression
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
