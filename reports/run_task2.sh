#!/usr/bin/env bash
set -euo pipefail

# Always run from task2 root (script lives in reports/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TASK2_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${TASK2_DIR}"

OUT_DIR="build"
SIM_VVP="${OUT_DIR}/sim.vvp"
SIM_LOG="${OUT_DIR}/sim.log"
VCD="${OUT_DIR}/tb_axis_pkt_router.vcd"

mkdir -p "${OUT_DIR}"

echo "[1/4] Cleaning old build outputs..."
rm -f "${SIM_VVP}" "${SIM_LOG}" "${VCD}"

echo "[2/4] Compiling..."
iverilog -g2012 -o "${SIM_VVP}" \
  rtl/axis_fifo_sync.sv \
  rtl/axis_pkt_router.sv \
  tb/tb_axis_pkt_router.sv

echo "[3/4] Running simulation..."
# Capture console output to a log for the reviewer
vvp "${SIM_VVP}" +WAVES +WAVE_FILE="${VCD}" | tee "${SIM_LOG}"

echo "[4/4] Checking waveform..."
if [[ -f "${VCD}" ]]; then
  ls -lh "${VCD}"
else
  echo "ERROR: VCD not found at ${VCD}"
  echo "TB likely wrote it elsewhere. Check your TB's \$dumpfile() path."
  exit 1
fi

echo "Open manually with a waveform viewer if needed:"
echo "  surfer ${VCD}"
echo "  gtkwave ${VCD}"
