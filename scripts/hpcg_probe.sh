#!/bin/bash
# Probe: memory + setup time for global 192^3 (validity needs >=1/4 of 18GB = 4.5GB)
B3=~/hpcg-src/build_C3_mpi_omp/bin
probe() { # label dir np threads nx
  cd "$2" || return 1
  rm -f HPCG-Benchmark*.txt hpcg*.txt
  S=$(date +%s)
  OMP_NUM_THREADS=$4 mpirun --oversubscribe --bind-to none -np $3 ./xhpcg --nx=$5 --rt=10 > /dev/null 2>&1
  E=$(date +%s)
  f=$(ls -t HPCG-Benchmark*.txt 2>/dev/null | head -1)
  [ -z "$f" ] && { echo "$1 : NO OUTPUT (wall $((E-S))s)"; return 1; }
  m=$(grep -oP 'data \(Gbytes\)=\K[0-9.]+' "$f" | head -1)
  g=$(grep -oP 'rating of=\K[0-9.e+-]+' "$f" | head -1)
  v=$(grep -oP 'HPCG result is \K\w+' "$f" | head -1)
  eq=$(grep -oP 'Number of Equations=\K[0-9]+' "$f" | head -1)
  echo "$1 : wall=$((E-S))s mem=${m}GB eq=$eq rating=$g result=$v"
}
echo "### global 192^3 candidates (8 proc -> local 96) ###"
probe "np8_t1_local96" $B3 8 1 96
echo "### np4 -> local 96x96x192 needs 3D split; use nx=96 npz=2 ###"
probe "np4_t2_local96" $B3 4 2 96
echo "### serial at same global size: np1 local 192 (=global 192^3) ###"
probe "np1_t1_local192" $B3 1 1 192
echo "### free check ###"
free -m | head -2
