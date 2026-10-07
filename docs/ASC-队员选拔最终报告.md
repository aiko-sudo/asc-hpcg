# ASC 队员选拔最终报告

## 一、基本信息

| 项目      | 内容         |
| ------- | ---------- |
| 姓名      |            |
| 年级专业    |            |
| 基础题     | HPCG |
| 大题      |            |
| 基础题仓库链接 |            |
| 大题仓库链接  |            |

## 二、基础题

### 题目与链接

- 选择题目：HPCG（High Performance Conjugate Gradient，高性能共轭梯度基准）
- 题目链接：https://github.com/hpcg-benchmark/hpcg

### 机器环境

| 项目         | 内容                            |
| ---------- | ----------------------------- |
| 机器来源       | 本地电脑 / WSL（Windows 11 Host 上的 WSL2 容器） |
| 操作系统       | Ubuntu 24.04.3 LTS（内核 6.6.87.2-microsoft-standard-WSL2） |
| CPU        | Intel Core Ultra 9 275HX（宿主机 24 核 24 线程 / 2.7 GHz）；WSL 内配额 8 核 |
| 内存         | 宿主机 31.4 GB；WSL 内配额 18 GB（可用约 17 GB） |
| GPU        | NVIDIA GeForce RTX 5070 Laptop 8 GB（HPCG 3.1 为纯 CPU 基准，未参与计算） |
| 编译器        | gcc / g++ 13.3.0（`-O3 -ffast-math -ftree-vectorize`，C++11） |
| MPI        | Open MPI 4.1.6（libopenmpi-dev / mpicxx，单机 `mpirun`） |
| BLAS / 数学库 | 不使用外部 BLAS；HPCG 3.1 自带稀疏内核参考实现（ComputeSPMV_ref / ComputeSYMGS_ref / ComputeMG_ref / ComputeWAXPBY_ref / ComputeDotProduct_ref） |
| 关键依赖版本     | GNU Make 4.3、CMake 3.28.3、glibc 2.39、OpenMP（libgomp，随 gcc 13.3）、HPCG 3.1（2019-03-28 发布版） |

### Baseline 与测试配置

> 所有组均满足官方有效性要求：计时阶段 `rt ≥ 90 s`（主对比组 180 s）、问题规模 192³（约 707 万未知数，占约 5 GB，≥ 内存配额 1/4）。`运行时间` 为 HPCG 报告的计时阶段执行时间（秒），`性能指标` 为官方 HPCG rating（GFLOP/s），`正确性结果` 均为 `VALID`（V&V 测试 PASSED，残差均值 ~3.7e-41）。

| 配置编号 | 运行命令 | 关键参数 | 运行时间 | 性能指标 | 正确性结果 |
| ---- | ---- | ---- | ----:| ----:| ----- |
| 1 | `./xhpcg --nx=192 --rt=180`（串行基线） | 规模 192³，1 进程 × 1 线程，`C1_serial` 配置 | 195.0 s | 2.01 GFLOP/s | VALID |
| 2 | `OMP_NUM_THREADS=8 ./xhpcg --nx=192 --rt=180`（纯 OpenMP） | 规模 192³，1 进程 × 8 线程，`C2_omp` 配置 | 192.5 s | 2.68 GFLOP/s | VALID |
| 3 | `OMP_NUM_THREADS=1 mpirun --oversubscribe --bind-to none -np 8 ./xhpcg --nx=96 --rt=180`（MPI 仅进程） | 规模 192³（局部 96³），8 进程 × 1 线程，`C3_mpi_omp` 配置 | 185.4 s | 6.33 GFLOP/s | VALID |
| 4 | `OMP_NUM_THREADS=2 mpirun --oversubscribe --bind-to core -np 8 ./xhpcg --nx=96 --rt=90`（MPI+OpenMP，最佳） | 规模 192³（局部 96³），8 进程 × 2 线程，`C3_mpi_omp` 配置 | 101.3 s | 6.44 GFLOP/s | VALID |
| 5 | `OMP_NUM_THREADS=4 mpirun --oversubscribe --bind-to core -np 2 ./xhpcg --nx=96 --rt=90`（进程数对比） | 规模 192³（进程分解 2×2×2），2 进程 × 4 线程 | 117.0 s | 3.32 GFLOP/s | VALID |
| 6 | `OMP_NUM_THREADS=1 mpirun --oversubscribe --bind-to none -np 8 ./xhpcg --nx=96 --rt=180` + `-march=native`（编译优化对比） | 规模 192³，8 进程 × 1 线程，`C4_native` 配置 | 190.0 s | 6.18 GFLOP/s | VALID |

> 补充扫描数据（规模 192³，计时 90 s，全部 VALID）：
> - MPI 进程/线程配比：8×2 = 6.44 → 8×1 = 6.29 → 4×2 = 4.99 → 2×4 = 3.32（GFLOP/s）。
> - 纯 OpenMP 线程数：t1 = 1.89 → t2 = 2.56 → t4 = 2.64 → t8 = 2.68（GFLOP/s，收益严重递减）。
> - 线程绑定（8 进程×1 线程）：`none` = 6.21，`core` = 6.29，`socket` 与此相当（差异 ≤ 1.3%）。
> - 问题规模扫描（8 进程×1 线程）：128³ = 6.21，192³ = 6.21，224³ = 6.06（GFLOP/s，基本持平，呈内存带宽受限特征）。

### 基础题结论

**最佳配置：配置 4，即 MPI 8 进程 × 每进程 2 个 OpenMP 线程（`mpirun -np 8` + `OMP_NUM_THREADS=2`，`--bind-to core`），HPCG rating 6.44 GFLOP/s，相对串行基线（配置 1）加速 3.2 倍，相对纯 OpenMP 8 线程（配置 2）提升 2.4 倍。**

判断依据：

1. **性能指标口径统一**：全部 13 组运行均使用官方定义（PCG 迭代阶段加权 GFLOP/s，建题开销按 500 次迭代摊销），取自各组 `hpcg` 结果文件的 `Final Summary::HPCG result is VALID with a GFLOP/s rating of`，可直接横向对比。
2. **正确性全部通过**：所有组 V&V 测试（谱收敛测试、对称性检验、迭代数一致性、可复现性）均为 PASSED，程序报告 `VALID`，说明性能差异不是靠放宽校验换来的。
3. **MPI 明显优于共享内存线程**：多重网格预条件（SYMGS 平滑）是 HPCG 性能瓶颈，其 OpenMP 扩展性差——配置 2 里 MG 内核仅 2.43 GFLOP/s（8 线程 vs 1 线程几乎不缩放），而 MPI 按独立局部网格切分后 MG 内核可达 6.36 GFLOP/s。数据并行度（进程数）是本基准的主要收益来源：进程数 8→4→2，性能依次 6.44→4.99→3.32 显著下滑，而线程 1→8 只带来 2.01→2.68 的提升。
4. **线程绑定与编译优化影响很小**：`--bind-to core` 相对 `none` 提升 ≤ 1.3%；`-march=native` 甚至略降（6.33→6.18），结合规模扫描 128³/192³/224³ 成绩几乎不变，说明在 WSL 环境与 5 GB 数据集下本基准呈内存带宽受限特征，计算指令优化收益有限。
5. **规模满足有效性约束**：主对比组采用 192³（707 万未知数、约 5 GB 双精度数据），超过 WSL 内存配额 18 GB 的 1/4，符合 HPCG 官方对"问题规模应反映真实稀疏迭代求解器需求"的要求。

完整性说明：本实验为课程复现性质，运行时长（90 s / 180 s）低于官方成绩提交下限（1800 s），数字仅用于机内横向对比，不宜与 TOP500 的 HPCG 成绩直接比较；所有原始命令、日志与结果文件均随仓库提交，可复现。

## 三、大题

### 题目理解

- 选择题目：
- 题目链接：
- 大题主要内容：
- 性能目标：
- 正确性判断方式：

### 机器环境

| 项目          | 内容                                    |
| ----------- | ------------------------------------- |
| 机器来源        | 本地电脑 / WSL / 虚拟机 / 自备服务器 / Colab / 其他 |
| 操作系统        |                                       |
| CPU         |                                       |
| 内存          |                                       |
| GPU         |                                       |
| 编译器         |                                       |
| MPI         |                                       |
| Python      |                                       |
| CUDA / ROCm |                                       |
| 关键依赖版本      |                                       |

### Baseline

运行命令：

```bash

```

Baseline 结果：

| 项目    | 内容  |
| ----- | --- |
| 运行时间  |     |
| 性能指标  |     |
| 正确性结果 |     |
| 输出文件  |     |
| 日志文件  |     |

### 性能分析

说明使用了哪些工具或方法进行分析，并给出至少一个有证据支持的结论。

### 优化或工程改进

| 编号  | 修改内容 | 修改原因 | 预期效果 |
| --- | ---- | ---- | ---- |
| 1   |      |      |      |
| 2   |      |      |      |
| 3   |      |      |      |

### 优化后结果

| 实验       | 运行时间 | 性能指标 | 正确性结果 | 说明  |
| -------- | ----:| ----:| ----- | --- |
| Baseline |      |      |       |     |
| 优化后      |      |      |       |     |

### 正确性验证

说明优化后结果如何验证，是否与 Baseline 或官方要求一致。

## 四、遇到的问题和解决方法

| 问题  | 现象  | 解决方法 |
| --- | --- | ---- |
|     |     |      |

## 五、总结

总结基础题和大题的完成情况、有效优化、无效优化、对题目的理解，以及后续还可以继续优化的方向。
