#!/usr/bin/env bash
set -euo pipefail

test_name="${TEST:-axis_router_smoke_test}"
seed="${SEED:-1}"
build_dir="${BUILD_DIR:-build}"
uvm_home="${UVM_HOME:-$build_dir/deps/uvm}"
uvm_pkg="${UVM_PKG:-$uvm_home/src/uvm_pkg.sv}"
uvm_inc="${UVM_INC:-$uvm_home/src}"
uvm_dpi="${UVM_DPI:-$uvm_home/src/dpi/uvm_dpi.cc}"
verilator="${VERILATOR:-verilator}"
build_jobs="${UVM_BUILD_JOBS:-0}"
include_reg_model="${UVM_INCLUDE_REG_MODEL:-0}"
include_hdl_dpi="${UVM_INCLUDE_HDL_DPI:-0}"
repo_root="$(pwd)"
if [[ -z "${TMPDIR:-}" ]]; then
  export TMPDIR="$repo_root/$build_dir/tmp"
fi

test_build_dir="$build_dir/uvm/${test_name}/seed-${seed}"
obj_dir="$test_build_dir/obj_dir"
log_suffix="${FORCE_UVM_SCOREBOARD_ERROR:+-forced}"
log="$build_dir/uvm-${test_name}-seed-${seed}${log_suffix}.log"
exe="$obj_dir/Vtb_axis_router_uvm"
uvm_pkg_for_build="$uvm_pkg"
dpi_for_build="$uvm_dpi"
compat_inc="$test_build_dir/compat"
compat_inc_abs="$repo_root/$compat_inc"
uvm_dpi_inc_abs="$repo_root/$uvm_home/src/dpi"

mkdir -p "$TMPDIR" "$test_build_dir" "$compat_inc" "$(dirname "$log")"

if [[ ! -f "$uvm_pkg" || ! -f "$uvm_inc/uvm_macros.svh" || ! -f "$uvm_dpi" ]]; then
  echo "ERROR: UVM dependency is missing. Run scripts/setup-uvm.sh first." | tee "$log"
  echo "Expected package: $uvm_pkg" | tee -a "$log"
  echo "Expected include dir: $uvm_inc" | tee -a "$log"
  echo "Expected DPI source: $uvm_dpi" | tee -a "$log"
  exit 2
fi

cat > "$compat_inc/malloc.h" <<'EOF_MALLOC_H'
#ifndef AXIS_ROUTER_UVM_COMPAT_MALLOC_H
#define AXIS_ROUTER_UVM_COMPAT_MALLOC_H
#include <stdlib.h>
#endif
EOF_MALLOC_H

if [[ "$include_hdl_dpi" != "1" ]]; then
  dpi_for_build="$test_build_dir/uvm_dpi_no_hdl.cc"
  cat > "$dpi_for_build" <<'EOF_UVM_DPI'
#include <stdlib.h>
#include <string.h>
#include <vector>
#include <string>
#include "verilated.h"

static std::vector<std::string> axis_router_uvm_args;

#ifdef __cplusplus
extern "C" {
#endif

#include "uvm_dpi.h"

int uvm_re_match(const char * re, const char *str);
const char * uvm_glob_to_re(const char *glob);
extern char* uvm_dpi_get_tool_name_c ();
extern char* uvm_dpi_get_tool_version_c ();
extern regex_t* uvm_dpi_regcomp (char* pattern);
extern int uvm_dpi_regexec (regex_t* re, char* str);
extern void uvm_dpi_regfree (regex_t* re);

#include "uvm_common.c"
#include "uvm_regex.cc"

static void axis_router_add_plusarg(const char* prefix) {
  const char* match = Verilated::commandArgsPlusMatch(prefix);
  if (match != NULL && match[0] != '\0') axis_router_uvm_args.push_back(match);
}

const char *uvm_dpi_get_next_arg_c(int init) {
  static size_t idx = 0;
  if (init == 1) {
    axis_router_uvm_args.clear();
    axis_router_add_plusarg("UVM_TESTNAME=");
    axis_router_add_plusarg("UVM_VERBOSITY=");
    axis_router_add_plusarg("ntb_random_seed=");
    axis_router_add_plusarg("SEED=");
    axis_router_add_plusarg("FORCE_UVM_SCOREBOARD_ERROR");
    idx = 0;
  }
  if (idx >= axis_router_uvm_args.size()) return NULL;
  return axis_router_uvm_args[idx++].c_str();
}

char* uvm_dpi_get_tool_name_c() {
  return const_cast<char*>(Verilated::productName());
}

char* uvm_dpi_get_tool_version_c() {
  return const_cast<char*>(Verilated::productVersion());
}

regex_t* uvm_dpi_regcomp(char* pattern) {
  regex_t* re = (regex_t*) malloc(sizeof(regex_t));
  int status = regcomp(re, pattern, REG_NOSUB|REG_EXTENDED);
  if (status) {
    regfree(re);
    free(re);
    return NULL;
  }
  return re;
}

int uvm_dpi_regexec(regex_t* re, char* str) {
  if (!re) return 1;
  return regexec(re, str, (size_t)0, NULL, 0);
}

void uvm_dpi_regfree(regex_t* re) {
  if (!re) return;
  regfree(re);
  free(re);
}

#ifdef __cplusplus
}
#endif
EOF_UVM_DPI
fi

if [[ "$include_reg_model" != "1" ]]; then
  uvm_pkg_for_build="$test_build_dir/uvm_pkg_no_reg.sv"
  cat > "$uvm_pkg_for_build" <<'EOF_UVM_PKG'
`ifndef UVM_PKG_SV
`define UVM_PKG_SV

`include "uvm_macros.svh"

package uvm_pkg;
  `include "dpi/uvm_dpi.svh"
  `include "base/uvm_base.svh"
  `include "dap/uvm_dap.svh"
  `include "tlm1/uvm_tlm.svh"
  `include "comps/uvm_comps.svh"
  `include "seq/uvm_seq.svh"
  `include "tlm2/uvm_tlm2.svh"
endpackage

`endif
EOF_UVM_PKG
fi

set +e
{
  echo "UVM test: $test_name"
  echo "Seed: $seed"
  echo "Verilator: $($verilator --version)"
  echo "UVM package: $uvm_pkg"
  echo "UVM package used for build: $uvm_pkg_for_build"
  echo "UVM include dir: $uvm_inc"
  echo "UVM DPI source: $uvm_dpi"
  echo "UVM DPI source used for build: $dpi_for_build"
  echo "UVM include register model: $include_reg_model"
  echo "UVM include HDL DPI: $include_hdl_dpi"
  echo "Compatibility include dir: $compat_inc"
  echo "Build jobs: $build_jobs"
  if [[ -d "$uvm_home/.git" ]]; then
    echo "UVM source URL: $(git -C "$uvm_home" config --get remote.origin.url)"
    echo "UVM revision: $(git -C "$uvm_home" rev-parse HEAD)"
  fi
  echo "Build dir: $test_build_dir"
  echo "Compiling..."
  "$verilator" \
    --binary \
    --build-jobs "$build_jobs" \
    --timing \
    --assert \
    +define+UVM_HDL_NO_DPI \
    -Wno-DECLFILENAME \
    -Wno-PINCONNECTEMPTY \
    -Wno-TIMESCALEMOD \
    -Wno-WIDTH \
    -Wno-UNOPTFLAT \
    --top-module tb_axis_router_uvm \
    --Mdir "$obj_dir" \
    -CFLAGS "-I$compat_inc_abs -I$uvm_dpi_inc_abs" \
    +incdir+"$uvm_inc" \
    +incdir+tb/uvm \
    "$uvm_pkg_for_build" \
    "$dpi_for_build" \
    -f filelists/rtl.f \
    -f filelists/tb_uvm.f
  echo "Running..."
  "$exe" \
    +UVM_TESTNAME="$test_name" \
    +ntb_random_seed="$seed" \
    +SEED="$seed" \
    ${FORCE_UVM_SCOREBOARD_ERROR:+ +FORCE_UVM_SCOREBOARD_ERROR}
} 2>&1 | tee "$log"
status=${PIPESTATUS[0]}
set -e
if [[ $status -ne 0 ]]; then
  exit "$status"
fi
if grep -Eq "UVM_(FATAL|ERROR) :[[:space:]]*[1-9]" "$log"; then
  echo "UVM reported errors or fatals; treating test as failed"
  exit 1
fi
