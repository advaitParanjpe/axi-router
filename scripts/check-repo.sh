#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"
REPO_ROOT="$(pwd -P)"

fail=0

required_files=(
  "AGENTS.md"
  "README.md"
  "Makefile"
  ".gitignore"
  "docs/architecture.md"
  "docs/verification-plan.md"
  "docs/development-plan.md"
  "docs/decisions.md"
  "docs/results.md"
  "project/current-milestone.md"
  "project/project-status.md"
  "project/milestone-history.md"
  "scripts/run-codex.sh"
  "scripts/check-repo.sh"
)

required_dirs=(
  "rtl"
  "tb"
  "docs"
  "filelists"
  "project"
  "scripts"
)

for path in "${required_files[@]}"; do
  if [[ ! -f "${path}" ]]; then
    echo "MISSING file: ${path}" >&2
    fail=1
  fi
done

for path in "${required_dirs[@]}"; do
  if [[ ! -d "${path}" ]]; then
    echo "MISSING directory: ${path}" >&2
    fail=1
  fi
done

generated_found="$(find rtl tb docs filelists project scripts -type f \( \
  -name '*.vvp' -o -name '*.vcd' -o -name '*.fst' -o -name '*.log' -o \
  -name '*.out' -o -name '.DS_Store' \) -print)"
if [[ -n "${generated_found}" ]]; then
  echo "Generated files found in source/documentation directories:" >&2
  echo "${generated_found}" >&2
  fail=1
fi

for script in scripts/*.sh reports/*.sh; do
  if [[ -f "${script}" ]]; then
    bash -n "${script}"
  fi
done

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git_root_raw="$(git rev-parse --show-toplevel)"
  git_root="$(cd "${git_root_raw}" && pwd -P)"
  repo_root_phys="$(pwd -P)"
  git_root_cmp="$(printf '%s' "${git_root}" | tr '[:upper:]' '[:lower:]')"
  repo_root_cmp="$(printf '%s' "${repo_root_phys}" | tr '[:upper:]' '[:lower:]')"
  if [[ "${git_root_cmp}" != "${repo_root_cmp}" ]]; then
    echo "Git root mismatch: ${git_root_raw} (expected ${REPO_ROOT})" >&2
    fail=1
  fi
  echo "Git status:"
  git status --short
else
  echo "Git repository not initialized."
fi

if [[ ! -f Makefile ]]; then
  fail=1
else
  for target in test lint synth-check; do
    if ! grep -Eq "^${target}:" Makefile; then
      echo "Make target not found: ${target}" >&2
      fail=1
    fi
  done
fi

if ! command -v make >/dev/null 2>&1; then
  echo "make command not found on PATH" >&2
  fail=1
fi

if [[ "${fail}" -ne 0 ]]; then
  echo "Repository check failed." >&2
  exit 1
fi

echo "Repository check passed."
