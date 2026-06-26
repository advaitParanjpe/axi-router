# Milestone 5 — Verification Hardening, BFMs, Assertions, and Random Regression

## Objective

Strengthen verification of the implemented 2-input/4-output AXI4-Stream router before introducing UVM.

Build a reusable conventional SystemVerilog verification layer with AXI-Stream interfaces, source/sink BFMs, an independent packet-level reference model and scoreboard, protocol assertions, randomized traffic, functional coverage where supported, and repeatable regressions.

Do not implement the UVM environment in this milestone.

Do not redesign the router architecture unless verification exposes a confirmed RTL defect. Any RTL change must be narrowly scoped, documented, and accompanied by a regression that demonstrates the original failure.

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
- all active RTL, testbenches, filelists, scripts, and Makefile targets

Treat the frozen architecture and implemented Milestone 4 behaviour as authoritative.

## Required work

### 1. Verification architecture

Create a reusable non-UVM verification structure.

Use clear components such as:

- AXI-Stream SystemVerilog interface
- ingress source BFM or driver
- egress sink/backpressure BFM
- ingress monitor
- egress monitor
- packet transaction representation
- independent routing/reference model
- packet-level scoreboard
- test configuration and deterministic seed handling

Keep these components lightweight and suitable for later reuse or adaptation within UVM.

Do not duplicate DUT implementation logic line-for-line inside the reference model.

### 2. AXI-Stream interface

Create a SystemVerilog interface for the supported subset:

- `tdata`
- `tvalid`
- `tready`
- `tlast`
- `tdest`

Provide suitable modports for:

- source driving
- sink driving
- passive monitoring

If tool support permits, include protocol assertions or helper tasks in the interface. Otherwise keep assertions in a separate checker module.

The active synthesizable RTL interface does not need to change solely to use interfaces in the testbench; connect interfaces to the existing arrayed DUT ports cleanly.

### 3. Source BFMs

Implement reusable source BFMs capable of:

- sending single-beat and multi-beat packets
- selecting ingress and destination
- inserting deterministic or randomized gaps between beats
- holding payload and sideband signals stable while stalled
- intentionally generating:
  - invalid destinations
  - changing `tdest`
  - oversize packets
- stopping cleanly on reset
- restarting after reset

Avoid clock-edge races by using clocking blocks or disciplined drive timing supported by the toolchain.

### 4. Sink and backpressure BFMs

Implement reusable sink BFMs capable of:

- always-ready operation
- deterministic stall patterns
- randomized backpressure
- prolonged stalls
- independent behavior for all four outputs
- reset-aware operation

Use deterministic seeds so every failure is reproducible.

### 5. Independent monitors and scoreboard

Monitor accepted ingress beats and accepted egress beats using only public interface handshakes.

Reconstruct complete packets independently.

The scoreboard must verify:

- legal packets are delivered to the correct output
- packet data and beat order are preserved
- `tlast` boundaries are preserved
- dropped packets never appear on outputs
- packets are neither duplicated nor lost
- each legal packet appears exactly once
- packets on one output never interleave
- per-ingress ordering is preserved where required by the architecture
- reset correctly flushes expected in-flight state
- counters match independently calculated expected events

Account honestly for arbitration nondeterminism. For same-output contention, either model the exact documented round-robin behavior or compare against a legal ordering set derived from the specification.

Do not use DUT internal signals as the primary correctness oracle.

### 6. Protocol and architectural assertions

Add a meaningful assertion/checker layer for:

- output `tdata`, `tdest`, and `tlast` stability while `tvalid && !tready`
- input source stability assumptions or checks while stalled
- no unknown control signals after reset
- valid output destination values
- no output packet interleaving
- lock persistence until accepted `tlast`
- at most one ingress owner per output
- one ingress packet not driving multiple outputs
- counter increments only on documented packet events
- outputs deasserted during reset or in the documented post-reset cycle
- completed packet state cannot be overwritten
- arbiter priority changes only after completed packet forwarding

Use concurrent SVA where supported by Verilator or another available simulator. Where Icarus support is insufficient, use procedural cycle-by-cycle checkers and document the limitation.

Keep assertion code synthesis-safe through separation or guards.

### 7. Directed verification expansion

Retain all Milestone 4 tests and add focused cases for:

- repeated contention over many packets
- alternating and asymmetric packet lengths under contention
- stalled winner while another ingress is waiting
- all four outputs active concurrently where achievable
- independent output stalls
- back-to-back packets from each ingress
- maximum-capacity packets
- repeated dropped packets followed by valid traffic
- simultaneous invalid or malformed traffic on both ingresses
- simultaneous reset-sensitive traffic
- reset on or near the final beat
- counter wrap behavior
- long stalls with payload-stability checking
- head-of-line blocking scenario demonstrating documented behavior

### 8. Randomized regression

Add deterministic constrained-random or pseudo-random testing using the available simulator.

Randomize:

- ingress selection
- packet length
- destination
- payload
- inter-packet gaps
- inter-beat gaps where legal
- output backpressure
- contention frequency
- invalid destinations
- malformed destination changes
- oversize packets
- reset injection, if reliable and reproducible

Run enough traffic to expose concurrency and arbitration defects without making normal regression excessively slow.

Support:

- explicit random seed
- default regression seed list
- failure output that prints the seed
- easy single-seed reproduction
- bounded timeout/deadlock detection

Example targets may include:

- `make random`
- `make random SEED=<value>`
- `make regression`

Use project conventions rather than these exact names if better alternatives already exist.

### 9. Fairness verification

Test round-robin arbitration under sustained same-output contention.

Verify that:

- both ingresses make progress
- the documented initial winner is observed
- priority advances only after packet completion
- output stalls do not cause ownership changes
- one requester is not starved while both remain continuously eligible

Use a practical bounded fairness check rather than claiming mathematical proof.

### 10. Functional coverage

Where supported by installed open-source tools, add functional coverage for important scenarios.

Cover at least conceptually:

- both ingresses
- all four destinations
- packet-length categories
- single-beat and multi-beat packets
- same-output contention
- different-output concurrency
- each drop reason
- output stalls
- lock held across stalls
- reset during capture
- reset during transmit
- round-robin winner transitions
- counter wrap
- relevant crosses such as ingress × destination and contention × packet length

If usable SystemVerilog covergroup support is unavailable, implement explicit coverage counters or bins in the testbench and print a coverage summary.

Do not call this formal coverage closure. Define measurable scenario goals and fail the regression if essential bins remain unhit.

### 11. Regression organization

Update Makefile and filelists so that:

- existing smoke tests remain fast
- the standard `make test` remains useful
- broader randomized regression has a separate clear command if it is materially slower
- failures propagate nonzero exit status
- logs and waveforms stay under `build/`
- waveforms remain optional
- each random run records its seed
- timeouts fail clearly

Do not add heavyweight external dependencies.

### 12. RTL audit during verification

Use the stronger verification environment to audit:

- simultaneous ingress completion
- simultaneous requests to multiple outputs
- lock acquisition and release
- arbitration priority updates
- drop-state exit
- exact-capacity packet handling
- reset precedence
- counter increment events
- parameter-width behavior

Fix confirmed RTL defects only when reproduced by a self-checking test.

For every RTL bug fixed, document:

- failing scenario
- root cause
- files changed
- regression added

### 13. Documentation and project state

Update:

- `README.md`
- `docs/verification-plan.md`
- `docs/results.md`
- `project/project-status.md`
- `project/milestone-history.md`

Record:

- verification components implemented
- directed and random scenarios covered
- seed list used
- assertion/checker support
- functional coverage mechanism
- any RTL bugs found and fixed
- reproducible commands
- remaining gaps before UVM

Do not claim UVM, formal proof, complete AXI4-Stream compliance, or coverage closure.

## Validation

Run at minimum:

- `scripts/check-repo.sh`
- `make clean`
- `make test`
- the complete randomized regression command
- at least one explicit single-seed reproduction command
- `make lint`
- `make synth-check`
- `git diff --check`

Run a sufficiently broad but practical deterministic seed set.

Review timeout behavior and intentionally test that a forced scoreboard error or equivalent test failure returns a nonzero exit code, without leaving the repository in a failing state.

## Acceptance criteria

- Reusable AXI-Stream source, sink, and monitoring infrastructure exists.
- An independent packet-level reference model and scoreboard check public-interface behavior.
- Directed and randomized traffic exercise routing, concurrency, contention, stalls, drops, reset, fairness, and boundaries.
- Random failures are reproducible from a printed seed.
- Deadlock/timeouts are detected.
- Output stability and packet atomicity are checked.
- Round-robin behavior and bounded fairness are verified.
- Counters are checked independently.
- Functional scenario coverage is measured using supported tooling or explicit bins.
- Essential coverage bins are exercised by regression.
- Any RTL changes are backed by failing-then-passing regression tests.
- Existing lint and synthesis checks continue to pass.
- No UVM classes or UVM dependency are introduced.
- Documentation accurately distinguishes tested behavior from proof or closure.

## Completion report

End with:

- Status
- Milestone
- Summary
- Verification architecture added
- Interfaces and BFMs added
- Reference model and scoreboard behavior
- Assertions/checkers added
- Directed tests added
- Random regression structure and seeds
- Functional coverage results
- Fairness results
- RTL bugs found and fixed
- Files changed
- Commands run
- Validation results
- Known limitations
- Remaining risks before UVM
- Recommended next milestone

The recommended next milestone should build the UVM environment by adapting the now-proven transaction model, drivers, monitors, scoreboard logic, and coverage plan.