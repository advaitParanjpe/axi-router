# Milestone 3 — Freeze the 2x4 AXI4-Stream Router Architecture

## Objective

Define and freeze the architecture and externally observable behaviour of the generalized AXI4-Stream packet router before implementation begins.

This milestone is specification and planning only.

Do not modify synthesizable RTL, existing testbenches, assertions, BFMs, UVM components, filelists, or regression functionality except where a trivial documentation-path correction is required.

The current implemented design remains the stabilized 1-input/2-output baseline throughout this milestone.

## Target direction

The intended next implementation is a portfolio-quality AXI4-Stream packet router with:

- 2 ingress ports
- 4 egress ports
- destination-based packet routing
- independent arbitration for each output
- round-robin fairness
- packet-level arbitration locking
- no packet interleaving
- correct AXI4-Stream backpressure
- parameterized widths and buffering
- later SystemVerilog assertion and UVM verification

The architecture must remain controlled enough to implement, verify, synthesize, document, and finish to a high standard.

## Required work

### 1. Inspect existing context

Before editing documentation, read:

- `AGENTS.md`
- `README.md`
- `docs/architecture.md`
- `docs/verification-plan.md`
- `docs/development-plan.md`
- `docs/decisions.md`
- `docs/results.md`
- `project/project-status.md`
- `project/milestone-history.md`
- `project/current-milestone.md`
- current RTL and testbench files as needed to understand the inherited baseline

Do not assume planned features already exist.

### 2. Produce a frozen architecture specification

Expand `docs/architecture.md` into a precise implementation specification for the generalized router.

The specification must define the following.

#### Interface

Define the supported AXI4-Stream subset:

- `tdata`
- `tvalid`
- `tready`
- `tlast`
- `tdest`

Explicitly define:

- signal directions and array organization for all ingress and egress ports
- parameter names and legal ranges
- data width
- destination width
- number of ingress ports
- number of egress ports
- FIFO depth or packet-capacity parameters
- synchronous active-high reset behaviour
- which AXI4-Stream optional signals are intentionally unsupported

Do not claim full AXI4-Stream compliance. Describe the implemented subset precisely.

#### Packet and destination semantics

Specify:

- when `tdest` is sampled
- whether `tdest` must remain constant throughout a packet
- whether the router checks destination consistency on later beats
- mapping between legal `tdest` values and output ports
- handling of invalid or out-of-range destinations
- handling of malformed packets
- handling of packets that exceed configured storage capacity
- handling of a reset during packet reception or transmission
- whether zero-length packets are meaningful
- whether partial final beats are supported without `tkeep`

#### Buffering architecture

Select and document the buffering architecture.

The preferred controlled design is:

- one packet-capable FIFO or packet buffer per ingress
- no permanent legacy 1x2 datapath
- no virtual output queues
- no cut-through mode in the first generalized version

Confirm or revise this only with a clear justification.

Specify:

- whether a packet must be fully received before becoming eligible for arbitration
- whether packet metadata is stored separately
- how packet boundaries are represented internally
- how fullness and packet admission are determined
- whether a packet is accepted beat-by-beat and later dropped, or rejected through backpressure before overflow
- consequences of the chosen design, including head-of-line blocking

Clearly document any head-of-line blocking as a known architectural tradeoff rather than hiding it.

#### Routing and arbitration

Specify:

- how each buffered ingress advertises a request to an output
- that each output has an independent arbiter
- round-robin priority rules
- reset value of arbitration priority
- when priority advances
- whether priority advances only after a completed packet transfer
- how simultaneous requests are resolved
- how an output locks ownership to one ingress for the complete packet
- how ownership is released
- how output stalls affect ownership
- proof-level invariants such as:
  - at most one ingress drives a given output
  - one ingress packet cannot be sent to multiple outputs
  - packet beats cannot interleave on an output
  - arbitration cannot change midway through a packet

#### Backpressure and concurrency

Specify:

- when each ingress asserts `tready`
- when each egress asserts `tvalid`
- stability requirements while `tvalid` is asserted and `tready` is low
- whether both ingress ports may be accepted concurrently
- whether different outputs may transmit concurrently
- what happens when both inputs request the same output
- what happens when each input requests a different output
- interaction between output stalls and unrelated outputs
- known head-of-line blocking behaviour

#### Counters and status

Define a controlled status/counter set.

At minimum consider:

- accepted packet count per ingress
- forwarded packet count per output
- dropped packet count per ingress or by reason
- optional arbitration-contention or stall counts

Specify:

- exact increment events
- counter widths
- overflow behaviour
- reset behaviour

Avoid adding a large control/status bus in this project phase. Counters may remain direct output signals or internal observability points if that is simpler.

#### Parameterization

Define legal and intentionally unsupported configurations.

The default target must remain 2 ingress ports and 4 egress ports.

Decide whether the implementation will be genuinely parameterized for ingress and egress counts or whether only widths and depths will be parameterized.

Do not promise arbitrary parameterization unless the planned RTL and verification can realistically support it.

Define safe minimum values and any elaboration-time checks.

### 3. Record architecture decisions

Update `docs/decisions.md` with concise decision records covering at least:

- supported AXI4-Stream subset
- use of `tdest`
- selected buffering placement
- store-and-forward versus cut-through
- round-robin arbitration
- packet-level output locking
- invalid-destination handling
- oversize-packet handling
- reset-during-packet behaviour
- head-of-line blocking acceptance
- supported parameterization scope
- whether `tkeep` is omitted from the first generalized implementation

Each decision should include:

- decision
- rationale
- consequences
- status

Mark frozen decisions clearly.

### 4. Refine the verification plan

Update `docs/verification-plan.md` so it maps directly onto the frozen architecture.

Define planned verification categories, including:

- interface protocol behaviour
- packet integrity
- destination routing
- simultaneous independent transfers
- same-output contention
- round-robin fairness
- packet lock and no interleaving
- randomized output backpressure
- ingress backpressure
- invalid destinations
- oversize packets
- malformed destination changes within a packet
- reset while idle
- reset during packet capture
- reset during output transmission
- minimum and boundary parameter cases
- counter correctness
- sustained randomized traffic

Identify the future UVM components that will be required:

- ingress agents
- egress agents or passive monitors with ready-driving capability
- transactions and sequences
- configuration object
- reference model
- scoreboard
- functional coverage
- assertions
- virtual sequences
- regression organization

Do not implement them.

Define high-level coverage goals and functional coverpoints without claiming coverage closure.

### 5. Define implementation decomposition

In `docs/architecture.md` or a concise dedicated section of `docs/development-plan.md`, define the expected RTL module decomposition.

Consider modules such as:

- generalized top-level router
- ingress packet buffer/FIFO
- per-output round-robin arbiter
- optional shared package for types and parameter calculations
- counter/status logic

For each proposed module, state its responsibility and important interface behaviour.

Avoid unnecessary module fragmentation.

### 6. Update roadmap and project status

Update `docs/development-plan.md` only as necessary to reflect the now-frozen architecture and likely implementation sequence.

Update `project/project-status.md` to state:

- Milestone 3 specification status
- that the current executable RTL is still the 1x2 baseline
- that the 2x4 architecture is frozen but not yet implemented
- major selected architecture decisions
- immediate next implementation objective

Append Milestone 3 to `project/milestone-history.md`.

Do not mark generalized RTL or UVM work as complete.

### 7. Consistency review

Check all project Markdown files for contradictions.

In particular, ensure consistency around:

- AXI4-Stream rather than AXI4 or AXI4-Lite
- 2x4 target
- supported sideband signals
- routing mechanism
- buffering location
- arbitration policy
- packet-level locking
- invalid and oversize packet handling
- reset semantics
- current implementation status versus future planned status

Remove stale statements that conflict with frozen decisions, but do not erase useful Milestone 1 historical information.

## Validation

Run:

- `scripts/check-repo.sh`
- `make test`
- `make lint`
- `make synth-check`

The RTL should remain unchanged, and all existing validation should continue to pass.

Optionally use a Markdown link or consistency checker if already installed, but do not add a large dependency solely for this milestone.

Review `git diff` to confirm this milestone contains documentation and project-status changes only.

## Acceptance criteria

- The 2-input/4-output router has an unambiguous frozen architecture.
- Supported and unsupported AXI4-Stream signals are explicit.
- Packet, destination, invalid-input, overflow, and reset behaviour are defined.
- Buffering and packet admission rules are defined.
- Round-robin arbitration and packet locking rules are precise.
- Backpressure and concurrency behaviour are defined.
- Head-of-line blocking is acknowledged and bounded by the architecture.
- Parameterization scope is realistic and explicit.
- Planned RTL module boundaries are documented.
- Verification requirements map directly to architecture features and risks.
- Existing RTL and verification functionality are unchanged.
- Existing regression, lint, and synthesis checks still pass.
- Project status clearly distinguishes frozen specification from implemented functionality.
- No UVM implementation begins during this milestone.

## Completion report

End with:

- Status
- Milestone
- Summary
- Frozen architecture decisions
- Supported interface
- Buffering model
- Arbitration and packet-locking model
- Invalid, oversize, and reset behaviour
- Parameterization scope
- Documentation updated
- Commands run
- Validation results
- Remaining architecture risks
- Recommended next milestone

The recommended next milestone should implement the generalized 2-input/4-output RTL and focused conventional SystemVerilog tests. It should not begin the full UVM environment yet.