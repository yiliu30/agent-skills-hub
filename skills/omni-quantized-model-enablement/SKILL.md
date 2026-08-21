---
name: omni-quantized-model-enablement
description: Enable and debug AutoRound-quantized diffusion or multimodal models in vLLM-Omni, including checkpoint schema inspection, loader and fused-weight mapping, MXFP8/W4A16 integration, attention and RoPE parity, and deterministic video or audio validation. Use when adding a new model, importing an AutoRound checkpoint, comparing BF16 with a quantized path, or diagnosing black, random, or structurally incorrect Omni outputs.
---

# Omni Quantized Model Enablement

Use this skill to take a model from a working reference implementation and checkpoint to a verified vLLM-Omni inference path. Work from the reference contract outward: establish deterministic inputs, inspect the exported checkpoint, implement loading and quantization, localize the first divergent operator, then validate a complete generation.

Keep model correctness, checkpoint conversion, quantization error, attention backend behavior, and decoder quality as separate hypotheses. Do not accept a visually plausible short sample as proof of correctness.

## Inputs to collect

Collect these before editing code:

- reference implementation and revision;
- local model/checkpoint path and quantization format;
- target GPU, `uv` environment, dtype, and attention backend;
- prompt, negative prompt, seed, shape, frame count, and scheduler settings;
- expected output artifact and acceptance criteria; and
- whether the checkpoint is weight-only, activation-quantized, or MXFP block-scaled.

If any value is unknown, inspect the repository and model config before guessing. Use `uv run` from the target environment for all Python checks and inference commands.

Before model debugging, verify that the environment itself starts:

```bash
uv run python -c "import torch; print(torch.__version__, torch.cuda.is_available())"
```

If dependency resolution fails before Python starts, record it as an environment blocker and select or repair the intended `.venv`; do not interpret that failure as model or quantization evidence.

## Workflow

### 1. Establish a deterministic reference

Run a minimal reference generation and record the exact seed, scheduler timesteps/sigmas, packed sequence lengths, position IDs, dtypes, and backend. Use the same values in Omni. Prefer a two-step diagnostic run before a normal-step-count run.

For a diffusion model, save the initial noise and first transformer inputs. For an audio/video model, validate video and audio branches separately so one decoder cannot hide a failure in the other.

### 2. Inspect the model architecture and checkpoint

Inspect model config, module names, parameter shapes, buffers, fused projections, and positional encoding. Inventory the checkpoint with a safetensors/torch loader or repository tooling. Explicitly check:

- missing and unexpected parameters;
- non-persistent or derived buffers such as RoPE frequency tables;
- QKV and gate/up projection ordering;
- transposes and packed dimensions;
- quantization scales, zero points, block size, and scale orientation; and
- activation quantization metadata.

Treat a missing buffer as a design decision that must be implemented, not as a harmless warning. Derived constants should generally be constructed from config and registered non-persistently. Read [checkpoint and quantization details](references/checkpoint-and-quantization.md) when the format is unfamiliar.

### 3. Quantize with AutoRound deliberately

Inspect the installed AutoRound source and CLI help instead of assuming flags from another version:

```bash
uv run python -m auto_round --help
rg -n "mxfp8|iters|disable_opt_rtn|model_free" /path/to/auto-round/auto_round
```

For a zero-iteration MXFP8 export, set the semantic requirements explicitly: `iters=0`, disable optimized RTN, and disable model-free routing when the goal is the ordinary offline model path. Use the exact CLI/API spelling supported by the checked-out AutoRound version. Record the resulting scheme, scales, block size, and export format in the experiment log.

Do not assume that an AutoRound export preserves every model buffer. Re-run the checkpoint inventory after export and compare it with the BF16/reference inventory.

### 4. Gate the checkpoint in diffusion-only mode

Before changing vLLM-Omni, load the AutoRound checkpoint in the original Diffusers/reference diffusion pipeline, or in a minimal diffusion-only harness that uses the checkpoint's intended quantized/dequantized kernels. Run the same deterministic two-step test used for BF16, then run a normal-step-count sample.

This is a hard gate:

- **Quantized diffusion is already bad:** stop Omni work and debug AutoRound settings, exported weights/scales, omitted buffers, quantized kernel support, and the reference loader.
- **Quantized diffusion is good but Omni is bad:** the checkpoint and quantization are probably sound; focus on Omni name mapping, fused layouts, positions, attention masking/backend, and VAE/audio integration.

Save both diffusion-only artifacts and intermediate statistics. Do not use an Omni output to judge whether the quantized checkpoint itself is valid.

### 5. Implement the Omni loader contract

Add or update a checkpoint adapter that maps source names to runtime names. Keep transformations explicit and testable:

1. map source names;
2. split or fuse QKV and MLP projections in the correct order;
3. reshape or transpose scales to the runtime layout;
4. dequantize only when the selected kernel requires it;
5. preserve activation-QDQ metadata; and
6. report every skipped or unconsumed key.

Add shape assertions at the adapter boundary. Make missing required tensors fatal. For derived buffers, initialize them in the module constructor from model config rather than requiring a checkpoint key.

### 6. Validate one operation at a time

Compare the BF16/reference and Omni path at these boundaries:

1. packed noise/latent and embeddings;
2. sequence lengths, cumulative lengths, positions, and token tags;
3. input to the first transformer block;
4. Q/K/V projection outputs;
5. Q/K after RoPE;
6. segmented attention output;
7. block output and denoiser output; and
8. decoded VAE output.

Use relative RMS, max absolute error, mean/std/min/max, and a small tensor slice. The first large divergence determines the next hypothesis. If pre-block inputs match but Q/K after RoPE does not, investigate position IDs and frequency initialization before investigating SDPA.

### 7. Validate packed attention independently

For packed sequences, compare the selected backend against an explicit per-document reference. On a single rank, use a segmented SDPA formulation when the generic attention wrapper introduces a broadcast mask or padding behavior that differs from the reference. Verify causal/non-causal behavior, document boundaries, softmax scale, and sequence-parallel gather/scatter separately.

### 8. Verify end to end

Run checks in this order:

- compile changed Python files;
- run a two-step deterministic smoke test;
- compare intermediate tensors with the reference;
- run a normal 30–50 step generation;
- inspect frame/audio statistics for degenerate output; and
- inspect representative decoded frames and output container metadata.

Keep diagnostic hooks gated by an environment variable, remove temporary hooks after localization, and preserve only stable regression tests.

## Failure triage

- **Black output with large Q/K divergence:** inspect RoPE frequencies, position IDs, dtype casts, and checkpoint buffers.
- **Pre-block divergence:** inspect RNG device, scheduler, latent packing, text/media embeddings, and request shape.
- **Only fused projections diverge:** inspect QKV or gate/up order, shard loading, transposes, and scale splitting.
- **Linear outputs differ but RoPE matches:** compare dequantized weights, block scales, activation QDQ, accumulation dtype, and kernel dispatch.
- **Attention differs only with packed inputs:** compare cumulative lengths, document masks, and gather/scatter layouts.
- **Intermediate tensors match but decoded video is wrong:** inspect denoiser update equations, scheduler, VAE scaling/layout, and video frame ordering.
- **Quantized Diffusers output is already wrong:** do not debug Omni first; inspect AutoRound export keys/scales, quantized/dequantized reference loading, kernel support, and omitted derived state.
- **BF16 works but quantized output fails:** do not conclude that quantization arithmetic is the cause until the checkpoint schema and derived buffers are identical.

## Completion criteria

Declare support only when all of the following are true:

- the reference and Omni use identical deterministic test inputs;
- the quantized checkpoint passes a diffusion-only/reference pipeline gate before Omni integration;
- checkpoint keys, buffers, fused ordering, and quantization scales are accounted for;
- no required state is left uninitialized or silently skipped;
- the first transformer block and attention path have an explained numerical delta;
- a short run is structurally consistent with the reference; and
- a full-step video/audio artifact is valid, non-degenerate, and visually/audibly correct.

## Bundled reference

Load [checkpoint-and-quantization.md](references/checkpoint-and-quantization.md) when inspecting an unfamiliar AutoRound export, selecting MXFP8/W4A16 handling, or diagnosing a mismatch between BF16 and a quantized path.
