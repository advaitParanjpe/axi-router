# Decision Records

## DR-001: Protocol Target

Decision: The project targets AXI4-Stream, not AXI4 memory-mapped or AXI4-Lite.

Rationale: The inherited design and intended packet-router behavior are stream
oriented.

## DR-002: Eventual Router Shape

Decision: The eventual portfolio target is 2 ingress ports and 4 egress ports.

Rationale: This is large enough to demonstrate routing, arbitration,
backpressure, verification, and parameterization without becoming a full NoC.

## DR-003: Inherited 1x2 Baseline

Decision: The inherited 1x2 implementation does not need to remain as a
permanent legacy implementation.

Rationale: This repository is already a copy, so the current RTL can evolve
toward the 2x4 target after its architecture is frozen.

## DR-004: Development Order

Decision: Housekeeping and architecture specification precede major RTL
expansion.

Rationale: A stable workflow and frozen specification reduce churn before
generalizing the design.

## DR-005: UVM Timing

Decision: UVM is a core learning and portfolio objective, but it begins after
the RTL architecture and conventional baseline verification are stable.

Rationale: UVM is most useful when the design contract is clear enough to build
agents, sequences, a reference model, and coverage intentionally.
