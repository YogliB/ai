#!/usr/bin/env python3
import json
import re
import sys

RULES = """=== SLASHKIT RULES (apply to all work you produce) ===
- NO comments in source code: no inline, block, or TODO comments, no multi-line docstrings. Allowed: auto-generated license headers, Python one-liner docstrings. Rename/extract instead.
- Code search: ripwire (--legend=compact) or ast-grep via shell for symbols, callers, declarations. Grep/rg only for non-code files, literal strings, or fallback.
- Terse technical output, drop filler.
======================================================"""


def transform(data):
    event = str(data.get("hook_event_name") or data.get("event") or "")
    if re.search(r"session.?start", event, re.I):
        return {"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": RULES}}

    tool = str(data.get("tool_name") or data.get("tool") or data.get("name") or "")
    inp = data.get("tool_input") or data.get("input") or data.get("parameters")
    if not re.search(r"task|subagent", tool, re.I) or not isinstance(inp, dict):
        return {}

    for key in ("prompt", "task"):
        prompt = inp.get(key)
        if isinstance(prompt, str) and RULES not in prompt:
            inp[key] = f"{RULES}\n\n{prompt}"

    if "tool_name" in data or "tool_input" in data:
        return {"hookSpecificOutput": {"hookEventName": "PreToolUse", "updatedInput": inp}}
    return {"updated_input": inp}


def self_check():
    cursor = transform({"tool": "Task", "input": {"prompt": "do x"}})
    assert RULES in cursor["updated_input"]["prompt"]

    claude = transform({"tool_name": "Task", "tool_input": {"prompt": "do x"}})
    assert RULES in claude["hookSpecificOutput"]["updatedInput"]["prompt"]

    devin = transform({"tool_name": "run_subagent", "tool_input": {"task": "do x", "title": "t"}})
    upd = devin["hookSpecificOutput"]["updatedInput"]
    assert RULES in upd["task"] and upd["title"] == "t"

    assert transform({"tool_name": "exec", "tool_input": {"command": "ls"}}) == {}
    assert transform({}) == {}

    again = transform({"tool_name": "Task", "tool_input": claude["hookSpecificOutput"]["updatedInput"]})
    assert again["hookSpecificOutput"]["updatedInput"]["prompt"].count(RULES) == 1

    session = transform({"hook_event_name": "SessionStart"})
    assert session["hookSpecificOutput"]["additionalContext"] == RULES
    session = transform({"event": "sessionStart"})
    assert session["hookSpecificOutput"]["additionalContext"] == RULES
    print("inject-rules self-check ok")


def main():
    if "--self-check" in sys.argv:
        self_check()
        return
    try:
        data = json.loads(sys.stdin.read() or "{}")
    except Exception:
        data = {}
    print(json.dumps(transform(data)))


main()
