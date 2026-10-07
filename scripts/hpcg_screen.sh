#!/bin/bash
# Screening: find correct proc/thread ratio (avoid oversubscription)
B3=~/hpcg-src/build_C3_mpi_omp/bin
B2=~/hpcg-src/build_C2_omp/bin
RT=45

run() { # $1=label $2=dir $3=cmd
  cd "$2" || return 1
  rm -f HPCG-Benchmark*.txt hpcg*.txt
  eval "$3" > /dev/null 2>&1
  f=$(ls -t HPCG-Benchmark*.txt 2>/dev/null | head -1)
  if [ -z "$f" ]; then echo "$1 : NO OUTPUT"; return 1; fi
  gf=$(grep -oP 'rating of=\K[0-9.e+-]+' "$f" | head -1)
  tt=$(grep -oP 'execution time \(sec\) is=\K[0-9.]+' "$f" | head -1)
  mm=$(grep -oP 'data \(Gbytes\)=\K[0-9.]+' "$f" | head -1)
  echo "$1 : GFLOP/s=$gf time=${tt}s mem=${mm}GB"
}

echo "### MPI proc x 1 thread (global 64^3) ###"
run "np1_t1" $B3 "OMP_NUM_THREADS=1 mpirun --oversubscribe --bind-to none -np 1 ./xhpcg --nx=64 --rt=$RT"
run "np8_t1" $B3 "OMP_NUM_THREADS=1 mpirun --oversubscribe --bind-to none -np 8 ./xhpcg --nx=32 --rt=$RT"
echo "### pure OpenMP (global 64^3) ###"
run "np1_t1" $B2 "OMP_NUM_THREADS=1 ./xhpcg --nx=64 --rt=$RT"
run "np1_t2" $B2 "OMP_NUM_THREADS=2 ./xhpcg --nx=64 --rt=$RT"
run "np1_t4" $B2 "OMP_NUM_THREADS=4 ./xhpcg --nx=64 --rt=$RT"
run "np1_t8" $B2 "OMP_NUM_THREADS=8 ./xhpcg --nx=64 --rt=$RT"
echo "### MPI+OMP mixed 2x4 ###"
run "np2_t4" $B3 "OMP_NUM_THREADS=4 mpirun --oversubscribe --bind-to none -np 2 ./xhpcg --nx=32 --rt=$RT"
echo "### done ###"
