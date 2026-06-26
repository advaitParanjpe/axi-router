# Codex Instructions

- Work only within this repository.
- Before modifying files, read: `README.md`, `docs/development-plan.md`,
  `docs/architecture.md`, `docs/verification-plan.md`, `docs/decisions.md`,
  `project/project-status.md`, and `project/current-milestone.md`.
- Treat `project/current-milestone.md` as the only active implementation
  assignment. Do not implement future roadmap items unless that file explicitly
  requests them.
- Preserve supported behavior unless the active milestone explicitly changes the
  specification.
- Clearly distinguish confirmed facts from assumptions.
- Avoid unsupported claims about AXI compliance, synthesis results,
  verification closure, or tool support.
- Keep synthesizable RTL separate from simulation-only code.
- Use explicit, robust SystemVerilog parameter sizing and avoid unsafe
  zero-width constructs.
- Run the validation commands required by the current milestone.
- Never hide meaningful warnings merely to obtain a clean tool result.
- Keep generated outputs under `build/` or another documented generated-artifact
  directory.
- After completing a milestone, update `project/project-status.md` and append a
  concise entry to `project/milestone-history.md`.
- Do not rewrite the roadmap unless the milestone explicitly requests it.
- End every run with: status, milestone, summary, files added, files modified,
  files removed or renamed, commands run, validation results, known limitations,
  remaining risks, and recommended next step.
