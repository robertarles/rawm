#!/usr/bin/env python3
"""Convert an .xcresult bundle into JUnit XML (+ a simple HTML summary).

CONTRIBUTING.md requires test results as JUnit XML under ./reports/testing/.
Xcode emits .xcresult; this converts it using the native `xcresulttool` (no deps).

Usage:
  xcresult-to-junit.py <path/to/Result.xcresult> <out-dir>

Writes:
  <out-dir>/junit.xml
  <out-dir>/index.html
"""
import json
import os
import subprocess
import sys
from xml.sax.saxutils import escape, quoteattr


def load_test_nodes(xcresult):
    out = subprocess.run(
        ["xcrun", "xcresulttool", "get", "test-results", "tests",
         "--path", xcresult, "--format", "json"],
        check=True, capture_output=True, text=True,
    )
    return json.loads(out.stdout).get("testNodes", [])


def walk(node, suite, cases):
    """Collect Test Case leaves grouped by their enclosing Test Suite name."""
    ntype = node.get("nodeType")
    if ntype == "Test Suite":
        suite = node.get("name", suite)
    if ntype == "Test Case":
        cases.append((suite or "Tests", node))
        return  # failure-message children handled by the caller
    for child in node.get("children", []) or []:
        walk(child, suite, cases)


def failure_text(case):
    msgs = []
    for child in case.get("children", []) or []:
        nt = (child.get("nodeType") or "")
        if "Failure" in nt or child.get("result") == "Failed":
            if child.get("name"):
                msgs.append(child["name"])
    return "\n".join(msgs)


def main(argv):
    if len(argv) != 2:
        print("usage: xcresult-to-junit.py <Result.xcresult> <out-dir>", file=sys.stderr)
        return 2
    xcresult, out_dir = argv
    os.makedirs(out_dir, exist_ok=True)

    cases = []
    for root in load_test_nodes(xcresult):
        walk(root, None, cases)

    # Group by suite.
    suites = {}
    for suite, case in cases:
        suites.setdefault(suite, []).append(case)

    total = fails = skips = 0
    total_time = 0.0
    suite_xml = []
    suite_rows = []
    for suite in sorted(suites):
        s_cases = suites[suite]
        s_fail = s_skip = 0
        s_time = 0.0
        tc_xml = []
        for case in s_cases:
            name = case.get("name", "?")
            dur = float(case.get("durationInSeconds") or 0.0)
            s_time += dur
            result = case.get("result", "Passed")
            attrs = f"classname={quoteattr(suite)} name={quoteattr(name)} time=\"{dur:.4f}\""
            if result == "Failed":
                s_fail += 1
                msg = failure_text(case) or "Test failed"
                tc_xml.append(f"    <testcase {attrs}>\n"
                              f"      <failure>{escape(msg)}</failure>\n"
                              f"    </testcase>")
            elif result == "Skipped":
                s_skip += 1
                tc_xml.append(f"    <testcase {attrs}>\n"
                              f"      <skipped/>\n"
                              f"    </testcase>")
            else:
                tc_xml.append(f"    <testcase {attrs}/>")

        total += len(s_cases)
        fails += s_fail
        skips += s_skip
        total_time += s_time
        suite_xml.append(
            f"  <testsuite name={quoteattr(suite)} tests=\"{len(s_cases)}\" "
            f"failures=\"{s_fail}\" skipped=\"{s_skip}\" time=\"{s_time:.4f}\">\n"
            + "\n".join(tc_xml) + "\n  </testsuite>"
        )
        suite_rows.append((suite, len(s_cases), s_fail, s_skip, s_time))

    xml = (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        f'<testsuites tests="{total}" failures="{fails}" skipped="{skips}" '
        f'time="{total_time:.4f}">\n'
        + "\n".join(suite_xml)
        + "\n</testsuites>\n"
    )
    with open(os.path.join(out_dir, "junit.xml"), "w") as f:
        f.write(xml)

    # Simple HTML summary.
    status = "PASSED" if fails == 0 else "FAILED"
    color = "#1a7f37" if fails == 0 else "#cf222e"
    rows = "\n".join(
        f"<tr><td>{escape(s)}</td><td style='text-align:right'>{t}</td>"
        f"<td style='text-align:right'>{fl}</td><td style='text-align:right'>{sk}</td>"
        f"<td style='text-align:right'>{tm:.3f}s</td></tr>"
        for (s, t, fl, sk, tm) in suite_rows
    )
    html = f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<title>rawm — Test Results</title>
<style>
 body{{font:14px -apple-system,system-ui,sans-serif;margin:2rem;color:#1f2328}}
 h1{{font-size:1.4rem}} .status{{font-weight:600;color:{color}}}
 table{{border-collapse:collapse;margin-top:1rem;width:100%;max-width:780px}}
 th,td{{border-bottom:1px solid #d0d7de;padding:.4rem .6rem}}
 th{{text-align:left;background:#f6f8fa}}
</style></head><body>
<h1>rawm — Test Results</h1>
<p class="status">{status}</p>
<p>{total} tests · {fails} failures · {skips} skipped · {total_time:.2f}s</p>
<table><thead><tr><th>Suite</th><th>Tests</th><th>Failures</th><th>Skipped</th><th>Time</th></tr></thead>
<tbody>
{rows}
</tbody></table>
</body></html>
"""
    with open(os.path.join(out_dir, "index.html"), "w") as f:
        f.write(html)

    print(f"[junit] {total} tests, {fails} failures, {skips} skipped -> {out_dir}/junit.xml")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
