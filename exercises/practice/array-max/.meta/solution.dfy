method Max(a: array<int>) returns (m: int)
  requires a.Length > 0
  ensures exists i :: 0 <= i < a.Length && a[i] == m
  ensures forall i :: 0 <= i < a.Length ==> a[i] <= m
{
  m := a[0];
  var idx := 1;
  while idx < a.Length
    invariant 1 <= idx <= a.Length
    invariant exists i :: 0 <= i < idx && a[i] == m
    invariant forall i :: 0 <= i < idx ==> a[i] <= m
  {
    if a[idx] > m { m := a[idx]; }
    idx := idx + 1;
  }
}
