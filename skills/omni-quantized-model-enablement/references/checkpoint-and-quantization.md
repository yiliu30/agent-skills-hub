# Checkpoint and Quantization Reference

Use this reference while inspecting a new AutoRound export or implementing its vLLM-Omni adapter. Keep the main skill workflow loaded first; load this file only for format-level details.

## Checkpoint inventory

Create a key inventory for the BF16/reference checkpoint and the AutoRound output. For each key, record:

| Field | Why it matters |
| --- | --- |
| Runtime/source name | Detect name mapping and fused-module mismatches |
| Shape and rank | Detect split, transpose, and shard errors |
| Dtype | Distinguish storage dtype from compute dtype |
| Scale/zero-point keys | Verify quantization metadata is present and paired |
| Block size and axis | Verify MXFP block orientation |
| Buffer versus parameter | Prevent missing derived state |

Look specifically for positional encodings, RoPE frequency tables, timestep embeddings, normalization constants, and VAE configuration. A quantizer often exports weights and scales but omits derived buffers. The runtime must initialize omitted derived state deterministically.

## AutoRound semantics

AutoRound interfaces and flags vary by checkout. Inspect the local source and `--help` output before constructing a command. Confirm these semantic choices rather than relying on defaults:

- `iters=0` means no iterative optimization/search;
- disable optimized RTN when plain RTN behavior is required;
- disable model-free routing for the ordinary offline model path;
- choose the intended export format explicitly; and
- record whether activation calibration/QDQ is required.

Use source inspection such as:

```bash
uv run python -m auto_round --help
rg -n "iters|disable_opt_rtn|model_free|mxfp8|MXFP8" /path/to/auto-round/auto_round
```

Do not infer support solely from a README. Check the actual quantizer registration, exporter, and emitted key names.

## Diffusion-only gate before Omni

Always test the AutoRound checkpoint in its original Diffusers/reference diffusion path before adapting it to Omni:

1. run the BF16/reference checkpoint with a fixed seed;
2. run the quantized checkpoint with the same seed, prompt, shape, scheduler, and step count;
3. compare the first denoiser inputs/outputs and a short decoded sample; and
4. run a normal-step-count sample only after the short run is structurally sound.

If the quantized diffusion path fails, the problem is in quantization, export, checkpoint loading, omitted model state, or the quantized kernel. Fix that first. If the diffusion path passes and Omni fails, use the operator-level parity workflow to isolate Omni's adapter, packed layout, positions, attention backend, or decoder integration. This gate prevents an Omni debugging session from masking a bad checkpoint.

## MXFP8 loading checks

MXFP8 generally requires both packed/low-precision weight data and block scales. Verify:

1. the weight byte/value layout expected by the selected kernel;
2. the scale dtype and shape;
3. whether scales are `[out_features, num_blocks]` or a transposed equivalent;
4. the block axis and block size;
5. activation quantization and dequantization/QDQ placement;
6. accumulation dtype; and
7. fallback behavior when the hardware kernel is unavailable.

For a first correctness run, a BF16 emulation/dequantization path can be useful. It must preserve the same logical weight and scale layout, otherwise it only hides or introduces a loader bug.

## Fused projection checks

Never assume source ordering from the target module name. For every fused layer, write down the source order and runtime order:

- QKV: `q`, `k`, `v` versus grouped-head or interleaved layouts;
- MLP: `gate`, `up` versus `up`, `gate`; and
- scales: split on output rows, input columns, or block axis.

Test one layer with a small known tensor and assert that splitting and reassembly are inverse operations. A shape-compatible but permuted projection can produce plausible values while destroying generation quality.

## Operator-level parity probe

Use one fixed input and compare the first transformer invocation. A useful probe reports:

```python
def stats(name, x):
    y = x.float()
    print(name, tuple(x.shape), x.dtype,
          "mean", y.mean().item(),
          "std", y.std().item(),
          "min", y.min().item(),
          "max", y.max().item())

def rel_rms(a, b):
    af, bf = a.float(), b.float()
    return ((af - bf).pow(2).mean().sqrt() /
            bf.pow(2).mean().sqrt().clamp_min(1e-12)).item()
```

Compare tensors in this order: packed inputs, positions, pre-block hidden state, projections, pre-RoPE Q/K, post-RoPE Q/K, attention output, block output, denoiser output, and decoded output. Stop at the first large divergence.

## RoPE safety rule

For a model whose checkpoint does not guarantee a serialized frequency table, compute it from configuration:

```python
inv_freq = 1.0 / (
    rope_theta ** (torch.arange(0, 2 * inv_freq_len, 2, dtype=torch.float32)
                  / (2 * inv_freq_len))
)
self.register_buffer("inv_freq", inv_freq, persistent=False)
```

Never use `torch.empty` for required derived state. Never silently continue after a required parameter or buffer is missing.

## Evidence log template

Record each experiment in a compact table:

| Run | Backend/dtype | Steps | First divergent tensor | Relative RMS | Artifact |
| --- | --- | ---: | --- | ---: | --- |
| reference | Diffusers/BF16 | 2 | none | baseline | path |
| Omni | TORCH_SDPA/MXFP8 | 2 | Q/K after RoPE | value | path |
| fixed Omni | TORCH_SDPA/MXFP8 | 2 | expected quantization delta | value | path |
| fixed Omni | TORCH_SDPA/MXFP8 | 50 | decoded output | visual check | path |

Include the exact command, environment, checkpoint revision, seed, and any temporary debug environment variables so another agent can reproduce the result.
