#!/bin/bash
# Collect machine environment info for the report
envdir="/mnt/d/Documents/qwen-agent/l44XrhQk5F/default/hpcg_results/env"
mkdir -p "$envdir"

lscpu > "$envdir/cpuinfo_lscpu.txt" 2>&1
nproc > "$envdir/cpuinfo_nproc.txt" 2>&1
free -g > "$envdir/memory_free.txt" 2>&1
cat /proc/meminfo | head -5 >> "$envdir/memory_free.txt"
head -5 /etc/os-release > "$envdir/os_release.txt"
uname -a > "$envdir/kernel_uname.txt"

{
  gcc --version | head -1
  g++ --version | head -1
  mpirun --version 2>/dev/null | head -1
  mpicc --version 2>/dev/null | head -1
  make --version | head -1
  /bin/bash --version | head -1
} > "$envdir/toolchain_gcc.txt"

grep -m1 "model name" /proc/cpuinfo >> "$envdir/cpuinfo_lscpu.txt" 2>&1

echo "=== env files ==="
ls "$envdir"
echo "=== lscpu head ==="
head -30 "$envdir/cpuinfo_lscpu.txt"