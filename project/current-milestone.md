# Milestone 7 — Execute and Debug the UVM Environment

## Objective

Establish a reproducible local Verilator + UVM execution flow, compile the Milestone 6 UVM environment, debug it, and run all focused UVM tests successfully.

Do not add major new verification features or modify RTL unless an executed UVM test exposes a confirmed DUT defect.

## Required work

1. Inspect:
   - `verilator --version`
   - current UVM scripts, filelists, Makefile targets, and `tb/uvm/`
   - the current official/reputable Verilator-compatible UVM options

2. Add a reproducible dependency setup script, such as:

   - `scripts/setup-uvm.sh`

   It must:

   - fetch a pinned Verilator-compatible UVM 2017 release
   - prefer the CHIPS Alliance/Verilator-compatible `uvm-2017-1.1` source unless testing proves another pinned release works better
   - install it under a gitignored dependency directory such as `build/deps/uvm`
   - verify the expected `uvm_pkg.sv` and include directory exist
   - avoid committing the full external UVM source tree
   - print the exact source URL, revision/tag, and local path
   - be idempotent

3. Update `scripts/run-uvm.sh`, Makefile targets, and UVM filelists so Verilator can:

   - compile the UVM library and project UVM sources
   - build an executable simulation
   - pass `+UVM_TESTNAME=<test>`
   - pass and print the seed
   - place all generated files under `build/`
   - propagate compilation and simulation failures
   - save readable per-test logs

4. Compile and debug the UVM environment.

   Fix:

   - unsupported or incorrect SystemVerilog/UVM constructs
   - package/include ordering
   - factory registration errors
   - config database and virtual-interface wiring
   - phase objections
   - driver/sequencer handshakes
   - monitor reconstruction
   - analysis-port connections
   - reset handling
   - scoreboard draining and end-of-test checks
   - simulator compatibility issues

   Preserve the intended UVM architecture. Do not delete substantive components merely to obtain a passing smoke test.

5. Run and pass:

   - `axis_router_smoke_test`
   - `axis_router_routing_test`
   - `axis_router_concurrency_test`
   - `axis_router_contention_test`
   - `axis_router_backpressure_test`
   - `axis_router_drop_test`
   - `axis_router_reset_test`
   - `axis_router_random_test` with at least seeds 1, 7, 23, and 101

6. Verify that:

   - two ingress agents and four egress agents build
   - drivers complete sequence items
   - monitors publish observed packets
   - reference model produces predictions
   - scoreboard matches expected and actual packets
   - reset flushes partial transactions correctly
   - tests finish without objection leaks or timeout
   - a deliberately forced scoreboard error returns nonzero

7. Keep all conventional verification passing:

   - `make test`
   - `make random`
   - `make regression`
   - `make lint`
   - `make synth-check`

8. Update:

   - `README.md`
   - `docs/verification-plan.md`
   - `docs/results.md`
   - `project/project-status.md`
   - `project/milestone-history.md`

   Record the exact Verilator version, UVM source/tag, setup command, execution commands, passing tests, seeds, and remaining limitations.

## Acceptance criteria

- UVM dependency setup is reproducible from a clean checkout.
- The UVM environment compiles and executes locally.
- All focused UVM tests pass.
- Random tests pass for the required deterministic seeds.
- The scoreboard and forced-failure path are proven executable.
- Conventional regressions remain passing.
- No unsupported claim of coverage closure is made.
- Any UVM source edits are genuine compatibility or correctness fixes, not removal of meaningful verification behavior.

## Validation

Run:

- `scripts/setup-uvm.sh`
- `make clean`
- `make uvm-smoke`
- all focused UVM tests
- required UVM random seeds
- `make uvm-failure-check`
- `make test`
- `make random`
- `make regression`
- `make lint`
- `make synth-check`
- `git diff --check`

## Completion report

Report:

- Status
- Verilator version
- UVM source and pinned revision
- Setup process
- Compile issues found and fixed
- UVM runtime issues found and fixed
- Tests and seeds executed
- Scoreboard and failure-check results
- Conventional regression results
- RTL changes, if any
- Files changed
- Remaining simulator limitations
- Recommended next milestone