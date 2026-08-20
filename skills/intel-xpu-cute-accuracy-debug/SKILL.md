---
name: intel-xpu-cute-accuracy-debug
description: Debug numerical mismatches in Intel XPU CuTe/CUTLASS kernels, especially Xe DPAS/BDPAS fragment layouts, block-scale payloads, and fused SDPA/GEMM accumulators.
---

# Intel XPU CuTe accuracy debugging

Use this skill when an Intel XPU CuTe/CUTLASS kernel compiles and launches but
fails verification, has unexpectedly poor numerical accuracy, or needs a
credible accuracy measurement. It is for layout, fragment-transfer, scale,
and accumulator diagnosis; it is not a generic performance-tuning workflow.

## Start with the right comparison

Determine whether the observed gap can be caused by intended low-precision
arithmetic before changing the kernel:

- Compare the kernel with a host/device oracle that mirrors its actual input
  payload formats, scale rounding, and intermediate quantization.
- Compare separately with the original higher-precision inputs to measure
  end-user quality.
- Do not use a loose high-precision tolerance to conclude a register-layout
  or accumulator path is correct.

Report cosine similarity, maximum and mean absolute error, and maximum and
mean relative error. Define and print a nonzero denominator floor for relative
error.

## Investigation order

1. Reduce to a deterministic, small, single-tile case where possible.
2. Localize the failing boundary: global-memory copy, register reorder,
   payload/scale construction, MMA/BDPAS call, accumulator update, or
   epilogue.
3. Inspect the authoritative CuTe MMA traits and relevant reorder atom before
   inferring register ownership from tensor shape or index order.
4. Prove operand and scale mappings with coordinate fingerprints before using
   random values.
5. Test accumulation separately with a reduction-oriented operand pattern.
6. Return to random/representative inputs only after the exact-model oracle
   proves the suspect boundary.

Read [fragment-and-collective-debugging.md](references/fragment-and-collective-debugging.md)
whenever a fragment reorder, cross-lane transfer, or Xe DPAS/BDPAS operand is
involved. Read [accuracy-oracles.md](references/accuracy-oracles.md) when
building a host reference or reporting quality metrics.

## Non-obvious invariants

- A CuTe register fragment is an ABI-defined mapping, not a contiguous logical
  matrix. Source/destination element count compatibility is required for a
  `reorder()` atom even when types compile.
- A subgroup collective must be executed by all lanes in the same order with
  the same logical source operation. Do not select a lane-dependent source
  register index for `group_broadcast`; condition only the local destination
  store after the collective.
- For block-scaled BDPAS, validate data payload placement and scale/offset
  payload placement independently. A correct data fingerprint does not prove
  scale-byte mapping.
- Uniform test data can hide K-stripe permutations, out-of-fragment reads,
  and wrong scale slots. Prefer coordinate-dependent, exactly representable
  patterns.

## Scope and safety

Preserve the kernel's intended precision format and existing user changes.
Use temporary compile-time diagnostics for focused experiments, then restore a
clean normal build. Start a separate simulator port only when needed and avoid
concurrent clients on a shared simulator.
