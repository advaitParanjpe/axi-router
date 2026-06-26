# Milestone 4 — Implement the Generalized 2x4 AXI4-Stream Router RTL

## Objective

Implement the frozen 2-input/4-output AXI4-Stream packet-router architecture and verify its core behaviour with focused conventional SystemVerilog tests.

The implementation must follow the frozen specification in:

- `docs/architecture.md`
- `docs/decisions.md`
- `docs/verification-plan.md`

Do not begin the full UVM environment in this milestone.

The inherited 1-input/2-output RTL does not need to remain as a permanent legacy datapath. It may be refactored, replaced, or removed once the generalized implementation and regressions are working.

## Required context

Before making changes, read:

- `AGENTS.md`
- `README.md`
- `docs/architecture.md`
- `docs/decisions.md`
- `docs/verification-plan.md`
- `docs/development-plan.md`
- `project/project-status.md`
- `project/milestone-history.md`
- all current RTL, testbench, filelist, and build files

Treat the frozen architecture documentation as authoritative. Do not silently change a frozen decision to simplify implementation.

If a genuine contradiction exists, document it clearly and make the smallest defensible correction before continuing.

## Required implementation

### 1. Generalized top-level router

Implement the fixed structural target:

- 2 AXI4-Stream ingress ports
- 4 AXI4-Stream egress ports
- supported signals:
  - `tdata`
  - `tvalid`
  - `tready`
  - `tlast`
  - `tdest`
- synchronous active-high reset

Use clear packed or unpacked SystemVerilog arrays where supported by the project’s tools.

Keep the externally visible interface unambiguous and practical for later UVM connection.

The implementation must be synthesizable.

### 2. Supported parameters

Implement the frozen parameterization scope only:

- data width
- destination width
- ingress packet-buffer capacity
- counter width

The first generalized implementation remains structurally fixed at 2 ingress ports and 4 egress ports.

Do not claim arbitrary port-count parameterization.

Add safe elaboration-time checks for illegal parameter values without breaking Yosys parsing or synthesis.

Avoid zero-width vectors, unsafe casts, implicit truncation, and parameter-derived indexing hazards.

### 3. Ingress packet buffers

Implement one packet-capable store-and-forward buffer per ingress.

Each ingress buffer must:

- capture one complete packet before that packet becomes eligible for output arbitration
- retain packet data, `tlast`, and required destination metadata
- sample the packet destination according to the frozen specification
- detect changing `tdest` within a packet
- detect packets exceeding the configured capacity
- consume and drop malformed, invalid-destination, and oversize packets
- prevent a partially captured packet from becoming visible to an output
- support independent simultaneous packet capture on both ingress ports
- apply correct input backpressure based on buffer and drop-state behaviour

Do not add cut-through forwarding or virtual output queues.

A buffer holding a completed packet must not accept another packet until its current packet has been forwarded or discarded, unless the frozen documentation explicitly permits otherwise.

### 4. Destination routing

Map legal destination values to the four outputs exactly as specified.

Packets with invalid or out-of-range destinations must:

- never assert valid packet data on an output
- be fully consumed from the ingress interface
- be discarded atomically
- increment the appropriate drop counter exactly once

A packet with `tdest` changing after its first accepted beat must be classified as malformed and must not be forwarded.

Clearly define the precedence if a packet is both malformed and oversize. Avoid double-counting one packet as multiple drops unless the frozen specification explicitly requires separate counters.

### 5. Per-output arbitration

Implement one independent arbiter for each output.

Each output arbiter must:

- observe requests from both ingress packet buffers
- grant at most one ingress
- use round-robin arbitration when both ingresses request the same output
- initialize priority according to the frozen specification
- advance priority only after a packet completes successfully on that output
- preserve priority while idle or stalled unless otherwise specified
- allow different outputs to operate concurrently

An ingress packet must request exactly one output.

### 6. Packet-level output locking

Once an output begins forwarding a packet:

- lock the output to the granted ingress
- preserve ownership through output backpressure
- keep output data, `tlast`, and destination stable whenever `tvalid=1` and `tready=0`
- do not switch ingress ownership between packet beats
- release the lock only when the final beat transfers with `tvalid && tready && tlast`

Packet beats from different ingresses must never interleave on one output.

One ingress packet must never be transmitted to multiple outputs.

### 7. Backpressure and concurrency

Implement and test the specified behaviour for:

- both ingresses capturing packets concurrently
- both outputs or multiple outputs transmitting concurrently
- ingresses targeting different outputs
- both ingresses contending for the same output
- one stalled output while unrelated outputs continue operating
- prolonged output backpressure
- held `tvalid` with stable payload during stalls
- head-of-line blocking caused by the selected ingress-buffer architecture

Do not introduce unnecessary global stalls.

### 8. Reset behaviour

Synchronous active-high reset must:

- clear ingress capture and completed-packet state
- abort partially captured packets
- abort packets currently being transmitted
- clear output locks
- reset arbitration priority
- clear counters
- leave outputs deasserted after reset
- return ingress interfaces to the documented post-reset state

Add focused testing for reset:

- while idle
- during ingress capture
- while an output packet is stalled
- during active packet transmission

Do not attempt to preserve in-flight packets across reset.

### 9. Counters and status

Implement the frozen counter set from `docs/architecture.md`.

At minimum, implement the documented equivalents of:

- accepted packet count per ingress
- forwarded packet count per output
- dropped packet count per ingress or specified drop category

Counters must:

- increment on the exact documented event
- increment once per packet rather than once per beat
- clear on reset
- use the configured width
- use the documented overflow behaviour

Do not add a control/status bus.

### 10. RTL decomposition

Use the frozen or recommended module decomposition without excessive fragmentation.

Expected responsibilities may include:

- generalized top-level router
- reusable ingress packet buffer
- per-output round-robin arbiter
- optional package for shared types and safe width calculations

Keep arbitration, packet storage, and forwarding responsibilities understandable.

Remove or retire inherited modules only when no longer used and only after the generalized regression passes.

### 11. Focused conventional SystemVerilog verification

Add a self-checking conventional SystemVerilog testbench or small set of testbenches.

Use transaction-level helper tasks or lightweight source/sink helpers where useful, but do not build the full reusable UVM environment yet.

The tests must independently check packet contents, ordering, routing, drop behaviour, counters, and packet boundaries.

At minimum cover:

#### Basic routing

- ingress 0 to each of outputs 0–3
- ingress 1 to each of outputs 0–3
- single-beat packets
- multi-beat packets

#### Concurrency

- simultaneous packets from both ingresses to different outputs
- concurrent transmission on different outputs
- one output stalled while another continues

#### Contention and fairness

- both ingresses targeting the same output
- deterministic initial winner
- repeated contention demonstrating round-robin alternation
- packet-level locking during multi-beat transfers
- no interleaving under randomized backpressure

#### Error and drop behaviour

- invalid destination
- changing `tdest` within a packet
- oversize packet
- packet exactly at configured capacity
- packet following a dropped packet
- correct drop-counter behaviour
- no output leakage from dropped packets

#### Reset

- reset while idle
- reset during packet capture
- reset while an output is stalled
- clean recovery and successful traffic after reset

#### Boundary and parameter cases

At minimum exercise:

- default data width
- another legal data width
- packet-buffer capacity of 1 if supported by the frozen specification
- small counter width sufficient to observe documented overflow behaviour, if practical

Randomized backpressure may be implemented with deterministic seeds.

All tests must:

- be self-checking
- terminate with a nonzero exit status on failure
- avoid source/DUT clock-edge races
- avoid relying only on internal DUT signals
- place generated artifacts under `build/`
- keep waveform dumping optional

### 12. Assertions

Do not create the complete assertion library yet, but add a small number of high-value local assertions where straightforward and tool-compatible.

Prioritize properties or immediate checks for:

- output payload stability while stalled
- no output valid from multiple ingresses simultaneously
- lock cannot change mid-packet
- completed packet requests only legal output indices
- no ingress packet drives multiple outputs

Keep simulation-only assertions synthesis-safe and compatible with the existing toolchain.

If full concurrent SVA support is limited under Icarus, place assertions in a separate file or use guarded forms and document which simulator validates them.

Do not weaken synthesis compatibility merely to add assertions in this milestone.

### 13. Build and regression integration

Update:

- RTL filelists
- testbench filelists
- Makefile targets
- cleanup rules
- README command descriptions

Provide one clear regression command through `make test`.

Retain:

- `make lint`
- `make synth-check`
- `make clean`

Ensure the primary lint and synthesis targets operate on the new generalized top level.

Do not leave obsolete RTL accidentally included in synthesis.

### 14. Documentation and project state

Update documentation only to reflect implementation facts.

Update:

- `README.md`
- `docs/results.md`
- `project/project-status.md`
- `project/milestone-history.md`

Record:

- what is now implemented
- what was tested
- current limitations
- whether the inherited 1x2 implementation was removed
- exact reproducible commands
- remaining verification gaps

Do not claim UVM, coverage closure, formal proof, or reproducible Vivado results.

## Validation

Run at minimum:

- `scripts/check-repo.sh`
- `make clean`
- `make test`
- `make lint`
- `make synth-check`
- `git diff --check`

Run individual focused tests where useful for debugging.

Review the final source filelists and synthesis hierarchy to confirm the generalized 2x4 router is the active design.

## Acceptance criteria

- The active synthesizable design is the frozen 2-input/4-output AXI4-Stream subset router.
- Legal `tdest` values route packets to the correct output.
- Both ingress ports can capture traffic concurrently.
- Different outputs can transmit concurrently.
- Same-output contention uses deterministic round-robin arbitration.
- Output ownership is locked for the full packet.
- Packet beats never interleave on an output.
- Backpressure preserves stable output payload and ownership.
- Invalid, malformed, and oversize packets are consumed, dropped, and counted as specified.
- Reset aborts in-flight state and allows clean subsequent operation.
- Counters increment exactly as documented.
- Focused self-checking tests cover routing, concurrency, contention, fairness, stalls, drops, boundaries, and reset.
- Verilator reports no meaningful RTL warnings.
- Yosys parses, elaborates, and checks the generalized design.
- Generated artifacts remain under `build/`.
- No UVM environment is added.
- Documentation distinguishes implemented functionality from future verification work.

## Completion report

End with:

- Status
- Milestone
- Summary
- Architecture implemented
- RTL modules added, modified, removed, or retired
- Interface and parameters
- Buffering behaviour
- Arbitration and locking behaviour
- Drop and reset behaviour
- Counters implemented
- Verification added
- Files changed
- Commands run
- Validation results
- Known limitations
- Remaining verification risks
- Recommended next milestone

The recommended next milestone should strengthen conventional verification with reusable AXI-Stream interfaces/BFMs, protocol assertions, and broader randomized regressions before building the full UVM environment.