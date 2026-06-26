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

These are conventional tests only. No UVM environment, functional coverage
closure, formal proof, or AXI4-Stream full-compliance claim is made.

Historical Vivado timing and utilization reports are retained under `reports/`
as evidence from the inherited project state. They are not currently
reproducible from this repository because no Vivado project, constraints, or
scripted Vivado flow is present.
