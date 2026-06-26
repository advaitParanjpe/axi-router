# Development Plan

1. Baseline audit.
2. Baseline cleanup and stabilization.
3. Repository and Codex workflow setup.
4. Freeze the 2-input/4-output router architecture.
5. Implement the generalized 2-input/4-output RTL.
6. Directed verification and protocol assertions.
7. UVM environment foundation.
8. Constrained-random verification, functional coverage, and regressions.
9. Synthesis, performance analysis, and refinement.
10. Documentation, GitHub polish, and final release.

## Later Verification Considerations

After the 2x4 architecture is frozen, add reusable source/sink BFMs,
randomized backpressure, reset-during-packet testing, parameter sweeps,
handshake-stability assertions, no-data-loss checks, packet-atomicity checks,
and drop-semantics checks.

These are roadmap items, not Milestone 2 implementation work.
