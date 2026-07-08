function Reverse(xs: seq<int>): seq<int>
{
  if |xs| == 0 then [] else Reverse(xs[1..]) + [xs[0]]
}

lemma ReverseDistributes(xs: seq<int>, ys: seq<int>)
  ensures Reverse(xs + ys) == Reverse(ys) + Reverse(xs)
{
  if |xs| == 0 {
    assert xs + ys == ys;
  } else {
    calc {
      Reverse(xs + ys);
    ==  { assert (xs + ys)[1..] == xs[1..] + ys; }
      Reverse(xs[1..] + ys) + [xs[0]];
    == { ReverseDistributes(xs[1..], ys); }
      Reverse(ys) + Reverse(xs[1..]) + [xs[0]];
    == { assert Reverse(xs[1..]) + [xs[0]] == Reverse(xs); }
      Reverse(ys) + Reverse(xs);
    }
  }
}

lemma {:induction false} ReverseInvolution(xs: seq<int>)
  ensures Reverse(Reverse(xs)) == xs
{
  // student must add the induction step, using ReverseDistributes
}
