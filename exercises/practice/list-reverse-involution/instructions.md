# List Reverse Involution

`Reverse` reverses a sequence recursively. Prove that reversing twice gets
you back to where you started: `Reverse(Reverse(xs)) == xs`.

A helper lemma, `ReverseDistributes`, is given and already proved. It states
that reversing a concatenation swaps and reverses the two halves:
`Reverse(xs + ys) == Reverse(ys) + Reverse(xs)`. You will need it.

## Task

Fill in the body of `ReverseInvolution`. This is an induction proof: handle
the empty sequence as the base case, and in the recursive case, use the
induction hypothesis (a recursive call to `ReverseInvolution` on the tail)
together with `ReverseDistributes` to close the gap.
