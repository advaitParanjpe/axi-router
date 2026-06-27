# Milestone 8 — Verification Closure, Synthesis Results, and Release Polish

## Objective

Finish the AXI4-Stream router project to a strong portfolio-ready state.

This milestone must:

- strengthen assertions and measurable coverage
- run a broader but bounded regression campaign
- produce reproducible synthesis/resource results
- clean and finalize documentation
- prepare the repository for a public GitHub release

Do not redesign the router architecture.

Do not rebuild or substantially restructure the working UVM environment.

Do not add unrelated RTL features, new buses, virtual output queues, cut-through routing, arbitrary port counts, or a control/status interface.

Prefer focused edits and reuse the existing conventional and UVM verification infrastructure.

## Required context

Read:

- `AGENTS.md`
- `README.md`
- `docs/architecture.md`
- `docs/decisions.md`
- `docs/verification-plan.md`
- `docs/development-plan.md`
- `docs/results.md`
- `project/project-status.md`
- `project/milestone-history.md`
- active RTL
- conventional verification infrastructure
- UVM environment
- Makefile, scripts, and filelists

Treat the implemented 2x4 router and validated Verilator/UVM flow as stable.

## Scope control

This milestone is a closure and release milestone, not another architecture milestone.

Do not:

- replace working UVM components
- rewrite drivers, monitors, scoreboard, or reference model without a confirmed defect
- vendor the UVM library into source control
- add large external dependencies
- make speculative RTL optimizations
- claim proof or closure unsupported by measured results

If a test reveals a real RTL or verification defect, fix it narrowly and add a reproducing regression.

## 1. Assertion and protocol-checker strengthening

Review the existing procedural protocol checker and local assertions.

Add or strengthen focused checks for:

- output payload stability while `tvalid && !tready`
- output `tdest` and `tlast` stability while stalled
- no unknown `tvalid`, `tready`, `tlast`, or `tdest` after reset
- legal destination values on transferred output packets
- packet destination stability
- packet atomicity and no interleaving
- output ownership persistence through stalls
- ownership release only after accepted `tlast`
- at most one active ingress owner per output
- one ingress packet not driving multiple outputs
- arbiter priority changing only after completed packet transfer
- completed ingress packet state not being overwritten
- counter increments occurring only on documented packet events
- reset clearing locks, packet state, and output validity

Use concurrent SVA where reliably supported by the current Verilator flow.

Where simulator support is limited, retain robust procedural cycle-by-cycle checks.

Do not break Icarus conventional regressions solely to introduce unsupported SVA syntax.

Document which checks are concurrent assertions and which are procedural checkers.

## 2. Coverage strengthening

Review the existing explicit conventional and UVM coverage counters.

Ensure measurable coverage exists for:

- both ingress ports
- all four output destinations
- ingress × destination
- single-beat packets
- multi-beat packets
- maximum-capacity packets
- both ingresses active concurrently
- different-output concurrency
- same-output contention
- both possible contention winners
- round-robin winner transitions
- output stalls
- lock held across a stall
- each invalid/drop reason
- valid traffic immediately after each drop type
- reset during ingress capture
- reset during output transmission
- reset near the accepted final beat
- counter wrap
- head-of-line blocking scenario

Add concise coverage summaries to conventional and UVM logs.

Essential coverage bins must cause the intended broader regression to fail if unhit.

Do not claim formal coverage closure. Report scenario/bin coverage only.

## 3. Bounded broader regression

Add a broader deterministic regression target without making normal development painfully slow.

Use a documented seed set, for example 16 or 32 deterministic seeds, covering both conventional random and UVM random testing.

Requirements:

- fixed default seed list checked into the Makefile or script
- easy single-seed reproduction
- per-seed logs under `build/`
- nonzero exit on first failure or a clearly summarized aggregated failure
- printed failing seed
- bounded timeout
- no endless or extremely large campaign

Provide clear targets such as:

- `make closure`
- `make uvm-closure`
- `make full-regression`

Use better project-consistent names if appropriate.

The full closure regression should include:

- fast directed tests
- conventional random campaign
- all focused UVM tests
- bounded UVM random seed campaign
- assertion/protocol checks
- coverage-bin checks
- lint
- synthesis sanity check

Keep the runtime practical.

## 4. Reproducible synthesis reporting

Add a reproducible Yosys synthesis/report flow for the active 2x4 router.

Create or update scripts and Make targets to report at least:

- top module
- parameter configuration
- synthesized cell count
- major cell categories
- inferred memories or lack thereof
- estimated logic structure where available
- hierarchy summary
- warnings
- synthesis success/failure

Use a clearly documented generic technology-independent Yosys flow unless a real target library is already available.

Do not present generic Yosys cell counts as ASIC area.

If practical, add one FPGA-oriented synthesis estimate using an available Yosys target such as `synth_xilinx`, but only if supported locally and clearly label it as an estimate.

Record the exact tool version and command.

Keep generated detailed reports under `build/`.

Commit only concise human-readable result summaries under `docs/` or an intentional small reports directory.

## 5. Optional performance characterization

Add a small deterministic simulation-based characterization if practical without changing the architecture.

Measure or report:

- minimum packet latency
- latency under no contention
- latency under same-output contention
- impact of output backpressure
- concurrent throughput to different outputs
- accepted architectural head-of-line blocking behavior

Use cycle counts from simulation.

Clearly state the traffic assumptions and packet sizes.

Do not claim real-time frequency, bandwidth, power, or silicon performance from simulation alone.

Skip this section if implementing it would require major verification restructuring.

## 6. Repository and release cleanup

Audit the repository for public release.

Ensure:

- no generated binaries or waveforms are tracked
- no large Codex logs are tracked
- no machine-specific absolute paths are committed
- no private challenge text or confidential material remains
- no stale 1x2 claims remain in current-facing documentation
- the retired FIFO file is either clearly documented, moved to an archive/example location, or removed if truly unused
- script permissions are correct
- setup scripts are idempotent
- a clean checkout can reproduce the documented flows
- `.gitignore` covers generated dependencies and UVM builds

Do not remove useful project history or concise historical reports without reason.

## 7. README finalization

Rewrite or refine the README into a concise portfolio-quality landing page.

It should include:

- project overview
- architecture summary
- why the design is interesting
- supported AXI4-Stream subset
- 2-input/4-output structure
- `tdest` routing
- store-and-forward buffering
- round-robin arbitration
- packet-level locking
- backpressure
- known head-of-line blocking tradeoff
- verification summary
- conventional and UVM verification
- deterministic random regressions
- scoreboard/reference model
- assertions/protocol checks
- measured coverage bins
- synthesis summary
- reproducible setup and commands
- repository structure
- known limitations
- future extensions

Keep planned features clearly separate from implemented features.

Do not overstate AXI compliance, verification closure, synthesis quality, or performance.

## 8. Architecture diagram

Create a simple source-controlled architecture diagram in a reproducible text-based format such as Mermaid.

The diagram should show:

- 2 ingress interfaces
- per-ingress packet buffers
- destination request routing
- 4 independent round-robin arbiters
- packet locks
- 4 output interfaces
- counters/status observation

Embed or link it from the README.

Do not require proprietary diagram tools.

## 9. Results documentation

Update `docs/results.md` with a concise final results section containing:

- tool versions
- conventional tests run
- UVM tests run
- deterministic seed counts
- assertion/checker results
- scenario coverage results
- synthesis summary
- any measured latency/throughput characterization
- known warnings
- limitations

Include exact reproducible commands.

Do not include huge raw logs.

## 10. Final project-state updates

Update:

- `docs/verification-plan.md`
- `docs/development-plan.md`
- `docs/results.md`
- `project/project-status.md`
- `project/milestone-history.md`

Mark implemented items accurately.

List remaining optional future work separately, such as:

- commercial simulator validation
- fuller SVA support
- formal verification
- `tkeep`
- virtual output queues
- cut-through routing
- FPGA implementation
- arbitrary port-count parameterization

Do not leave an active milestone claiming incomplete work if this milestone passes.

## Validation

Run at minimum:

- `scripts/check-repo.sh`
- `make clean`
- `make test`
- `make random`
- `make regression`
- `make uvm-smoke`
- all focused UVM tests
- the bounded UVM seed campaign
- the new full closure regression
- assertion/protocol-check targets
- coverage checks
- reproducible synthesis report target
- `make lint`
- `make synth-check`
- `git diff --check`

Also verify:

- no tracked generated files
- no tracked Codex logs
- no tracked absolute local paths
- all executable shell scripts pass `bash -n`
- a forced conventional failure still returns nonzero
- a forced UVM scoreboard failure still returns nonzero

## Acceptance criteria

- Assertions/checkers cover the main protocol and architectural invariants.
- Essential scenario coverage bins are measured and hit.
- A broader deterministic regression is reproducible and passes.
- All focused UVM tests continue to pass.
- UVM random seeds are reproducible.
- Conventional regressions continue to pass.
- A reproducible Yosys synthesis report exists.
- README and documentation are portfolio-ready and technically honest.
- The architecture diagram is source-controlled and reproducible.
- Generated files and machine-specific paths are excluded.
- No major architecture or UVM redesign occurs.
- No unsupported verification-closure, AXI-compliance, area, timing, or performance claims are made.
- The repository is ready for a public GitHub release.

## Completion report

End with:

- Status
- Milestone
- Summary
- Assertions/checkers added
- Coverage bins and results
- Regression structure and seeds
- UVM results
- Conventional verification results
- Synthesis flow and results
- Performance characterization, if added
- README and documentation changes
- Repository cleanup performed
- RTL or verification bugs found and fixed
- Files added
- Files modified
- Files removed or retired
- Commands run
- Validation results
- Known warnings
- Remaining limitations
- Release-readiness assessment
- Recommended next step

The recommended next step should be either final human review and GitHub release or a very small targeted fix milestone. Do not recommend another large implementation phase unless a serious confirmed defect remains.