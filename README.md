# Lemma — Dafny proof-writing exercises, Exercism-interface-compatible

Cycle 1 deliverable: an Exercism-compatible test-runner adapter for Dafny,
plus five genuine proof-writing exercises, proven out entirely locally.
This does **not** attempt to get adopted as an official Exercism track —
see "Explicitly out of scope" below and in the originating spec.

## Why

Exercism has no track that teaches proof-writing. `exercism/lean` uses Lean
as a general-purpose language against the shared cross-track exercise set —
no theorem or tactic is ever exercised. `exercism/coq` shipped one real proof
exercise but stalled at the test-runner-build step (`test_runner: null`,
`active: false`). Dafny's `dafny verify` decomposes naturally into named,
independent verification conditions (one per method/lemma), which is a much
better fit for Exercism's array-of-named-checks `results.json` contract than
either of those.

## Primary sources

- Interface spec: https://github.com/exercism/docs/blob/main/building/tooling/test-runners/interface.md
- Docker contract: https://github.com/exercism/docs/blob/main/building/tooling/test-runners/docker.md

Re-fetch and re-verify these against whatever version of the docs exists
when you read this — the summary below is current as of 2026-07-08 but the
spec is not frozen.

## How it works

`bin/run.sh <slug> <solution-dir> <output-dir>` (the Docker contract
entrypoint) hands off to `lib/dafny_test_runner.py`, which:

1. Copies the student's `<slug>.dfy` out of the (read-only, per the Docker
   contract) solution directory into a scratch temp dir.
2. Runs `dafny verify <file> --log-format csv --json-output`.
3. Parses the CSV verification log: one row per verification task, named
   `"<Symbol> (correctness)"` or `"<Symbol> (well-formedness)"`, with a
   `Passed`/`Failed` outcome. This is the actual per-obligation granularity
   the interface's array-of-named-checks contract wants — see "Open
   questions, answered" below for why this was the right call over the
   per-symbol-invocation fallback.
4. Parses the `--json-output` diagnostic stream for `Error`-severity
   diagnostics (each with a source location), and attributes each one to
   the enclosing method/function/lemma by scanning the source for top-level
   declaration spans and matching line ranges.
5. Emits `results.json` (interface spec version 2):
   - If the file fails to parse or resolve, the CSV log has zero rows
     regardless of exit code — this is the correctly-unambiguous signal
     that no verification task executed. Top-level `status: "error"`, no
     `tests` array, per the spec's rule that `error` is reserved for "no
     test executed."
   - Otherwise, every named check that appears in the CSV row set becomes
     one entry in `tests`, with its attributed diagnostic message on
     failure and the relevant contract snippet as `test_code`.

## Open questions, answered

The originating spec flagged three things to verify empirically rather than
assume. All three were checked against Dafny 4.11.0 (installed via
`dotnet tool install --global dafny` from NuGet) with Z3 4.8.12 (from
Ubuntu's `apt` `z3` package):

1. **Does `--log-format:csv` give clean per-method attribution?** Yes.
   Each method/function/lemma produces its own named row(s)
   (`"Foo (correctness)"`, plus `"Foo (well-formedness)"` when applicable),
   and this held for loops, predicates, and recursive lemmas alike. The
   fallback (one `dafny verify` invocation per symbol) was **not** needed —
   the CSV path was used from the start.

2. **What Docker base image?** `mcr.microsoft.com/dotnet/sdk:8.0` +
   `apt-get install z3` + `dotnet tool install --global dafny` (from
   NuGet). This is the "custom Dockerfile on `mcr.microsoft.com/dotnet/sdk`"
   path the spec flagged as the likely fallback — it's simpler than
   unpacking Dafny's release zip (which bundles a matching Z3, but in a
   `bin/z3-<version>/` layout that's awkward to reproduce in a Dockerfile)
   and it's exactly what was validated directly on the development host.

3. **Is the predicate/method distinction pedagogically clean at
   difficulty 2 (`is-sorted-check`)?** Yes, kept as originally sequenced.

One thing the spec did *not* flag, but that surfaced during validation and
is worth calling out: **Dafny's automatic lemma induction is powerful
enough to prove `sum-formula` and `list-reverse-involution` with an empty
lemma body**, which would silently defeat the exercise (the student
"proves" the theorem by doing nothing). Both lemmas use
`{:induction false}` to force the student to write the actual recursive
call. Discovered by testing the intended-broken (empty-body) stub before
writing the rest of the exercise around it — worth flagging to anyone
extending this pattern to a 6th proof-by-induction exercise.

## Exercises

| Slug | Concept |
|---|---|
| `array-max` | postcondition-only, loop invariant needed to *prove* it |
| `is-sorted-check` | `predicate` spec vs. `method` implementation, `ensures` |
| `binary-search` | classic shrinking-search-space loop invariant |
| `list-reverse-involution` | function + lemma, induction via a given helper lemma |
| `sum-formula` | recursive function + closed form, induction with `{:induction false}` |

Each exercise directory has:
- `instructions.md` — student-facing problem statement
- `<slug>.dfy` — the stub (signature/spec fixed, body deliberately
  incomplete so it fails verification cleanly, not a parse error)
- `.meta/solution.dfy` — reference solution (verifies clean)
- `.meta/broken/*.dfy` — at least one deliberately-broken variant, to prove
  the adapter attributes the *right* obligation as failing

## Usage

### Locally

```sh
# One-off: verify a single solution
bin/run.sh array-max /path/to/solution-dir /path/to/output-dir
cat /path/to/output-dir/results.json

# Full harness: every reference + broken solution + stub, all 5 exercises
bin/run-tests.sh
```

Requires `dafny` and `z3` on `PATH`, plus `python3` and `jq` (harness only).
To install the same way this was validated:

```sh
dotnet tool install --global dafny
export PATH="$PATH:$HOME/.dotnet/tools"
apt-get install z3   # or your platform's equivalent
```

### Docker

```sh
docker build -t lemma-dafny-runner .
docker run --rm --network none \
  -v /path/to/solution-dir:/solution:ro \
  -v /path/to/output-dir:/output \
  lemma-dafny-runner array-max /solution /output
```

## What's NOT yet true (honest limitations)

- **The Dockerfile was not build-tested end-to-end in this development
  environment** — its outbound network policy allow-lists specific hosts
  (it could reach `mcr.microsoft.com` to pull the base image, but not
  `deb.debian.org`, so the `apt-get install z3` layer couldn't be
  exercised inside a container build here). Every command in the
  Dockerfile was validated directly against this same environment's host
  OS (Ubuntu, `apt`, `dotnet tool install`), which is what the Dockerfile
  mechanically reproduces — but the image itself should be built and
  smoke-tested in a normal (unrestricted) environment before relying on it.
- **No `task_id`/version-3 linking.** Practice-Exercise-style (one exercise
  = a flat list of named checks) is what's implemented; explicitly out of
  scope per the originating spec.
- **Symbol-span attribution is line-range-based and assumes a flat file**
  (no nested modules/classes). True for all 5 shipped exercises; would need
  revisiting for anything with nested declarations.
- **Only 5 exercises, only Dafny.** No Lean/TLA+/Cedar backends, no web UI,
  no LLM strategy layer — all explicitly out of scope for this cycle.
- **Not submitted to Exercism.** No track application, no maintainer
  outreach. That's a distinct, unmade decision (see the originating spec's
  Cycle 2+ notes).
- Flag names in the Dockerfile/parser were confirmed against Dafny
  **4.11.0** specifically. Re-confirm with `dafny verify --help` if the
  pinned version drifts — the spec's own caveat about legacy vs.
  action-verb CLI flag names is real; don't assume they're stable across
  major versions.
