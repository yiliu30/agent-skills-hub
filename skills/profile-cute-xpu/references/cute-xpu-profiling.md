# CuTe Intel XPU Profiling Reference

## Table of Contents

- Workflow
- Build and launch checks
- unitrace passes
- VTune path
- CuTe bottleneck map
- Intel Xe constraints
- Report checklist

## Workflow

Use this order unless the user provides existing profiling data:

1. Run the executable normally and verify correctness.
2. Run built-in timing, usually by setting the example's `--iterations` option.
3. Run `unitrace -d -v` to identify hot kernels, kernel names, SIMD width, local size, SLM use, private memory, and spill indicators.
4. Run `ComputeBasic` counters for the hot kernel.
5. Add `VectorEngineStalls` if compute activity or stall behavior is unclear.
6. Add memory profiling if bandwidth, L3, or load/store pressure looks dominant.
7. Convert the evidence into CuTe actions and re-profile one change at a time.

Use a short workload for metric passes. Metric collection adds overhead, so use ratios, stall percentages, hit rates, and utilization to infer bottlenecks. Use built-in timing or `unitrace -d` for timing comparisons.

## Build and Launch Checks

For SYCL*TLA examples, confirm:

```bash
cmake -G Ninja <repo> \
  -DCUTLASS_ENABLE_SYCL=ON \
  -DDPCPP_SYCL_TARGET=intel_gpu_bmg_g21
```

For debugging 2D block load/store alignment:

```bash
cmake -G Ninja <repo> \
  -DCUTLASS_ENABLE_SYCL=ON \
  -DDPCPP_SYCL_TARGET=intel_gpu_bmg_g21 \
  -DCMAKE_CXX_FLAGS="-DCUTE_ENABLE_XE_BLOCK_2D_ASSERT=1"
```

For instruction-level stall attribution:

```bash
icpx -fsycl -gline-tables-only -O2 ...
IGC_ShaderDumpEnable=1 IGC_DumpToCustomDir=dump <app> [args]
```

Kernel launch requirements for CuTe/Xe DPAS kernels:

- Use `sub_group_size<16>`.
- Prefer large GRF mode for heavy GEMM kernels, commonly `grf_size<256>`.
- A standard large BF16/BMG tile uses 32 subgroups per work-group: `Shape<_8, _4, _1>` over a `Shape<_256, _256, _32>` work-group tile.

## unitrace Passes

Set:

```bash
export ZE_FLAT_DEVICE_HIERARCHY=FLAT
```

Timing pass:

```bash
unitrace -d -v -o timing.csv <app> [args]
```

Broad hardware pass:

```bash
unitrace -k -g ComputeBasic -i 25 -o metrics_basic.csv \
  --include-kernels "<kernel-name>" \
  <app> [args]
```

Stall pass:

```bash
unitrace -k -g VectorEngineStalls -i 25 -o metrics_stalls.csv \
  --include-kernels "<kernel-name>" \
  <app> [args]
```

Memory pass:

```bash
unitrace -k -g MemoryProfile -i 25 -o metrics_memory.csv \
  --include-kernels "<kernel-name>" \
  <app> [args]
```

Timeline pass:

```bash
unitrace --chrome-kernel-logging --chrome-sycl-logging \
  -k -o trace.csv <app> [args]
```

Instruction stall sampling, when supported:

```bash
unitrace --stall-sampling -i 25 -o stalls.csv \
  --include-kernels "<kernel-name>" \
  <app> [args]
```

If a pass produces empty CSV rows, make the workload longer or lower the sampling interval. If `--include-kernels` filters everything, rerun timing with `-d -v` and copy the exact kernel name.

## VTune Path

Use VTune GPU Hotspots when the user prefers GUI analysis or when `unitrace` counters are unavailable. Look for:

- GPU time by kernel
- EU/XVE active and stall behavior
- memory bandwidth and cache behavior
- occupancy, register pressure, and spill hints
- host/device gaps or synchronization overhead

If ITT device library linkage interferes with the build, inspect the repository's DPCPP/ITT option before changing profiling tools.

## CuTe Bottleneck Map

### Bandwidth-bound or load-issue-bound

Evidence:

- High memory bytes or bandwidth relative to compute.
- Low XMX utilization.
- SBID or memory-related stalls.
- Many small K-loop iterations issuing frequent 2D block loads.

Actions:

- Increase K in `Shape<M,N,K>` to amortize 2D block load overhead.
- Increase M or N only if GRF pressure and occupancy stay healthy.
- Try `PipelineStages = 3` to hide latency, then check spill/occupancy.
- Confirm B uses VNNI-friendly layout/copy paths for BF16/FP16/INT8.

### Compute-bound but below expected peak

Evidence:

- XVE/XMX activity high but achieved TFLOPS is far below peak.
- ALU/XMX pipe utilization uneven.
- Reorder or barrier costs appear material.

Actions:

- Increase M/N tile size if occupancy allows.
- Check subgroup layout. Standard BF16/BMG baseline is `Shape<_8,_4,_1>, Stride<_4,_1,_0>` over `Shape<_256,_256,_32>`.
- Inspect whether `reorder()` is being compiled away or performing register shuffles.
- Verify data types map to supported `XE_DPAS_TT` combinations.

### Register pressure or occupancy limited

Evidence:

- Spill memory in timing output.
- Private memory growth.
- Lower occupancy after increasing tile size or pipeline stages.
- Performance regression when K or `PipelineStages` increases.

Actions:

- Revert `PipelineStages` from 3 to 2.
- Reduce M, N, or K.
- Reduce live fragments in the mainloop.
- Avoid explicit SLM unless the kernel has a correct multi-buffered design.

### Synchronization or barrier limited

Evidence:

- Barrier stalls dominate.
- The mainloop uses split barriers around every K-loop iteration.

Actions:

- Audit only if the mainloop structure changed. Standard CuTe Xe GEMM uses `barrier_arrive` before copy and `barrier_wait` after DPAS.
- Avoid adding barriers around prefetch or reorder without proof.

### Correctness or silent wrong results

Evidence:

- Verification fails after changing layout, tile shape, or copy atom.
- Wrong results with no runtime error.

Actions:

- Confirm `sub_group_size<16>`.
- Enable `-DCUTE_ENABLE_XE_BLOCK_2D_ASSERT=1`.
- Check base pointer 64-byte alignment, pitch 16-byte alignment, width 4-byte alignment.
- Check `XE_STORE_2D` height is at most 8.
- Check DPAS K dimension and problem K padding.

## Intel Xe Constraints

2D block operation constraints:

- Base pointer alignment: 64 bytes.
- Pitch alignment: 16 bytes.
- Width alignment: 4 bytes.
- Load/prefetch max height: 32 rows.
- Store max height: 8 rows.
- Max total width: 64 bytes, equivalently `Bits * Width <= 512`.
- Regular/VNNI load block count: 1, 2, or 4.
- Element size: 8, 16, 32, or 64 bits.
- `XE_LOAD_2D_VNNI`: 8 or 16 bits only.
- `XE_LOAD_2D_TRANSPOSE`: 32 or 64 bits only.

DPAS and subgroup constraints:

- Subgroup size is always 16.
- GRF per thread is commonly 256 in large-GRF mode.
- `XE_DPAS_TT<M,...>` supports M from 1 to 8.
- DPAS N is fixed at 16.
- DPAS K is `256 / max(sizeof_bits(TypeA), sizeof_bits(TypeB))`.

## Peak Comparison

Always include a peak comparison when enough information is available. For BMG Arc Pro B60, useful reference peaks are:

| Data type | Path | Approx peak |
|---|---|---|
| BF16/FP16 | XMX | 98.3 TFLOPS at 2.4 GHz, 102.4 TFLOPS at 2.5 GHz |
| FP32 | XVE | 12.3 TFLOPS at 2.4 GHz, 12.8 TFLOPS at 2.5 GHz |
| INT8 | XMX | 196.6 TOPS at 2.4 GHz, 204.8 TOPS at 2.5 GHz |
| GDDR6 memory | memory | 456 GB/s |

Classify measured/peak:

- 80% or higher: excellent.
- 60% to 80%: good, with possible headroom.
- 40% to 60%: significant headroom.
- Under 40%: deep-dive profiling required.

## Report Checklist

Include:

- executable and arguments
- GPU name and driver/runtime details if known
- compiler version and target
- problem shape, data type, tile shape, subgroup layout, and `PipelineStages`
- built-in timing and `unitrace -d -v` hot-kernel timing
- counter pass names and key metrics
- peak comparison
- primary bottleneck and next CuTe tuning action
