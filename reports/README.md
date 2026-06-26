# Historical Simulation / Reports Artifacts

These files are historical checked-in artifacts from the original task handoff.
The normal project build now writes generated files to `build/` via the root
`Makefile`.

## Prerequisites
- Icarus Verilog (`iverilog` + `vvp`)
- Waveform viewer (Surfer or GTKWave) for `.vcd` files

## Files
- `sim.log` — historical simulation console output.
- `tb_axis_pkt_router.vcd` — historical waveform dump from the directed testbench.
- `timing_summary_synth.rpt` / `utilization_synth.rpt` — historical Vivado
  post-synthesis reports. The Vivado flow that produced them is not currently
  reproducible from this repository alone.
- `run_task2.sh` — legacy helper script retained for traceability.

## How to run

### Preferred — Root Makefile
```bash
make sim
make test
```

### Legacy helper script
```bash
./reports/run_task2.sh
```

## Expected result
Simulation should complete with a `TB PASS` summary and packet counters showing:
- packets routed to `m0`
- packets routed to `m1`
- drop count increment for forced drop scenario

## Waveform viewing
Open `tb_axis_pkt_router.vcd` in Surfer or GTKWave and inspect:
- `s_axis_*` input handshakes
- `m0_axis_*` / `m1_axis_*` output handshakes
- `pkt_to_m0_count`, `pkt_to_m1_count`, `pkt_drop_count`
- (optional) internal DUT FSM and FIFO count signals if dumped

## Notes
- Report figures (block diagram, FSM diagram, waveform screenshots) are stored under `docs/img/`.
- Raw simulation artifacts and logs are stored under `reports/`.
