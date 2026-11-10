#!/usr/bin/env bash

# Maryana Pyzh <maryana.pyzh@irvmic.com> INNOVA IRV Microelectronics, S.L.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
build_dir="$(mktemp -d)"
trap 'rm -rf "$build_dir"' EXIT

cd "$repo_root"
if ! verilator --binary --timing --assert -Wno-fatal \
  --top-module tb_xif_wrapper_v1 \
  --Mdir "$build_dir" \
  +incdir+pkg \
  +define+XIF_ID_WIDTH_CFG=5 \
  pkg/cvxif_instr_pkg.sv \
  pkg/cvxif_v1_pkg.sv \
  pkg/if_xif_exe.sv \
  tb/tb_wrapper/fifo_v3.sv \
  rtl/instr_predecoder/instr_predecoder.sv \
  rtl/xif_wrapper.sv \
  tb/tb_wrapper/tb_xif_wrapper_v1.sv \
  "$@" >"$build_dir/build.log" 2>&1; then
  cat "$build_dir/build.log" >&2
  exit 1
fi
"$build_dir/Vtb_xif_wrapper_v1" +verilator+quiet | sed '/: Verilog \$finish$/d'
