#!/bin/bash
# Build all four HPCG configurations using out-of-source configure+make
# Usage: bash build_all.sh [hpcg-source-dir]
set -eu

SRC="${1:-/home/aiko/hpcg-src}"
[ -d "$SRC" ] || { echo "ERROR: source dir not found: $SRC"; exit 1; }

for a in C1_serial C2_omp C3_mpi_omp C4_native; do
  rm -rf "$SRC/build_$a"
  mkdir -p "$SRC/build_$a"
  echo "=== building $a ==="
  ( cd "$SRC/build_$a" && "$SRC/configure" "$a" > /dev/null 2>&1 && make -j4 > /dev/null 2>&1 )
  if [ -x "$SRC/build_$a/bin/xhpcg" ]; then
    echo "  $a : OK -> $SRC/build_$a/bin/xhpcg"
  else
    echo "  $a : FAILED"
  fi
done