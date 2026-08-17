---
name: vllm-kernel-trace
description: "Trace which GPU kernels vLLM dispatches for specific model layers (linear, attention, MoE, norms). Use this skill whenever the user wants to understand what kernel runs under a vLLM model layer, trace the call stack from a quantization config to the actual CUDA kernel, profile a vLLM run and identify bottleneck ops, or understand input/output dtypes and tensor shapes flowing through a layer. Trigger on phrases like 'which kernel', 'trace the call stack', 'what op does vLLM use for', 'profile this model', 'understand the dispatch path', 'what GEMM kernel', 'marlin or cutlass', 'kernel for MXFP4/FP8/AWQ/GPTQ'."
---

# vLLM Kernel Trace

Trace the GPU kernel dispatch path for any layer type in a vLLM model. Produces a call stack analysis, dtype/shape table, and a profiling script with actual trace results.

## Workflow

There are two modes. Use **Quick mode** when the user just wants to know what kernel is running (profile and grep). Use **Deep mode** when they want the full call stack, dtypes, shapes, and understanding of the dispatch logic.

### Quick Mode (profile-first)

1. Get model path, python env, GPU count from user (skip if already known)
2. Write and run a profiling script (see template in Step 5 below) with `torch_profiler_record_shapes=True`
3. After profiling completes, grep the trace JSON for kernel names:
   ```bash
   python -c "
   import json, glob, collections
   files = glob.glob('<PROFILE_DIR>/*.json')
   for f in files:
       trace = json.load(open(f))
       ops = [e['name'] for e in trace.get('traceEvents', []) if e.get('cat') == 'kernel']
       counts = collections.Counter(ops).most_common(20)
       for name, cnt in counts:
           print(f'{cnt:5d}  {name}')
   "
   ```
4. Report which kernels dominate and their shapes (visible in the trace event args)
5. If the user wants deeper understanding, switch to Deep mode

### Deep Mode (full trace)

### 1. Clarify the target

Ask the user:
- **Model path** — where is the model checkpoint?
- **Layer type** — what are they interested in? (quantized linear, attention, MoE, norms, or "all")
- **Python env** — which python interpreter to use
- **GPU setup** — how many GPUs, which CUDA_VISIBLE_DEVICES

If the user already provided these in context, skip asking.

### 2. Inspect the model config

Read the model's `config.json` (and `quantization_config` within it) to determine:
- `quant_method` (compressed-tensors, gptq, awq, fp8, mxfp4, etc.)
- `format` (e.g., mxfp4-pack-quantized, marlin, etc.)
- `model_type` (for architecture-specific dispatch)
- Any ignored layers

This tells you which quantization path vLLM will take.

### 3. Trace the code path

Follow the dispatch chain in vLLM source. The general pattern is:

```
quantization config (from config.json)
  → QuantizationConfig subclass (registered in __init__.py)
    → get_quant_method() returns a QuantizeMethodBase for the layer type
      → create_weights() / process_weights_after_loading()
      → apply_weights() or apply() → actual kernel call (ops.XXX)
```

Key directories to search:
- `vllm/model_executor/layers/quantization/` — all quant methods
- `vllm/model_executor/layers/quantization/compressed_tensors/schemes/` — compressed-tensors sub-schemes
- `vllm/model_executor/layers/quantization/utils/` — kernel wrappers (marlin, cutlass, etc.)
- `vllm/model_executor/layers/attention/` — attention backends
- `vllm/model_executor/layers/fused_moe/` — MoE kernels
- `vllm/_custom_ops.py` — the final dispatch to C++/CUDA ops

For each target layer, identify:
1. The scheme/method class that handles it
2. The `apply_weights()` or equivalent method
3. The actual `ops.XXX()` call (this is the kernel)
4. The scalar_type or other type identifiers passed to the kernel

### 4. Document dtypes and shapes

For the identified kernel call, document:
- Input activation: dtype, shape pattern `(M, K)`
- Weight: dtype after repacking, shape
- Scales: dtype, shape, group_size
- Any additional inputs (global_scale, zeros, bias)
- Output: dtype, shape pattern `(M, N)`
- Any quantization of activations (a_scales)

### 5. Create a profiling script

Write a self-contained Python script that:
- Loads the model with `vllm.LLM`
- Uses `profiler_config` with `torch_profiler_record_shapes: True`
- Runs a minimal generation (1 prompt, short max_tokens)
- Uses `enforce_eager=True` to avoid cudagraph complications
- Saves trace to a known directory

Template:
```python
import time
from vllm import LLM, SamplingParams

MODEL_PATH = "<user's model path>"
PROFILE_DIR = "./vllm_profile_<model_name>"

llm = LLM(
    model=MODEL_PATH,
    tensor_parallel_size=<N>,
    max_model_len=128,
    max_num_seqs=1,
    enforce_eager=True,
    profiler_config={
        "profiler": "torch",
        "torch_profiler_dir": PROFILE_DIR,
        "torch_profiler_record_shapes": True,
    },
)

llm.start_profile()
outputs = llm.generate(["Hello, my name is"], SamplingParams(temperature=0.0, max_tokens=16))
llm.stop_profile()

for o in outputs:
    print(f"Generated: {o.outputs[0].text!r}")
time.sleep(10)
print(f"Profile saved to: {PROFILE_DIR}")
```

### 6. Run with debug logging

Before profiling, do a quick run with `VLLM_LOGGING_LEVEL=DEBUG` and temporary debug prints (or grep the log) to confirm which kernel is actually hit and capture real shapes. Add a temporary `logger.debug(...)` in the identified `apply_weights()` function if needed, then remove it after.

### 7. Run the profiler

Execute the profiling script. After completion, optionally grep the trace JSON for the kernel name to confirm it appears.

### 8. Produce the results report

Write a markdown file with:
- **Call stack** — the full dispatch chain from config to kernel
- **Kernel identity** — the exact `ops.XXX` call and its CUDA kernel name
- **Dtype/Shape table** — all inputs and outputs with concrete dimensions for the user's model
- **Profiling script location** — path to the ready-to-use script
- **Profile output location** — where the trace was saved
- **How to view** — instructions for opening in Chrome trace viewer or TensorBoard

## Common Dispatch Paths (Reference)

| Quant Method | Format | Kernel | Key File |
|---|---|---|---|
| compressed-tensors | mxfp4-pack-quantized | `ops.marlin_gemm` (float4_e2m1f) | `schemes/compressed_tensors_w4a16_mxfp4.py` |
| compressed-tensors | float-quantized (fp8) | `ops.cutlass_scaled_mm` | `schemes/compressed_tensors_wNaN.py` |
| gptq_marlin | - | `ops.marlin_gemm` | `gptq_marlin.py` |
| awq_marlin | - | `ops.marlin_gemm` | `awq_marlin.py` |
| fp8 | - | `ops.cutlass_scaled_mm` | `fp8.py` |
| None (bf16) | - | torch.mm / cuBLAS | `linear.py` |

For attention:
- Flash Attention → `flash_attn` ops
- FlashInfer → `flashinfer` ops  
- Paged Attention → `ops.paged_attention_v1/v2`

For MoE:
- Triton fused MoE → `fused_moe/` triton kernels
- Marlin MoE → `ops.marlin_gemm_moe`

## Tips

- Use `enforce_eager=True` during tracing to see the actual kernel calls without cudagraph wrapping
- `VLLM_ENABLE_V1_MULTIPROCESSING=0` makes debug output easier to read (single process)
- The `torch_profiler_record_shapes=True` option captures tensor shapes in the trace — essential for understanding the data flow
- If the model uses tensor parallelism, shapes will be divided across GPUs (e.g., hidden_size/TP for some projections)
