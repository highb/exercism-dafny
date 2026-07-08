predicate SortedSpec(a: array<int>)
  reads a
{
  forall i, j :: 0 <= i < j < a.Length ==> a[i] <= a[j]
}

method IsSorted(a: array<int>) returns (result: bool)
  ensures result == SortedSpec(a)
{
  if a.Length <= 1 {
    return true;
  }
  var idx := 1;
  result := true;
  while idx < a.Length
    invariant 1 <= idx <= a.Length
    invariant result == (forall i, j :: 0 <= i < j < idx ==> a[i] <= a[j])
  {
    if a[idx-1] > a[idx] {
      result := false;
      return;
    }
    idx := idx + 1;
  }
}
