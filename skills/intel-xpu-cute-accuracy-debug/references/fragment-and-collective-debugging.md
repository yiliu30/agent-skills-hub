# Fragment, scale-payload, and collective debugging

## Derive mapping from traits, then validate it

For Xe DPAS/BDPAS code, start with the operation's traits rather than an
assumed indexing formula:

- `include/cute/atom/mma_traits_xe.hpp` defines the A/B/C layouts;
- `include/cute/arch/mma_xe.hpp` defines operation/register requirements;
- the Xe reorder implementation defines source/destination assumptions.

Record these facts for the exact instantiated atom: subgroup size, logical
tile M/N/K, fragment element type, values per work-item, and layout of each
operand/accumulator. Then make a diagnostic whose output exposes a logical
coordinate. An identity operand is often useful: `V=I` turns a GEMM output
column into an observable input-K coordinate.

## Fingerprints that isolate a failure

Use values that are exactly representable in the source format and distinct
over the dimension under test.

| Suspect | Diagnostic | What it proves |
| --- | --- | --- |
| Operand fragment | Stripe value by logical K/M/N | Logical value reaches intended MMA operand location |
| Scale payload | Distinct power-of-two scale per byte/slot | Hardware selects expected scale byte for each block |
| Row association | Distinct scale/payload per row | Scale belongs to correct row, not merely correct K block |
| Accumulation | Ones operand or known row sum | All reduction contributions and final normalization are included |
| Epilogue | Direct/simple accumulator values | Failure is before or after final store/conversion |

Do not judge a mapping from a uniform value. A transposition or stripe alias is
invisible if every position holds the same payload.

## Safe cross-lane fragment transfer

When source and destination fragments have different layouts, translate
through logical coordinates.

1. Use traits/fingerprints to identify `(logical coordinate -> source lane,
   source index)` and `(logical coordinate -> destination lane,
   destination index)`.
2. Iterate the same logical coordinate sequence on all subgroup lanes.
3. Execute the broadcast/shuffle for every lane for each coordinate.
4. Let only the owner of a destination coordinate perform the write.

This preserves subgroup collective semantics. Avoid loops where each lane
independently chooses a different source index before invoking
`group_broadcast`; that can compile but has invalid collective behavior.

## Block-scaled BDPAS checklist

For every operand, verify payload quantization convention, scale direction,
grouping dimension/group size, scale rounding, scale-slot selection, zipped
offsets, and neutral padding slots. If an internal result feeds a subsequent
BDPAS, construct its scale grid in producer logical coordinates, then map it
separately to consumer scale-fragment slots.
