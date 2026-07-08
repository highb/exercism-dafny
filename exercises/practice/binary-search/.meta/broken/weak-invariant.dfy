method BinarySearch(a: array<int>, key: int) returns (index: int)
  requires forall i, j :: 0 <= i < j < a.Length ==> a[i] <= a[j]
  ensures -1 <= index < a.Length
  ensures index >= 0 ==> a[index] == key
  ensures index == -1 ==> forall i :: 0 <= i < a.Length ==> a[i] != key
{
  var lo, hi := 0, a.Length;
  while lo < hi
    invariant 0 <= lo <= hi <= a.Length
    // missing invariants tracking that key is excluded outside [lo, hi)
  {
    var mid := lo + (hi - lo) / 2;
    if a[mid] == key {
      return mid;
    } else if a[mid] < key {
      lo := mid + 1;
    } else {
      hi := mid;
    }
  }
  return -1;
}
