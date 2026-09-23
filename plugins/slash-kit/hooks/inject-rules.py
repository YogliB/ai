#!/usr/bin/env python3
import json
import re
import sys

RULES = """=== SLASHKIT RULES (apply to all work you produce) ===
- NO comments in source code: no inline, block, or TODO comments, no multi-line docstrings. Allowed: auto-generated license headers, Python one-liner docstrings, ponytail: markers. Rename/extract instead.
- Code search: ripwire (--legend=compact) or ast-grep via shell for symbols, callers, declarations. Grep/rg only for non-code files, literal strings, or fallback.
- Terse technical output, drop filler.
======================================================"""


def main():
    try:
        data = json.loads(sys.stdin.read() or "{}")
    except Exception:
        data = {}

    tool = str(data.get("tool_name") or data.get("tool") or data.get("name") or "")
    inp = data.get("tool_input") or data.get("input") or data.get("parameters")

    if not re.search(r"task|subagent", tool, re.I) or not isinstance(inp, dict):
        print(json.dumps({}))
        return

    for key in ("prompt", "task"):
        prompt = inp.get(key)
        if isinstance(prompt, str) and RULES not in prompt:
            inp[key] = f"{RULES}\n\n{prompt}"

    if "tool_name" in data or "tool_input" in data:
        out = {"hookSpecificOutput": {"hookEventName": "PreToolUse", "updatedInput": inp}}
    else:
        out = {"updated_input": inp}
    print(json.dumps(out))


main()
