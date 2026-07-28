---
name: apfel
description: >-
  Delegate suitable tasks to apfel, the on-device Apple Intelligence CLI bridge
  (~3B, 4096-token window). Use when the user mentions apfel, wants local/free
  on-device LLM, or when a task is repetitive, low-risk, machine-checkable, and
  fits a small context — text transforms, classification, short summaries, JSON
  extraction, shell one-liners. Requires macOS 26+ Apple Silicon with Apple
  Intelligence enabled.
---

# apfel

[apfel](https://apfel.franzai.com/) = macOS Tahoe built-in Foundation Model as pipe-friendly CLI. Zero API keys, zero network, ~3B params, **4096 tokens total** (input + output).

## Prerequisites

Verify before use:

```bash
which apfel && apfel --version
```

Missing or exit 5 (model unavailable):

```bash
brew install apfel
```

Needs: **Apple Silicon**, **macOS 26 (Tahoe)+**, **Apple Intelligence enabled** (System Settings → Apple Intelligence & Siri).

## When to use apfel

Use when **all** true:

- **Non-critical** (no security decisions, no irreversible writes without review)
- **Short** output, ideally **machine-checkable** (regex, JSON schema, one-word label, bullets)
- Context fits **~3k words** in + out
- Local on-device inference OK for data (private; skip secrets you wouldn't paste locally)

**Good fits:** git log summary, rephrase, classify/extract, translate, explain command, one-liner shell, JSON restructure, small file compare, bulk cheap transforms.

**Stay on primary agent:** architecture, multi-file refactors, security review, complex reasoning, long docs, math-heavy correctness, current web knowledge.

## How to run

### Single prompt

```bash
apfel "Translate to German: hello"
apfel -q "Capital of France? One word."
```

### Pipe stdin (preferred for agent workflows)

```bash
git log --oneline -20 | apfel "summarize what I worked on"
echo "$TEXT" | apfel "extract action items as bullets, no other text"
pbpaste | apfel "fix grammar"
```

### Attach files (keep small)

```bash
apfel -f path/to/file "summarize in 3 bullets"
git diff HEAD~1 | apfel -f CONVENTIONS.md "review against conventions"
```

### Structured output

```bash
apfel -o json "Translate to German: hello" | jq -r .content
apfel --schema schema.json "Extract person: Alice is 30."
```

### System prompt + token budget

```bash
apfel -s "Reply with only the label. No explanation." --max-tokens 32 "classify: bug|feature|chore — $TITLE"
apfel --count-tokens -f README.md "summarize"   # preflight before large prompts
```

### Quiet mode for scripts

```bash
result=$(apfel -q "one-word sentiment: $line")
```

## Agent workflow

1. **Decide** — match "When to use apfel"?
2. **Preflight** — big input: `apfel --count-tokens ...` (exit 4 = overflow)
3. **Run** — pipe or `-f`; `-q` + tight `--max-tokens` for classification
4. **Validate** — parse JSON, check schema, spot-check before scale
5. **Fallback** — exit 1/3/4/5/6 or bad output → primary agent

## Guardrails

- **Never** apfel alone for security, auth, destructive shell — need human review
- **Validate** before edits/commits; small models refuse/err more than cloud
- **Inject date** when needed: `apfel -s "Today is $(date '+%B %d, %Y')." "..."` — no real-time clock
- **Guardrail blocks** (exit 3): `--permissive` for benign creative/transform only
- **No embeddings / server vision** via API — `-f` for local PDF/image text only

## Exit codes

| Code | Meaning | Action |
|------|---------|--------|
| 0 | Success | Use stdout |
| 3 | Guardrail blocked | Rephrase or `--permissive`; else fallback |
| 4 | Context overflow | Shrink input or fallback |
| 5 | Model unavailable | Enable Apple Intelligence / install apfel |
| 1, 6 | Runtime / busy | Retry `--retry` or fallback |

## Examples

```bash
git log --oneline -10 | apfel "one-line release note"
ps aux | sort -k3 -nr | head -5 | apfel "which process uses most CPU, one sentence"
apfel -o json "regex for email, reply only the pattern" | jq -r .content
df -h | apfel "which volume is fullest, one sentence"
```

Demos (optional): `apfel demos ./apfel-demos` → `./apfel-demos/cmd`, `gitsum`, `explain`, etc.

## References

- Site: https://apfel.franzai.com/
- Repo: https://github.com/Arthur-Ficial/apfel
- OpenAI server: `apfel --serve` → `http://localhost:11434/v1` (primary agent orchestrates; apfel = local inference)
