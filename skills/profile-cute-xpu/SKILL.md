---
name: profile-cute-xpu
description: Profile and analyze CuTe/SYCL*TLA kernels on Intel XPU/GPU, especially Intel Xe/BMG/Xe20/Xe35 GEMM-style kernels using CuTe primitives such as XE_DPAS_TT, XE_LOAD_2D, XE_LOAD_2D_VNNI, XE_LOAD_2D_TRANSPOSE, XE_PREFETCH_2D, XE_STORE_2D, TiledMMAHelper, and PipelineStages. Use when Codex needs to build a profiling workflow, run Intel PTI unitrace or VTune, interpret timing or hardware counters, diagnose compute-bound vs bandwidth-bound behavior, tune CuTe tile shapes, subgroup layout, prefetch depth, GRF pressure, SLM use, reorder overhead, 2D block alignment, XMX utilization, or write a profiling report for Intel XPU kernels.
---

# Profile CuTe Kernels on Intel XPU

Use this skill to profile CuTe/SYCL*TLA kernels on Intel GPUs and turn timing, `unitrace`, or VTune data into concrete CuTe tuning actions.

## Start Here

1. Identify the target executable and the shortest representative command that runs the kernel long enough for profiling.
2. Confirm the kernel is built for Intel SYCL with a matching target, for example `-DCUTLASS_ENABLE_SYCL=ON` and `-DDPCPP_SYCL_TARGET=intel_gpu_bmg_g21`.
3. Run baseline correctness and in-app timing first. Many SYCL*TLA examples already expose `--iterations=<N>` and print throughput using `GPU_Clock`.
4. Run hardware profiling in passes:
   - Timing: `unitrace -d -v -o timing.csv <app> [args]`
   - Broad counters: `unitrace -k -g ComputeBasic -i 25 -o metrics_basic.csv [--include-kernels "<name>"] <app> [args]`
   - Stalls: `unitrace -k -g VectorEngineStalls -i 25 -o metrics_stalls.csv [--include-kernels "<name>"] <app> [args]`
   - Memory, on BMG when available: `unitrace -k -g MemoryProfile -i 25 -o metrics_memory.csv [--include-kernels "<name>"] <app> [args]`
5. Map the bottleneck back to CuTe knobs: tile shape, subgroup layout, `PipelineStages`, 2D block copy atom selection, reorder cost, GRF pressure, SLM use, and alignment.

Always set `ZE_FLAT_DEVICE_HIERARCHY=FLAT` before `unitrace` metric collection.

## Bundled Helpers

- Run `scripts/check_cute_xpu_env.sh` to check for `unitrace`, `icpx`, Level Zero tools, GPU devices, and useful environment variables.
- Run `scripts/profile_cute_kernel.sh --app "<command>" --out profile_results --mode overview` to collect timing and common metric passes. Use `--kernel "<kernel-name>"` after the timing pass reveals the exact kernel name.
- Read `references/cute-xpu-profiling.md` when deciding which counters to collect, how to interpret symptoms, or which CuTe tuning knob to adjust.

## Profiling Decisions

- If the user only needs "how fast is it", use the example's built-in `--iterations` timing or `unitrace -d -v`.
- If the user asks why it is slow, collect `ComputeBasic` and compare measured TFLOPS or bandwidth to hardware peak.
- If XVE/XMX active is low, inspect memory counters, prefetch depth, tile reuse, and 2D block load issue overhead.
- If stall is high, collect `VectorEngineStalls` and classify SBID, SendWr, barrier, or instruction bottlenecks.
- If runtime worsens after increasing tile size or `PipelineStages`, check for GRF spill, lower occupancy, SLM spill, and excessive live copy fragments.
- If correctness fails or results are silently wrong, check `sub_group_size<16>`, 2D block alignment, store height limits, and matrix padding/stride requirements before chasing performance.

## CuTe-Specific Analysis Rules

- Treat `Shape<_256, _256, _32>` with `PipelineStages = 2` as the BF16/BMG baseline unless the repository code indicates a different known-good configuration.
- Treat Intel Xe subgroups as fixed at 16 lanes. A CuTe kernel using `XE_DPAS_TT` must launch with `sycl::ext::oneapi::experimental::sub_group_size<16>`.
- Watch GRF pressure whenever increasing M, N, K, subgroup count, or prefetch depth. Xe large GRF mode is commonly requested with `intel::grf_size<256>`.
- Prefer global-memory 2D block loads directly into GRF for standard GEMM. Consider SLM only when the source kernel deliberately shares tiles between subgroups, exceeds 2D block limits, or has an explicit double-buffered SLM pipeline.
- Account for `reorder(src, dst)`: it is free only when copy and MMA fragment layouts match; otherwise it is a real register shuffle.
- For B operands in BF16/FP16/INT8 GEMM, verify the code uses VNNI-friendly copy paths such as `XE_LOAD_2D_VNNI` or repository helper APIs that select them.

## Report Format

When producing a profiling report, include:

```markdown
## Profiling Report - <kernel or executable>

Date: <YYYY-MM-DD>
GPU: <device name>
Compiler: <icpx version>
Command: `<app> [args]`

### Summary
- Built-in timing: <time or TFLOPS>
- unitrace timing: <hot kernels and total time>
- Peak comparison: <measured>/<peak> = <efficiency>
- Primary bottleneck: <compute | memory | occupancy | synchronization | unknown>

### Evidence
- <counter>=<value>
- <counter>=<value>

### CuTe Actions
1. <tile shape / PipelineStages / copy atom / alignment / subgroup action>
2. <next validation pass>
```

## Source Context

This skill distills the workflow from SYCL*TLA's Intel CuTe performance material, especially `media/docs/cpp/cute/12_intel_performance_guide.md` and its linked references: `10_intel_overview.md`, `11_intel_gemm_companion.md`, `xe_2d_copy.md`, and `media/docs/cpp/xe_rearchitecture.md`.
