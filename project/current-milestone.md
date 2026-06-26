# Current Milestone: Milestone 2

## Objective

Establish permanent repository structure, documentation, Git hygiene, and Codex
workflow support for the AXI4-Stream router project.

## Scope

Housekeeping only. Do not make meaningful RTL, microarchitecture, testbench,
assertion, or verification-feature changes.

## Required Validation

- `bash -n scripts/run-codex.sh`
- `bash -n scripts/check-repo.sh`
- `scripts/check-repo.sh`
- `make test`
- `make lint`
- `make synth-check`

## Completion Requirements

- Keep `project/project-status.md` factual and current.
- Append Milestone 2 to `project/milestone-history.md`.
- Provide the structured completion report required by `AGENTS.md`.
