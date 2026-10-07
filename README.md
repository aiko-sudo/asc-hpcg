# ASC 队员选拔 · 基础题 HPCG 实验仓库

本仓库为 ASC 队员选拔最终报告「基础题 HPCG」的完整支撑材料：
提供编译配置、运行命令、原始结果、运行日志与机器环境快照，确保可复现性，并与报告逐项对应。

## 1. 题目

- 题目：HPCG（High Performance Conjugate Gradient Benchmark）
- 官网/源码：https://github.com/hpcg-benchmark/hpcg（revision 3.1，2019-03-28 发布）
- 目标：在本地环境编译运行 HPCG，调整（问题规模 / MPI 进程数 / OpenMP 线程数 / 线程绑定 / 编译优化）至少 3 组配置，对比性能并总结最优配置。

## 2. 机器环境

- 机器来源：本地 Windows 11 主机上的 WSL2 容器（Ubuntu 24.04.3 LTS）
- 宿主机 CPU：Intel Core Ultra 9 275HX（24 核 / 24 线程，2.7 GHz）；**WSL 配额 8 核**
- 宿主机内存：31.4 GB；**WSL 配额 18 GB**
- GPU：NVIDIA GeForce RTX 5070 Laptop 8 GB（HPCG 3.1 为纯 CPU 基准，未参与计算）
- 编译器：gcc / g++ 13.3.0（Ubuntu 24.04 默认）
- MPI：Open MPI 4.1.6（mpicxx）
- 数学库：不使用外部 BLAS，HPCG 自带稀疏内核参考实现
- 关键依赖：GNU Make 4.3、CMake 3.28.3、glibc 2.39、libgomp
- 环境快照原始文件见 `env/`（lscpu / free / /proc/meminfo / os-release / uname / 工具链版本）

## 3. 源码与编译

从 GitHub 获取 HPCG 3.1 源码，本仓库保留 4 份编译器配置：

| 配置 | 文件 | 说明 |
| --- | --- | --- |
| C1 | `setup/Make.C1_serial` | 串行（无 MPI、无 OpenMP），`-O3 -ffast-math -ftree-vectorize` |
| C2 | `setup/Make.C2_omp` | OpenMP（1 进程 × 多线程），同优化参数 |
| C3 | `setup/Make.C3_mpi_omp` | MPI + OpenMP 混合，同优化参数 |
| C4 | `setup/Make.C4_native` | 在 C3 基础上加 `-march=native` |

编译方式（HPCG 官方 make 流程）：

```bash
git clone https://github.com/hpcg-benchmark/hpcg.git && cd hpcg
cp <本仓库>/setup/Make.Cx_yyy setup/Make.Cx_yyy
# 或使用官方 configure 独立构建目录：
mkdir -p build_C3 && cd build_C3
../configure C3_mpi_omp && make
# 产物：bin/xhpcg
```

## 4. 运行命令与结果对照

统一对照表（更多细节见 `logs/` 与 `results/`；`.out` 为运行日志，`.txt` 为 HPCG 结果文件，文件名即运行名）：

| 运行名 | 对应报告配置 | 命令要点 | 规模 | 进程×线程 | 计时(s) | GFLOP/s | VALID |
| --- | --- | --- | --- | --- | --- | --- | --- |
| A1_C1_serial_np1_t1 | 配置 1（串行基线） | `./xhpcg --nx=192 --rt=180` | 192³ | 1×1 | 195.0 | 2.01 | ✓ |
| A2_C2_omp_np1_t8 | 配置 2（纯 OpenMP） | `OMP_NUM_THREADS=8 ./xhpcg --nx=192 --rt=180` | 192³ | 1×8 | 192.5 | 2.68 | ✓ |
| A3_C3_mpi_np8_t1 | 配置 3（MPI 8×1） | `OMP_NUM_THREADS=1 mpirun -np 8 ./xhpcg --nx=96 --rt=180` | 192³ | 8×1 | 185.4 | 6.33 | ✓ |
| A4_C4_native_np8_t1 | 配置 6（+march=native） | `OMP_NUM_THREADS=1 mpirun -np 8 ./xhpcg --nx=96 --rt=180`（C4 编译） | 192³ | 8×1 | 190.0 | 6.18 | ✓ |
| B1_mpi_np8_t1_none | 绑定对比 none | `--bind-to none` | 192³ | 8×1 | 104.9 | 6.21 | ✓ |
| B2_mpi_np8_t1_core | 绑定对比 core | `--bind-to core` | 192³ | 8×1 | 103.7 | 6.29 | ✓ |
| B3_mpi_np8_t2_core | **配置 4（最佳）** | `OMP_NUM_THREADS=2 mpirun --bind-to core -np 8 ./xhpcg --nx=96 --rt=90` | 192³ | 8×2 | 101.3 | **6.44** | ✓ |
| B4_mpi_np4_t2_core | 进程数 4 | `--bind-to core -np 4`，`OMP_NUM_THREADS=2` | 192³ | 4×2 | 104.0 | 4.99 | ✓ |
| B5_mpi_np2_t4_core | 配置 5（进程数 2） | `--bind-to core -np 2`，`OMP_NUM_THREADS=4` | 192³ | 2×4 | 117.0 | 3.32 | ✓ |
| C_omp_t1 | 线程扫描 t1 | `OMP_NUM_THREADS=1 ./xhpcg --nx=192 --rt=90` | 192³ | 1×1 | 138.3 | 1.89 | ✓ |
| C_omp_t2 | 线程扫描 t2 | `OMP_NUM_THREADS=2` | 192³ | 1×2 | 102.0 | 2.56 | ✓ |
| C_omp_t4 | 线程扫描 t4 | `OMP_NUM_THREADS=4` | 192³ | 1×4 | 98.3 | 2.64 | ✓ |
| D_g128_local64 | 规模 128³ | `mpirun -np 8 ./xhpcg --nx=64 --rt=90` | 128³ | 8×1 | 86.5 | 6.21 | ✓ |
| D_g224_local112 | 规模 224³ | `mpirun -np 8 ./xhpcg --nx=112 --rt=90` | 224³ | 8×1 | 102.6 | 6.06 | ✓ |

> 说明：所有运行均通过 HPCG V&V（谱收敛 / 对称性 / 迭代一致性 / 可复现性，结果 VALID）。
> 计时阶段 90 s / 180 s 低于官方提交下限 1800 s，属课程复现性质，仅作机内横向对比。

## 5. 复现步骤

```bash
# 1) 环境（Ubuntu 22.04+/24.04 均可）
sudo apt-get install -y build-essential libopenmpi-dev openmpi-bin cmake git

# 2) 获取源码并放入本仓库 setup 配置
git clone https://github.com/hpcg-benchmark/hpcg.git && cd hpcg
cp <repo>/setup/Make.* setup/

# 3) 编译（示例：C3）
mkdir -p build_C3 && cd build_C3 && ../configure C3_mpi_omp && make && cd ..

# 4) 运行（示例：最佳配置 8×2）
cd build_C3/bin
OMP_NUM_THREADS=2 mpirun --oversubscribe --bind-to core -np 8 ./xhpcg --nx=96 --rt=90

# 5) 一键复现全部矩阵
bash <repo>/scripts/hpcg_final.sh   # 自动重编四配置并运行全部 13 组，产出见 logs/results
bash <repo>/scripts/collect_env.sh  # 重新采集本机环境快照到 env/
```

## 6. 目录结构

```
├── setup/           4 份编译器配置（C1 串行 / C2 OpenMP / C3 MPI+OMP / C4 native）
├── scripts/         hpcg_final.sh（全矩阵复现）、collect_env.sh（环境采集）、
│                    hpcg_screen.sh / hpcg_probe.sh（规模与配比预扫）
├── results/         14 份 HPCG 结果文件（*.txt，含 rating / 校验 / 内存）
├── logs/            15 个运行日志（*.out + progress.log，含完整命令回显）
└── env/             机器环境快照（lscpu / free / os-release / uname / 工具链）
```

## 7. 与报告对应关系

| 报告章节 | 本仓库对应 |
| --- | --- |
| 机器环境 | `env/` 原始快照 + README §2 |
| Baseline 与测试配置（表） | README §4 对照表 + `results/` |
| 运行命令 | `logs/*.out` 顶部 + README §4 |
| 正确性（VALID） | 各 `results/*.txt` 的 `HPCG result is VALID` |
| 基础题结论（最佳配置 8×2，6.44 GFLOP/s） | `results/B3_mpi_np8_t2_core.txt` |