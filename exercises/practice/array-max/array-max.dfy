method Max(a: array<int>) returns (m: int)
  requires a.Length > 0
  ensures exists i :: 0 <= i < a.Length && a[i] == m
  ensures forall i :: 0 <= i < a.Length ==> a[i] <= m
{
  m := a[0]; // student must add a loop and an invariant
}
