# Reproducible Results

Current reproducible commands:

- `make sim`: focused generalized 2x4 directed regression passes.
- `make test`: directed regression, parameter regression, Verilator lint, and
  Yosys synthesis sanity checks pass.
- `make random`: deterministic randomized regression passes for seeds
  `1 7 23 101`.
- `make random-seed SEED=<value>`: reproduces a single randomized regression
  run and records the seed in `build/random-seed-<value>.log`.
- `make failure-check`: intentionally forces a scoreboard-style failure and
  confirms the simulator returns a nonzero status.
- `make lint`: Verilator RTL lint passes for the generalized synthesizable RTL.
- `make synth-check`: Yosys reads, elaborates, optimizes, and checks the
  generalized `axis_pkt_router` top level.
- `make uvm-static`: confirms the UVM source/filelist inventory is present.
- `scripts/setup-uvm.sh`: fetches the pinned CHIPS Alliance
  Verilator-compatible UVM source from
  `https://github.com/chipsalliance/uvm-verilator.git`, ref `uvm-2017-1.1`,
  commit `02da9d0e20062f15fe75363bebcc31246422c2c2`, into `build/deps/uvm`
  and checks for `src/uvm_pkg.sv` and `src/uvm_macros.svh`.
- `make uvm-smoke`, `make uvm-test`, `make uvm-random`, and
  `make uvm-regression`: run the Verilator-oriented UVM compile/run script
  after the pinned UVM dependency is available.
- Current Milestone 7 result: `make clean`, `scripts/setup-uvm.sh`,
  `make uvm-smoke`, `make uvm-regression`, `make uvm-failure-check`,
  `make test`, `make random`, `make regression`, `make lint`, and
  `make synth-check` pass locally on 2026-06-26.

Current focused tests cover legal `tdest` routing to outputs 0 through 3 from
both ingresses, multi-beat and single-beat packets, simultaneous ingress
traffic, concurrent different-output forwarding, same-output contention,
round-robin packet ordering, output backpressure, held payload during stalls
through local simulation checks, invalid destinations, malformed changing
`tdest`, oversize packets, exact-capacity packets, packet traffic after drops,
reset while idle, reset during capture, reset during stalled output transfer,
and selected parameter cases including `DATA_W=16`, packet capacity 1, and a
small counter-width wrap case.

The randomized regression adds reusable AXI-Stream subset interfaces, source
and sink BFM tasks, reset-aware randomized backpressure, public-interface
monitors, an independent packet-level reference model, scoreboard checks,
procedural protocol/stability checks, bounded same-output round-robin fairness
checks, timeout/deadlock detection, counter checking including modulo wrap, and
explicit scenario coverage counters. The default seed list is `1 7 23 101`.
The coverage counters require hits for both ingresses, all destinations,
single/multi/max-length packets, invalid/malformed/oversize drops, contention,
different-output concurrency, stalls including a long stall and lock-held
stall, reset during capture, reset during transmit, and counter wrap events.

Milestone 6 adds a UVM environment source tree and build targets. Milestone 7
adds pinned dependency setup and a Verilator compile/run script. The local tool
assessment found Icarus Verilog 13.0, Verilator 5.048, and Yosys 0.66.

The Milestone 7 UVM regression passes these focused tests: smoke, routing,
concurrency, contention, backpressure, drop, reset, and randomized traffic
with seeds `1 7 23 101`. Scoreboard summaries report zero pending and zero
unexpected packets, and every normal UVM run reports `UVM_WARNING : 0`,
`UVM_ERROR : 0`, and `UVM_FATAL : 0`. The forced UVM scoreboard error path is
intentionally detected and returns nonzero.

Remaining UVM simulator limitation: the Verilator runner excludes unused UVM
RAL and HDL-backdoor DPI sources by default through generated build-local
compatibility files under `build/uvm/`. This is a local simulator compatibility
choice, not a claim of full UVM library feature support.

No functional coverage closure, formal proof, or AXI4-Stream full-compliance
claim is made.

Historical Vivado timing and utilization reports are retained under `reports/`
as evidence from the inherited project state. They are not currently
reproducible from this repository because no Vivado project, constraints, or
scripted Vivado flow is present.
