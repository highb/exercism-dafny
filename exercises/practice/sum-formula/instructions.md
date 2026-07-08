# Sum Formula

`Sum(n)` computes `0 + 1 + ... + n` recursively. Prove that it equals the
closed-form formula: `2 * Sum(n) == n * (n + 1)`.

## Task

Fill in the body of `SumFormula`. This is an induction proof over `n`:
handle the `n == 0` base case, and in the recursive case, call
`SumFormula(n - 1)` to obtain the induction hypothesis and let Dafny's
arithmetic reasoning close the gap.

Automatic induction is turned off for this lemma (`{:induction false}`), so
an empty body will not verify on its own — you must invoke the recursive
case explicitly.
