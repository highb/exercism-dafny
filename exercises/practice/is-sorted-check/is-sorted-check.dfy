predicate SortedSpec(a: array<int>)
  reads a
{
  forall i, j :: 0 <= i < j < a.Length ==> a[i] <= a[j]
}

method IsSorted(a: array<int>) returns (result: bool)
  ensures result == SortedSpec(a)
{
  result := true; // student must add a loop and an invariant
}
