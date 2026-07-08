# Is Sorted Check

`SortedSpec` is a `predicate` that defines, mathematically, what it means for
an array to be sorted in non-decreasing order: every earlier element is at
most every later element.

Implement `IsSorted`, a `method` that decides sortedness by scanning the
array, and prove that the boolean it returns always agrees with `SortedSpec`.

## Task

Fill in the body of `IsSorted` so that it verifies against
`ensures result == SortedSpec(a)`. You'll need a loop invariant that
connects the partial scan you've done so far to the full `SortedSpec`
statement. Remember that an empty or single-element array is vacuously
sorted.
