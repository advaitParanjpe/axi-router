# Decision Records

## DR-001: Protocol Target

Decision: The project targets AXI4-Stream, not AXI4 memory-mapped or AXI4-Lite.

Rationale: The inherited design and intended packet-router behavior are stream
oriented.

Consequences: No AXI4 memory-mapped or AXI4-Lite control/status interface is
planned for the first generalized implementation.

Status: Frozen.

## DR-002: Router Shape

Decision: The portfolio target is 2 ingress ports and 4 egress ports.

Rationale: This is large enough to demonstrate routing, arbitration,
backpressure, verification, and parameterization without becoming a full NoC.

Consequences: The first generalized RTL will be designed and verified for this
fixed structural shape.

Status: Frozen.

## DR-003: Inherited 1x2 Baseline

Decision: The inherited 1x2 implementation remained the executable baseline
only until the generalized router was implemented. It was not a permanent
legacy datapath requirement.

Rationale: The repository is already a copy, so the current RTL can evolve
toward the 2x4 target after the architecture is frozen.

Consequences: Milestone 4 replaced the active top-level RTL behavior with the
generalized 2x4 implementation and retired the inherited 1x2 datapath from the
active filelist.

Status: Implemented by Milestone 4.

## DR-004: Supported AXI4-Stream Subset

Decision: The generalized router supports `tdata`, `tvalid`, `tready`, `tlast`,
and `tdest`.

Rationale: These signals are sufficient for packet payload transfer, packet
boundaries, backpressure, and destination-based routing.

Consequences: The design will describe an AXI4-Stream subset only and will not
claim full AXI4-Stream compliance.

Status: Frozen.

## DR-005: Destination Routing Uses `tdest`

Decision: `tdest` is sampled on the first accepted packet beat and maps values
0 through 3 directly to outputs 0 through 3.

Rationale: Using `tdest` avoids encoding routing policy in payload bytes and
matches the intended generalized packet-router behavior.

Consequences: Values greater than 3 are invalid for the 4-output design and
packets with invalid destinations are dropped rather than remapped.

Status: Frozen.

## DR-006: Buffering Placement

Decision: The generalized router uses one packet-capable ingress buffer per
ingress port and no virtual output queues.

Rationale: Per-ingress packet buffers are straightforward to implement and
verify for the first 2x4 version.

Consequences: Head-of-line blocking is accepted when an ingress head packet is
waiting for a stalled or contended output.

Status: Frozen.

## DR-007: Store-and-Forward Operation

Decision: The generalized router is store-and-forward. A packet must be fully
received and classified before it can request an output.

Rationale: Full-packet buffering simplifies destination validation, malformed
packet handling, packet-level arbitration, and no-interleaving guarantees.

Consequences: The first generalized implementation will not provide cut-through
latency. Buffer capacity limits maximum accepted packet length.

Status: Frozen.

## DR-008: Round-Robin Arbitration

Decision: Each output has an independent round-robin arbiter over ingress
requests targeting that output.

Rationale: Independent arbiters allow unrelated outputs to transfer
concurrently while providing deterministic fairness under same-output
contention.

Consequences: Priority resets to ingress 0 and advances only after a granted
packet completes on that output.

Status: Frozen.

## DR-009: Packet-Level Output Locking

Decision: Once an output grants an ingress, ownership is locked until the
packet's `tlast` beat is accepted by that output.

Rationale: Packet-level locking prevents packet interleaving and makes
scoreboard and assertion requirements clear.

Consequences: Output stalls hold the lock. Arbitration cannot switch owners
mid-packet.

Status: Frozen.

## DR-010: Invalid-Destination Handling

Decision: Packets whose first accepted `tdest` value is outside 0 through 3 are
consumed, dropped, and counted.

Rationale: Dropping invalid destinations avoids ambiguous routing and keeps the
interface contract explicit.

Consequences: Invalid packets are not forwarded to any output and no error
sideband is added in this phase.

Status: Frozen.

## DR-011: Oversize-Packet Handling

Decision: Packets exceeding `INGRESS_MAX_PKT_BEATS` are consumed through
`tlast`, dropped, and counted.

Rationale: Forwarding truncated packets would violate packet integrity.

Consequences: Oversize packet data after capacity is reached is not stored for
forwarding. The ingress remains occupied until the oversize packet terminates.

Status: Frozen.

## DR-012: Malformed `tdest` Changes

Decision: `tdest` must remain constant throughout a packet. A later beat whose
`tdest` differs from the sampled first-beat value makes the packet malformed.

Rationale: Packet-level routing needs one stable destination per packet.

Consequences: Malformed packets are consumed through `tlast`, dropped, and
counted.

Status: Frozen.

## DR-013: Reset During Packet Activity

Decision: Synchronous active-high reset aborts packet capture and packet
transmission, clears buffers, releases locks, resets arbiters, and clears
counters.

Rationale: A simple reset contract is easier to implement and verify than
attempting to preserve partial packets across reset.

Consequences: The router does not guarantee completion of a packet interrupted
by reset.

Status: Frozen.

## DR-014: Parameterization Scope

Decision: The first generalized implementation fixes the structural shape at 2
ingress ports and 4 egress ports, while parameterizing data width, destination
width, ingress packet capacity, and counter width.

Rationale: Arbitrary port-count parameterization would expand the implementation
and verification state space before the 2x4 architecture is proven.

Consequences: Elaboration-time checks must reject unsupported ingress or egress
counts if they are exposed as parameters.

Status: Frozen.

## DR-015: `tkeep` Omission

Decision: `tkeep` is omitted from the first generalized implementation.

Rationale: Omitting byte qualifiers keeps packet storage, comparisons, and
scoreboarding focused on core routing and arbitration behavior.

Consequences: All bytes of every beat are treated as meaningful, and partial
final beats are unsupported.

Status: Frozen.

## DR-016: UVM Timing

Decision: UVM is a core learning and portfolio objective, but it begins after
the generalized RTL and focused conventional verification are stable.

Rationale: UVM is most useful when the design contract is clear enough to build
agents, sequences, a reference model, and coverage intentionally.

Consequences: Milestone 3 defines future UVM needs but does not implement UVM
components.

Status: Frozen.
