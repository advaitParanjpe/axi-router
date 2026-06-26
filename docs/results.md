# Reproducible Results

Current reproducible commands:

- `make sim`: original directed regression passes.
- `make test`: directed regression, parameter regression, lint, and synthesis
  sanity checks pass.
- `make lint`: Verilator RTL lint passes for synthesizable RTL.
- `make synth-check`: Yosys reads, elaborates, optimizes, and checks the RTL.

The current regression covers the 1x2 AXI4-Stream subset baseline only.

Historical Vivado timing and utilization reports are retained under `reports/`
as evidence from the inherited project state. They are not currently
reproducible from this repository because no Vivado project, constraints, or
scripted Vivado flow is present.
