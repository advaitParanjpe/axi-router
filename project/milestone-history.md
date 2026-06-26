# Milestone History

## Milestone 0 - Inherited-Repository Audit

Outcome: Established the baseline facts for the inherited project. Confirmed it
was a 1-input, 2-output AXI4-Stream subset router with fixed first-byte-LSB
routing, store-and-forward buffering, per-output FIFOs, directed tests, and
historical synthesis artifacts.

## Milestone 1 - Baseline Cleanup and Stabilization

Outcome: Added root build commands, filelists, `.gitignore`, optional waveform
generation, parameter-focused directed tests, Verilator-clean RTL, and Yosys
parse/elaboration/check compatibility while preserving externally visible 1x2
router behavior.

## Milestone 2 - Repository, Documentation, Git, and Codex Workflow Setup

Outcome: Added permanent project context documents, stable Codex instructions,
project status tracking, milestone history, Git hygiene, and repository helper
scripts. No meaningful RTL or verification-feature changes were made.
