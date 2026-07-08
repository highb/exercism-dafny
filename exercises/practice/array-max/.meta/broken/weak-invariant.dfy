method Max(a: array<int>) returns (m: int)
  requires a.Length > 0
  ensures exists i :: 0 <= i < a.Length && a[i] == m
  ensures forall i :: 0 <= i < a.Length ==> a[i] <= m
{
  m := a[0];
  var idx := 1;
  while idx < a.Length
    invariant 1 <= idx <= a.Length
    // missing both invariants — Dafny cannot re-establish the postcondition
  {
    if a[idx] > m { m := a[idx]; }
    idx := idx + 1;
  }
}
