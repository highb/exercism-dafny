#!/usr/bin/env python3
"""Runs `dafny verify` on a solution file and emits an Exercism-compatible
results.json (interface spec version 2), with one named check per Dafny
verification task (method/function/lemma x well-formedness/correctness).

See README.md for the design rationale and the primary sources this was
built against.
"""
import csv
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

RESULTS_FILE_RE = re.compile(r"Results File: (.+\.csv)\s*$")

DECL_RE = re.compile(
    r"^(?:ghost\s+)?(method|function|predicate|lemma)\s+"
    r"(?:\{:[^}]*\}\s*)*"
    r"([A-Za-z_][A-Za-z0-9_']*)\s*\(",
)


def find_symbol_spans(source_text):
    """Returns [(name, start_line, end_line)] for each top-level
    method/function/predicate/lemma declaration, 1-indexed inclusive lines.
    Assumes a flat file with no nested modules/classes, which holds for
    all exercises shipped here."""
    lines = source_text.splitlines()
    starts = []
    for i, line in enumerate(lines, start=1):
        m = DECL_RE.match(line)
        if m:
            starts.append((i, m.group(2)))
    spans = []
    for idx, (start, name) in enumerate(starts):
        end = starts[idx + 1][0] - 1 if idx + 1 < len(starts) else len(lines)
        spans.append((name, start, end))
    return spans


def enclosing_symbol(spans, line):
    for name, start, end in spans:
        if start <= line <= end:
            return name
    return None


def run_dafny_verify(dafny_bin, dfy_path, cwd):
    cmd = [dafny_bin, "verify", str(dfy_path), "--log-format", "csv", "--json-output"]
    proc = subprocess.run(
        cmd, cwd=cwd, capture_output=True, text=True, timeout=120
    )
    return proc


def parse_json_output(stdout_text):
    """Returns a list of dicts with 'line' and 'message' for each Error
    severity diagnostic, and the csv results file path if reported."""
    diagnostics = []
    csv_path = None
    for line in stdout_text.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue
        if obj.get("type") == "status":
            m = RESULTS_FILE_RE.search(obj.get("value", ""))
            if m:
                csv_path = m.group(1)
        elif obj.get("type") == "diagnostic":
            value = obj["value"]
            if value.get("severity") != 1:  # 1 == Error
                continue
            loc = value["location"]["range"]["start"]
            parts = [value.get("defaultFormatMessage", "")]
            for related in value.get("relatedInformation", []):
                rel_loc = related["location"]["range"]["start"]
                parts.append(
                    f"  ({rel_loc['line']}:{rel_loc['character']}) "
                    f"{related.get('defaultFormatMessage', '')}"
                )
            diagnostics.append({"line": loc["line"], "message": "\n".join(parts)})
    return diagnostics, csv_path


def parse_csv_rows(csv_path):
    if csv_path is None or not Path(csv_path).exists():
        return []
    with open(csv_path, newline="") as f:
        reader = csv.DictReader(f)
        return list(reader)


def extract_test_code(source_text, span):
    _, start, end = span
    lines = source_text.splitlines()[start - 1 : end]
    contract = []
    for line in lines:
        stripped = line.strip()
        if stripped.startswith(("requires", "ensures", "invariant", "decreases")) or contract:
            if stripped == "{" or stripped == "":
                if contract:
                    break
                continue
            contract.append(line.rstrip())
        elif stripped and not stripped.startswith(("method", "function", "predicate", "lemma", "ghost")):
            break
    header = lines[0].strip() if lines else ""
    return "\n".join([header] + contract) if contract else header


def build_results(slug, dfy_path, dafny_bin, workdir):
    source_text = dfy_path.read_text()
    spans = find_symbol_spans(source_text)

    try:
        proc = run_dafny_verify(dafny_bin, dfy_path, workdir)
    except (subprocess.TimeoutExpired, OSError) as e:
        return {
            "version": 2,
            "status": "error",
            "message": f"Failed to invoke dafny verify: {e}",
        }

    combined_output = proc.stdout + proc.stderr
    diagnostics, csv_path = parse_json_output(combined_output)
    rows = parse_csv_rows(csv_path)

    if not rows:
        # Whole file failed to parse or resolve: no verification task ran.
        message = "\n\n".join(d["message"] for d in diagnostics)
        if not message:
            message = combined_output.strip() or "dafny verify produced no output"
        return {
            "version": 2,
            "status": "error",
            "message": message,
        }

    # Attribute each diagnostic to the enclosing symbol's source span.
    by_symbol = {}
    for d in diagnostics:
        name = enclosing_symbol(spans, d["line"])
        by_symbol.setdefault(name, []).append(d["message"])

    outcome_map = {"Passed": "pass", "Failed": "fail"}

    tests = []
    for row in rows:
        display_name = row["TestResult.DisplayName"]
        symbol_name = display_name.split(" (")[0]
        outcome = row["TestResult.Outcome"]
        status = outcome_map.get(outcome, "error")
        test = {"name": display_name, "status": status}
        if status != "pass":
            messages = by_symbol.get(symbol_name, [])
            test["message"] = (
                "\n\n".join(messages)
                if messages
                else f"Verification outcome: {outcome}. See dafny output for details."
            )
            span = next((s for s in spans if s[0] == symbol_name), None)
            if span:
                test["test_code"] = extract_test_code(source_text, span)
        tests.append(test)

    overall_status = "pass" if all(t["status"] == "pass" for t in tests) else "fail"

    return {
        "version": 2,
        "status": overall_status,
        "message": None,
        "tests": tests,
    }


def main():
    if len(sys.argv) != 4:
        print("usage: dafny_test_runner.py <slug> <solution-dir> <output-dir>", file=sys.stderr)
        sys.exit(1)

    slug, solution_dir, output_dir = sys.argv[1], Path(sys.argv[2]), Path(sys.argv[3])
    output_dir.mkdir(parents=True, exist_ok=True)

    dafny_bin = shutil.which("dafny") or "dafny"
    src_dfy_path = solution_dir / f"{slug}.dfy"

    if not src_dfy_path.exists():
        results = {
            "version": 2,
            "status": "error",
            "message": f"Expected solution file not found: {src_dfy_path.name}",
        }
    else:
        # dafny verify --log-format csv writes a TestResults/ dir relative to
        # its cwd, and the solution dir is mounted read-only in the Docker
        # contract, so verify a copy in a writable scratch dir instead.
        with tempfile.TemporaryDirectory() as workdir_str:
            workdir = Path(workdir_str)
            dfy_path = workdir / src_dfy_path.name
            dfy_path.write_text(src_dfy_path.read_text())
            results = build_results(slug, dfy_path, dafny_bin, workdir)

    with open(output_dir / "results.json", "w") as f:
        json.dump(results, f, indent=2)
        f.write("\n")


if __name__ == "__main__":
    main()
