# Mutation Testing Report (AI-Optimized)

## Summary

- **Mutation Score**: 83.8%
- **Total Mutants**: 37
- **Killed**: 31 (tests caught the bug)
- **Survived**: 6 (tests missed the bug)
- **Timeout**: 0
- **Errors**: 0

## Surviving Mutants (Action Required)

These mutations were NOT detected by tests. Each represents a potential bug your tests would miss.

### .\lib\src\discount.dart

5 surviving mutant(s)

#### Line 16:27

**Mutation**: `<` → `>`

**Operator**: Comparison: < → >

**Suggested Test**: Add tests for values on both sides of the comparison. Test with value less than, equal to, and greater than the boundary.

---

#### Line 24:30

**Mutation**: `-` → `+`

**Operator**: Arithmetic: - → +

**Suggested Test**: Add a test that verifies the arithmetic result. If `-` changed to `+`, test with values where addition vs subtraction gives different results (e.g., non-zero operands).

---

#### Line 24:48

**Mutation**: `/` → `*`

**Operator**: Arithmetic: / → *

**Suggested Test**: Test with values where `/` vs `*` produce different results. Avoid values like 1 or 0 that may give same result for both operations.

---

#### Line 25:18

**Mutation**: `<` → `<=`

**Operator**: Comparison: < → <=

**Suggested Test**: Add a boundary test. Test with exact boundary value where `<` vs `<=` differ. If testing `<` vs `<=`, use the exact boundary value.

---

#### Line 25:18

**Mutation**: `<` → `>`

**Operator**: Comparison: < → >

**Suggested Test**: Add tests for values on both sides of the comparison. Test with value less than, equal to, and greater than the boundary.

---

### .\lib\src\calculator.dart

1 surviving mutant(s)

#### Line 12:27

**Mutation**: `'division by zero'` → `''`

**Operator**: String: 'x' → ''

**Suggested Test**: Test with both empty and non-empty strings. Verify behavior differs appropriately.

---

## Quick Reference (file:line)

```
.\lib\src\calculator.dart:12  # 'division by zero' → ''
.\lib\src\discount.dart:16  # < → >
.\lib\src\discount.dart:24  # - → +
.\lib\src\discount.dart:24  # / → *
.\lib\src\discount.dart:25  # < → <=
.\lib\src\discount.dart:25  # < → >
```
