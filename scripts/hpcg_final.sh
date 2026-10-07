#!/bin/bash
# ============================================================
# HPCG 3.1 benchmark matrix  (Ultra 9 275HX via WSL2: 8 cores / 18 GB)
# Fixed: compiler flags except C4; global size per block
# ============================================================
SRC=/home/aiko/hpcg-src
OUT=/home/aiko/hpcg_results
RT_MAIN=180
RT_SUB=90
mkdir -p $OUT
LOG=$OUT/progress.log
: > $LOG
say() { echo "$@" | tee -a $LOG; }

# ---------- rebuild all four configs ----------
for a in C1_serial C2_omp C3_mpi_omp C4_native; do
  rm -rf $SRC/build_$a
  mkdir -p $SRC/build_$a
  (cd $SRC/build_$a && $SRC/configure $a > /dev/null 2>&1 && make -j4 > /dev/null 2>&1)
  if [ -x $SRC/build_$a/bin/xhpcg ]; then say "build $a : OK"; else say "build $a : FAILED"; fi
done
say "----"

# ---------- helper ----------
RUN() { # $1 label $2 dir $3 np $4 threads $5 local-dims(e.g. "96 96 96") $6 rt $7 bind
  local L=$1 DIR=$2 NP=$3 TH=$4 DIMS=$5 RT=$6 BIND=$7
  local args=""
  set -- $DIMS
  args="--nx=$1 --ny=$2 --nz=$3"
  cd $DIR/bin || { say "$L : cd fail"; return; }
  rm -f HPCG-Benchmark*.txt hpcg*.txt
  local start=$(date +%s)
  if ldd ./xhpcg 2>/dev/null | grep -q libmpi; then
    OMP_NUM_THREADS=$TH mpirun --oversubscribe --bind-to $BIND -np $NP ./xhpcg $args --rt=$RT > $OUT/${L}.out 2>&1
  else
    OMP_NUM_THREADS=$TH ./xhpcg $args --rt=$RT > $OUT/${L}.out 2>&1
  fi
  local wall=$(( $(date +%s) - start ))
  local f=$(ls -t HPCG-Benchmark*.txt 2>/dev/null | head -1)
  if [ -z "$f" ]; then say "$L : NO RESULT (wall ${wall}s) -- see $OUT/${L}.out"; return; fi
  cp "$f" $OUT/${L}.txt
  local g=$(grep -oP 'rating of=\K[0-9.eE+-]+' "$f" | head -1)
  local v=$(grep -oP 'HPCG result is \K\w+' "$f" | head -1)
  local m=$(grep -oP 'Total memory used for data \(Gbytes\)=\K[0-9.]+' "$f" | head -1)
  local eq=$(grep -oP 'Number of Equations=\K[0-9]+' "$f" | head -1)
  local st=$(grep -oP 'Setup Information::Setup Time=\K[0-9.]+' "$f" | head -1)
  local tt=$(grep -oP 'execution time \(sec\) is=\K[0-9.]+' "$f" | head -1)
  local bw=$(grep -oP 'Raw Total B/W=\K[0-9.]+' "$f" | head -1)
  local spmv=$(grep -oP 'GFLOP/s Summary::Raw SpMV=\K[0-9.]+' "$f" | head -1)
  local mg=$(grep -oP 'GFLOP/s Summary::Raw MG=\K[0-9.]+' "$f" | head -1)
  local dot=$(grep -oP 'GFLOP/s Summary::Raw DDOT=\K[0-9.]+' "$f" | head -1)
  local wax=$(grep -oP 'GFLOP/s Summary::Raw WAXPBY=\K[0-9.]+' "$f" | head -1)
  say "$L : GFLOP/s=$g VALID=$v timed=${tt}s wall=${wall}s mem=${m}GB eq=$eq setup=${st}s bw=${bw}GB/s | SpMV=$spmv MG=$mg DOT=$dot WAXPBY=$wax"
}

say "=== A. MAIN MATRIX  global 192^3, rt=${RT_MAIN}s ==="
RUN A1_C1_serial_np1_t1   $SRC/build_C1_serial  1 1 "192 192 192" $RT_MAIN none
RUN A2_C2_omp_np1_t8      $SRC/build_C2_omp     1 8 "192 192 192" $RT_MAIN none
RUN A3_C3_mpi_np8_t1      $SRC/build_C3_mpi_omp 8 1  "96 96 96"   $RT_MAIN none
RUN A4_C4_native_np8_t1   $SRC/build_C4_native  8 1  "96 96 96"   $RT_MAIN none

say "=== B. MPI-INTERNAL VARIATION  global 192^3, rt=${RT_SUB}s ==="
RUN B1_mpi_np8_t1_none     $SRC/build_C3_mpi_omp 8 1 "96 96 96"   $RT_SUB none
RUN B2_mpi_np8_t1_core     $SRC/build_C3_mpi_omp 8 1 "96 96 96"   $RT_SUB core
RUN B3_mpi_np8_t2_core     $SRC/build_C3_mpi_omp 8 2 "96 96 96"   $RT_SUB core
RUN B4_mpi_np4_t2_core     $SRC/build_C3_mpi_omp 4 2 "96 96 192"  $RT_SUB core
RUN B5_mpi_np2_t4_core     $SRC/build_C3_mpi_omp 2 4 "96 192 192" $RT_SUB core

say "=== C. THREAD COUNT SWEEP (pure OpenMP)  global 192^3, rt=${RT_SUB}s ==="
RUN C_omp_t1 $SRC/build_C2_omp 1 1 "192 192 192" $RT_SUB none
RUN C_omp_t2 $SRC/build_C2_omp 1 2 "192 192 192" $RT_SUB none
RUN C_omp_t4 $SRC/build_C2_omp 1 4 "192 192 192" $RT_SUB none

say "=== D. SCALE SWEEP (C3 np8 t1) rt=${RT_SUB}s ==="
RUN D_g128_local64  $SRC/build_C3_mpi_omp 8 1 "64 64 64"   $RT_SUB none
RUN D_g224_local112 $SRC/build_C3_mpi_omp 8 1 "112 112 112" $RT_SUB none

say "=== ALL DONE ==="
date >> $LOG
