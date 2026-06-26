#!/usr/bin/env bash
set -euo pipefail

repo_url="${UVM_REPO_URL:-https://github.com/chipsalliance/uvm-verilator.git}"
repo_ref="${UVM_REPO_REF:-uvm-2017-1.1}"
repo_revision="${UVM_REPO_REVISION:-02da9d0e20062f15fe75363bebcc31246422c2c2}"
build_dir="${BUILD_DIR:-build}"
deps_dir="${UVM_DEPS_DIR:-$build_dir/deps}"
uvm_dir="${UVM_HOME:-$deps_dir/uvm}"

mkdir -p "$deps_dir"

if [[ -d "$uvm_dir/.git" ]]; then
  current_url="$(git -C "$uvm_dir" config --get remote.origin.url || true)"
  current_revision="$(git -C "$uvm_dir" rev-parse HEAD || true)"
  if [[ "$current_url" != "$repo_url" ]]; then
    echo "ERROR: $uvm_dir exists with remote '$current_url', expected '$repo_url'" >&2
    exit 1
  fi
  if [[ "$current_revision" != "$repo_revision" ]]; then
    git -C "$uvm_dir" fetch --tags --depth 1 origin "$repo_ref"
    git -C "$uvm_dir" checkout --detach FETCH_HEAD
  fi
elif [[ -e "$uvm_dir" ]]; then
  echo "ERROR: $uvm_dir exists but is not a git checkout" >&2
  exit 1
else
  git clone --depth 1 --branch "$repo_ref" "$repo_url" "$uvm_dir"
fi

uvm_pkg="$uvm_dir/src/uvm_pkg.sv"
uvm_include="$uvm_dir/src"

if [[ ! -f "$uvm_pkg" ]]; then
  echo "ERROR: expected UVM package not found: $uvm_pkg" >&2
  exit 1
fi

if [[ ! -f "$uvm_include/uvm_macros.svh" ]]; then
  echo "ERROR: expected UVM include directory is incomplete: $uvm_include" >&2
  exit 1
fi

revision="$(git -C "$uvm_dir" rev-parse HEAD)"

if [[ "$revision" != "$repo_revision" ]]; then
  echo "ERROR: UVM checkout is at '$revision', expected '$repo_revision'" >&2
  exit 1
fi

echo "UVM source URL: $repo_url"
echo "UVM requested ref: $repo_ref"
echo "UVM pinned revision: $revision"
echo "UVM local path: $uvm_dir"
echo "UVM package: $uvm_pkg"
echo "UVM include dir: $uvm_include"
