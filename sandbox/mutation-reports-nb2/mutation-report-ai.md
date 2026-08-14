# Mutation Testing Report (AI-Optimized)

## Summary

- **Mutation Score**: 96.2%
- **Total Mutants**: 53
- **Killed**: 51 (tests caught the bug)
- **Survived**: 2 (tests missed the bug)
- **Timeout**: 0
- **Errors**: 0

## Surviving Mutants (Action Required)

These mutations were NOT detected by tests. Each represents a potential bug your tests would miss.

### .\lib\src\modern.dart

1 surviving mutant(s)

#### Line 34:8

**Mutation**: `(v > max)` → `(true)`

**Operator**: Control: if(x) → if(true)

**Suggested Test**: Add tests that exercise both branches of the if statement. Ensure tests verify behavior when condition is true AND when false.

---

### .\lib\src\discount.dart

1 surviving mutant(s)

#### Line 10:8

**Mutation**: `(effectiveTotal > 100)` → `(true)`

**Operator**: Control: if(x) → if(true)

**Suggested Test**: Add tests that exercise both branches of the if statement. Ensure tests verify behavior when condition is true AND when false.

---

## Quick Reference (file:line)

```
.\lib\src\modern.dart:34  # (v > max) → (true)
.\lib\src\discount.dart:10  # (effectiveTotal > 100) → (true)
```
