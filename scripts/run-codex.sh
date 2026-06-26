#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/run-codex.sh [--allow-dirty] [--] [extra Codex prompt text]

Runs Codex from the repository root using repository context files. By default,
the script refuses to run when the Git working tree has uncommitted changes.
Use --allow-dirty to override that guard.
USAGE
}

allow_dirty=0
extra_prompt=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --allow-dirty)
      allow_dirty=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      extra_prompt=("$@")
      break
      ;;
    *)
      extra_prompt+=("$1")
      shift
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"
REPO_ROOT="$(pwd -P)"

CODEX_TMPDIR="$REPO_ROOT/build/tmp"
mkdir -p "$CODEX_TMPDIR"
export TMPDIR="$CODEX_TMPDIR"

required_files=(
  "AGENTS.md"
  "README.md"
  "docs/development-plan.md"
  "docs/architecture.md"
  "docs/verification-plan.md"
  "docs/decisions.md"
  "project/project-status.md"
  "project/current-milestone.md"
)

for path in "${required_files[@]}"; do
  if [[ ! -f "${path}" ]]; then
    echo "ERROR: required context file missing: ${path}" >&2
    exit 1
  fi
done

if ! command -v codex >/dev/null 2>&1; then
  echo "ERROR: codex command is unavailable on PATH." >&2
  exit 127
fi

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git_root_raw="$(git rev-parse --show-toplevel)"
  git_root="$(cd "${git_root_raw}" && pwd -P)"
  repo_root_phys="$(pwd -P)"
  git_root_cmp="$(printf '%s' "${git_root}" | tr '[:upper:]' '[:lower:]')"
  repo_root_cmp="$(printf '%s' "${repo_root_phys}" | tr '[:upper:]' '[:lower:]')"
  if [[ "${git_root_cmp}" != "${repo_root_cmp}" ]]; then
    echo "ERROR: Git root is ${git_root_raw}, expected ${REPO_ROOT}." >&2
    exit 1
  fi

  if [[ "${allow_dirty}" -eq 0 ]] && [[ -n "$(git status --porcelain)" ]]; then
    echo "ERROR: Git working tree is dirty. Commit/stash changes or pass --allow-dirty." >&2
    git status --short
    exit 1
  fi
else
  echo "ERROR: ${REPO_ROOT} is not initialized as a Git repository." >&2
  exit 1
fi

LOG_DIR="${REPO_ROOT}/build/codex-logs"
mkdir -p "${LOG_DIR}"
timestamp="$(date '+%Y%m%d-%H%M%S')"
log_file="${LOG_DIR}/codex-${timestamp}.log"

prompt="Read AGENTS.md. Read all context files required by AGENTS.md. Execute project/current-milestone.md only. Run required validation. Update status/history files. End with the structured completion report required by AGENTS.md."

if [[ "${#extra_prompt[@]}" -gt 0 ]]; then
  prompt="${prompt} Extra user note: ${extra_prompt[*]}"
fi

set +e
codex \
  --ask-for-approval never \
  --sandbox workspace-write \
  exec \
  -C "${REPO_ROOT}" \
  "${prompt}" 2>&1 | tee "${log_file}"

status=${PIPESTATUS[0]}
set -e

echo "Codex log: ${log_file}"
exit "${status}"
