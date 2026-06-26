# Reproducible Results

Current reproducible commands:

- `make sim`: focused generalized 2x4 directed regression passes.
- `make test`: directed regression, parameter regression, Verilator lint, and
  Yosys synthesis sanity checks pass.
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

These are focused conventional tests only. No UVM environment, functional
coverage closure, formal proof, or AXI4-Stream full-compliance claim is made.

Historical Vivado timing and utilization reports are retained under `reports/`
as evidence from the inherited project state. They are not currently
reproducible from this repository because no Vivado project, constraints, or
scripted Vivado flow is present.
