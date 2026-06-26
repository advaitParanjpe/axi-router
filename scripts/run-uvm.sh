#!/usr/bin/env bash
set -euo pipefail

test_name="${TEST:-axis_router_smoke_test}"
seed="${SEED:-1}"
build_dir="${BUILD_DIR:-build}"
mkdir -p "$build_dir"

log="$build_dir/uvm-${test_name}-seed-${seed}.log"

uvm_pkg_path="${UVM_PKG:-}"
if [[ -z "$uvm_pkg_path" ]]; then
  uvm_pkg_path="$(find /opt /usr /Applications "$HOME" -maxdepth 5 -iname uvm_pkg.sv 2>/dev/null | head -1 || true)"
fi

{
  echo "UVM test: $test_name"
  echo "Seed: $seed"
  echo "Simulator assessment:"
  command -v iverilog >/dev/null 2>&1 && iverilog -V 2>&1 | head -1 || true
  command -v verilator >/dev/null 2>&1 && verilator --version || true
  command -v yosys >/dev/null 2>&1 && yosys -V || true
  if [[ -z "$uvm_pkg_path" ]]; then
    echo "BLOCKED: no local uvm_pkg.sv was found. Icarus is retained for conventional tests but does not provide validated UVM execution here."
    exit 2
  fi
  echo "Selected UVM package: $uvm_pkg_path"
  echo "BLOCKED: an executable UVM simulator flow has not been validated for this host."
  exit 2
} | tee "$log"
