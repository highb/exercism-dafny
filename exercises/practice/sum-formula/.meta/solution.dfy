function Sum(n: nat): nat
{
  if n == 0 then 0 else n + Sum(n - 1)
}

lemma {:induction false} SumFormula(n: nat)
  ensures 2 * Sum(n) == n * (n + 1)
{
  if n == 0 {
  } else {
    SumFormula(n - 1);
  }
}
