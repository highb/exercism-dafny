# Binary Search

Implement `BinarySearch` over a non-decreasing array. It must return the
index of `key` if present, or `-1` if `key` does not occur anywhere in the
array.

## Task

Fill in the body of `BinarySearch` so that it verifies. You'll need a loop
invariant that shrinks the search space on each iteration while maintaining
the invariant that `key` cannot be hiding outside the current `[lo, hi)`
window.
