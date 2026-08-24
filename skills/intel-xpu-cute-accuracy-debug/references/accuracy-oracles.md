# Accuracy oracles and metrics for low-precision CuTe kernels

## Use two references

An exact-model oracle answers whether the kernel implements its declared
low-precision math. Reproduce the payloads passed to the kernel, scale values
after hardware-format rounding, intermediate quantization points, relevant
masks/normalization, and output conversion.

A high-precision-input reference answers quality relative to original BF16 or
FP32 inputs. Keep it separate: a mismatch there can be expected quantization
loss, while a mismatch against the exact-model oracle is an implementation
problem until proved otherwise.

For fused SDPA, generally test both:

```text
dequantized Q/K/V -> QK -> softmax -> quantized/dequantized P -> PV
original BF16/FP32 Q/K/V -> QK -> softmax -> PV
```

## Metrics

For output vectors `reference` and `actual`, report:

```text
cosine = dot(reference, actual) / (norm(reference) * norm(actual))
abs_i  = abs(reference_i - actual_i)
rel_i  = abs_i / max(abs(reference_i), relative_floor)
```

Print cosine, max/mean absolute error, max/mean relative error, and the
positive `relative_floor`. Choose pass thresholds based on the format and
operation. Keep exact-model validation strict; use the high-precision
comparison to define and justify a quality envelope.

## SDPA isolation sequence

1. Test QK against dequantized inputs.
2. Test softmax/P conversion independently where feasible.
3. Test PV with coordinate fingerprints and identity V.
4. Test full P reduction with V=ones.
5. Test random V against the exact-model oracle.
6. Measure quality against original BF16/FP32 inputs.
