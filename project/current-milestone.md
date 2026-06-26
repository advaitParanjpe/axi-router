# Milestone 6 — Build the UVM Verification Environment

## Objective

Build a reusable UVM environment for the implemented 2-input/4-output AXI4-Stream packet router by adapting the proven transaction model, BFMs, monitors, scoreboard rules, and coverage plan from Milestone 5.

This milestone must establish a complete working UVM architecture and a focused set of directed and lightly randomized UVM tests.

Do not replace or remove the existing conventional SystemVerilog regressions. They remain the trusted fast baseline.

Do not redesign the synthesizable router unless the UVM environment exposes a confirmed RTL defect with a reproducible failing test.

## Required context

Read:

- `AGENTS.md`
- `README.md`
- `docs/architecture.md`
- `docs/decisions.md`
- `docs/verification-plan.md`
- `docs/results.md`
- `project/project-status.md`
- `project/milestone-history.md`
- all active RTL
- the conventional interface, BFMs, monitors, scoreboard logic, protocol checker, directed tests, randomized tests, filelists, and Makefile targets

Treat Milestone 5’s conventional verification semantics as the reference when adapting behavior into UVM.

## Tool and simulator assessment

Before implementation:

1. Inspect the locally installed simulators and determine which can compile and run UVM.
2. Inspect available UVM library installations or simulator-provided UVM support.
3. Prefer an existing supported installation rather than vendoring a large UVM library blindly.
4. Document the selected simulator, UVM version, compile flags, and limitations.
5. Keep the existing Icarus-based conventional regression unchanged if Icarus cannot support the required UVM features.

Likely open-source options may include Verilator with a compatible UVM setup or another locally installed simulator. Use only tooling that is actually available and validated.

If no installed simulator can execute UVM:

- still create a standards-based UVM environment that is structurally reviewable
- add a compile path where practical
- document the exact blocking tool limitation
- do not falsely claim UVM execution
- keep all existing conventional validation passing

However, make a serious effort to achieve an executable UVM flow.

## Required UVM architecture

Create a clear UVM directory structure, such as:

```text
tb/uvm/
├── axis_router_uvm_pkg.sv
├── axis_router_transaction.sv
├── axis_router_config.sv
├── axis_ingress_sequencer.sv
├── axis_ingress_driver.sv
├── axis_ingress_monitor.sv
├── axis_ingress_agent.sv
├── axis_egress_driver.sv
├── axis_egress_monitor.sv
├── axis_egress_agent.sv
├── axis_router_reference_model.sv
├── axis_router_scoreboard.sv
├── axis_router_coverage.sv
├── axis_router_env.sv
├── axis_router_sequences.sv
├── axis_router_virtual_sequencer.sv
├── axis_router_tests.sv
└── tb_axis_router_uvm.sv
```

The exact file split may differ, but responsibilities must remain clear. Avoid placing the entire environment in one oversized file.

## 1. Transaction model

Implement a packet-level UVM sequence item representing:

- ingress port
- packet payload beats
- packet length
- destination
- optional malformed destination behavior
- optional invalid destination behavior
- optional oversize behavior
- configurable inter-beat gaps
- transaction identifier for debug and scoreboard correlation

Provide:

- UVM field automation or explicit `do_copy`, `do_compare`, `do_print`, and `convert2string` support
- legal constraints for normal packets
- controlled methods or constraints for negative/error traffic
- concise debug printing

Do not model unsupported AXI4-Stream fields.

## 2. Configuration object

Create a UVM configuration object containing at least:

- number of ingress agents: 2
- number of egress agents: 4
- data width
- destination width
- packet-buffer capacity
- counter width
- active/passive agent settings
- timeout
- seed or test configuration where useful
- backpressure configuration
- coverage enable
- scoreboard enable

Use the UVM configuration database cleanly. Avoid scattered hard-coded virtual-interface assignments.

## 3. Ingress agents

Create one ingress agent per input.

Each active ingress agent must contain:

- sequencer
- driver
- monitor

The driver must:

- consume packet transactions
- drive the supported AXI4-Stream signals
- obey `tvalid/tready`
- preserve payload, `tlast`, and `tdest` while stalled
- support inter-beat and inter-packet gaps
- support legal and intentionally malformed traffic
- stop and recover correctly across reset
- call `item_done()` only after the sequence item has been handled correctly

The monitor must:

- observe only public interface signals
- reconstruct accepted packets from `tvalid && tready`
- publish packet observations through analysis ports
- detect reset-aborted partial packets and discard them appropriately
- provide useful protocol/error reporting

Reuse semantic lessons from the conventional BFMs, but do not directly depend on procedural testbench globals.

## 4. Egress agents

Create one egress agent per output.

Each egress agent should include:

- a ready/backpressure driver when active
- a passive output monitor

The ready driver must support:

- always-ready operation
- deterministic stall patterns
- randomized backpressure
- prolonged bounded stalls
- reset-aware behavior

The monitor must:

- reconstruct transferred packets
- preserve output port identity
- publish completed packet observations
- detect malformed boundaries or protocol inconsistencies
- discard reset-aborted partial observations

Do not create an egress sequencer architecture more complicated than necessary. A simple ready-control sequence item or configuration-driven driver is sufficient.

## 5. Virtual interfaces and top-level testbench

Use the existing AXI-Stream interface where practical, extending it only if required without breaking conventional tests.

The UVM top-level module must:

- instantiate the DUT
- instantiate two ingress interfaces
- instantiate four egress interfaces
- connect arrayed DUT ports correctly
- generate clock and synchronous reset
- place virtual interfaces in `uvm_config_db`
- invoke `run_test()`
- expose counters to the scoreboard through a clean observation mechanism
- support optional waveform dumping
- use a bounded simulation timeout

Avoid hierarchical access to internal DUT implementation state.

## 6. Reference model

Implement an independent packet-level UVM reference model.

It must:

- receive observed ingress packets
- independently classify packets as:
  - legal
  - invalid destination
  - malformed destination
  - oversize
  - reset-aborted
- predict the correct output for legal packets
- produce expected packets for the scoreboard
- predict counter updates
- follow documented drop-reason precedence
- flush relevant expected state on reset

Do not copy RTL state-machine logic line by line.

Where arbitration affects exact ordering, model the documented round-robin rules or provide the scoreboard with an explicitly legal set of expected orderings. Prefer exact modeling where practical because the policy is deterministic.

## 7. Scoreboard

Create a UVM scoreboard using analysis ports, analysis exports, analysis FIFOs, or another clean UVM transaction flow.

It must check:

- correct output routing
- packet payload integrity
- beat order
- packet length and `tlast` boundaries
- no duplication
- no unexpected packet
- no missing packet
- dropped traffic never reaches an output
- same-output contention ordering
- per-output packet atomicity
- reset flushing
- counter values modulo configured width

At end of test, the scoreboard must fail if:

- expected packets remain unmatched
- unexpected packets were observed
- protocol/reference-model errors occurred
- counter mismatches remain

Provide concise but useful diagnostics containing:

- test name
- transaction identifier
- ingress
- expected output
- actual output
- destination
- packet length
- payload mismatch location where applicable

## 8. Virtual sequencer and virtual sequences

Create a virtual sequencer coordinating:

- two ingress sequencers
- four egress/backpressure controls where sequence-driven

Implement reusable virtual sequences for at least:

- basic routing
- simultaneous different-output traffic
- same-output contention
- round-robin fairness
- randomized output backpressure
- invalid destinations
- malformed changing destination
- oversize packets
- reset during capture
- reset during transmission
- mixed legal and illegal traffic
- lightly randomized multi-ingress traffic

Do not make all tests depend on one monolithic virtual sequence.

## 9. UVM tests

Implement a reusable base test and focused derived tests.

At minimum provide:

- `axis_router_smoke_test`
- `axis_router_routing_test`
- `axis_router_concurrency_test`
- `axis_router_contention_test`
- `axis_router_backpressure_test`
- `axis_router_drop_test`
- `axis_router_reset_test`
- `axis_router_random_test`

Tests must configure the environment, launch appropriate virtual sequences, enforce timeouts, and allow objections to end cleanly.

The smoke test should remain quick.

## 10. Functional coverage

Implement a UVM subscriber or coverage component.

Cover:

- ingress port
- output destination
- packet-length categories
- single-beat, multi-beat, and maximum-capacity packets
- legal and each drop reason
- same-output contention
- different-output concurrency
- backpressure occurrence
- reset during capture
- reset during transmit
- round-robin winner transitions where observable
- relevant crosses:
  - ingress × destination
  - ingress × packet-length category
  - drop reason × ingress
  - contention × packet-length category

If the selected simulator lacks usable SystemVerilog covergroup support, preserve the explicit coverage-bin mechanism from Milestone 5 within a UVM component and report bin results.

Do not claim coverage closure during this milestone. Report measured results honestly.

## 11. Protocol checking

Reuse or adapt the Milestone 5 procedural checker so UVM simulations continue checking:

- output stability while stalled
- valid destination values
- no unknown control signals
- reset behavior
- destination stability within output packets
- bounded timeout/deadlock behavior

Keep the checker independent of UVM where useful so it remains reusable across both testbench styles.

Do not weaken the conventional regression.

## 12. UVM reporting and test outcome

Configure UVM reporting so:

- `UVM_ERROR` and `UVM_FATAL` produce a failing process exit status
- normal output is readable
- component topology can be printed for one debug target
- seed and test name appear in logs
- scoreboard summary appears at end of test
- coverage summary appears at end of test

Confirm intentionally that a forced UVM error causes the command to return nonzero, then restore the passing state.

## 13. Build and regression integration

Add clear build targets such as:

- `make uvm-smoke`
- `make uvm-test TEST=<test-name>`
- `make uvm-random SEED=<seed>`
- `make uvm-regression`

Exact names may follow existing project conventions.

Requirements:

- existing `make test`, `make random`, `make regression`, `make lint`, and `make synth-check` continue to work
- UVM artifacts and logs stay under `build/`
- each test records simulator, test name, and seed
- a single UVM test can be reproduced easily
- slower UVM regression remains separate from the fast conventional smoke tests
- failures propagate a nonzero exit status
- no commercial simulator is assumed unless actually available

Add UVM filelists and scripts cleanly.

## 14. Validation of the UVM environment

Validate at least:

- all agents build and connect correctly
- virtual interfaces are set correctly
- drivers and sequencers complete handshakes
- monitors reconstruct packets correctly
- reference model produces predictions
- scoreboard detects injected mismatches
- reset flushes partial transactions
- backpressure does not break drivers
- tests terminate without objection leaks
- intentional UVM errors fail the process

Where execution is supported, run all focused UVM tests and a small deterministic random seed set.

## 15. RTL changes

Do not modify synthesizable RTL unless the UVM environment exposes a confirmed bug.

For every RTL change:

- retain a minimal reproducing UVM or conventional regression
- document the root cause
- document why Milestone 5 did not detect it
- rerun all conventional and UVM validation

## 16. Documentation and project state

Update:

- `README.md`
- `docs/verification-plan.md`
- `docs/results.md`
- `project/project-status.md`
- `project/milestone-history.md`

Document:

- UVM simulator and UVM version
- environment hierarchy
- tests implemented
- commands
- seed reproduction
- scoreboard behavior
- coverage implementation
- protocol checker integration
- any RTL defects discovered
- known tool limitations
- remaining work before verification closure

Do not claim full verification closure, formal proof, full AXI4-Stream compliance, or reproducible Vivado support.

## Validation

Run at minimum:

- `scripts/check-repo.sh`
- `make clean`
- `make test`
- `make random`
- existing conventional regression
- UVM smoke test
- all focused UVM directed tests
- a deterministic UVM random seed set
- intentional UVM failure/exit-code check
- `make lint`
- `make synth-check`
- `git diff --check`

If UVM execution is blocked by unavailable simulator support, run every feasible compile/static check and clearly report the limitation.

## Acceptance criteria

- A recognizable, reusable UVM environment exists.
- Two ingress agents and four egress agents are instantiated.
- Active drivers obey AXI-Stream handshakes and reset.
- Monitors reconstruct packet transactions using public interfaces.
- A virtual sequencer coordinates multi-agent scenarios.
- The independent reference model predicts routing, drops, counters, and arbitration.
- The scoreboard detects loss, duplication, corruption, misrouting, ordering errors, and counter mismatches.
- Functional scenario coverage is recorded.
- Directed UVM tests cover routing, concurrency, contention, backpressure, drops, and reset.
- A randomized UVM test is reproducible by seed.
- UVM failures produce nonzero command status.
- Existing conventional verification remains operational.
- Verilator RTL lint and Yosys synthesis checks remain passing.
- No unsupported claims are made.
- Any inability to execute UVM is documented precisely rather than hidden.

## Completion report

End with:

- Status
- Milestone
- Summary
- Simulator and UVM version
- UVM hierarchy
- Transactions and configuration
- Agents implemented
- Drivers and monitors
- Virtual sequencer and sequences
- Reference model
- Scoreboard
- Coverage component
- Tests implemented
- Build and regression commands
- UVM test results
- Conventional regression results
- RTL bugs found and fixed
- Files changed
- Validation results
- Tool limitations
- Remaining verification risks
- Recommended next milestone

The recommended next milestone should expand UVM constrained-random testing, coverage measurement, assertions, and regression depth toward verification closure. It should not immediately add unrelated RTL features.