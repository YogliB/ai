#!/bin/sh
set -eu

REPO_ROOT=$(git rev-parse --show-toplevel)
LINT="$REPO_ROOT/skills/sk-planning/scripts/lint-plan.sh"
TEMPLATE="$REPO_ROOT/skills/sk-planning/templates/plan.md"
MASTER="$REPO_ROOT/skills/sk-planning/templates/masterplan.md"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

fail() {
	echo "test-lint-plan: FAIL: $1" >&2
	exit 1
}

# A filled template passes: all sections, in order, decision filled.
sed 's/- \*\*Decision:\*\* \[Proceed \/ Split\]/- **Decision:** Proceed/' "$TEMPLATE" > "$TMP/good.md"
sh "$LINT" "$TMP/good.md" >/dev/null || fail "a filled template does not pass"

# The masterplan template passes in --masterplan mode.
sh "$LINT" "$MASTER" --masterplan >/dev/null || fail "the masterplan template does not pass"

# A missing section is reported.
grep -v '^## Risks$' "$TMP/good.md" > "$TMP/no-risks.md"
if sh "$LINT" "$TMP/no-risks.md" 2>"$TMP/err"; then
	fail "a missing section is not reported"
fi
grep -q 'missing required section: ## Risks' "$TMP/err" || fail "the missing section is not named"

# A section out of order is reported (Scope and Risks swapped).
S1=$(grep -n '^## Scope$' "$TMP/good.md" | cut -d: -f1)
S2=$(grep -n '^## Risks$' "$TMP/good.md" | cut -d: -f1)
S3=$(grep -n '^## Dependencies$' "$TMP/good.md" | cut -d: -f1)
{
	sed -n "1,$((S1 - 1))p" "$TMP/good.md"
	sed -n "$S2,$((S3 - 1))p" "$TMP/good.md"
	sed -n "$S1,$((S2 - 1))p" "$TMP/good.md"
	sed -n "$S3,\$p" "$TMP/good.md"
} > "$TMP/reorder.md"
if sh "$LINT" "$TMP/reorder.md" 2>"$TMP/err"; then
	fail "a section out of order is not reported"
fi
grep -q 'out of order' "$TMP/err" || fail "the order problem is not named"

# Files not right after Goal is reported.
sed 's/^## Files$/## Goal\n\nx\n\n## Files/; 1,/^## Goal$/{ /^## Goal$/d }' "$TMP/good.md" > "$TMP/tmp.md"
awk '
	/^## Files$/ && !done { print "## Context"; print ""; done = 1; next }
	/^## Context$/ && !swapped { print "## Files"; print ""; swapped = 1; next }
	{ print }
' "$TMP/good.md" > "$TMP/swap.md"
if sh "$LINT" "$TMP/swap.md" 2>"$TMP/err"; then
	fail "Files not after Goal is not reported"
fi
grep -q 'right after ## Goal' "$TMP/err" || fail "the Files position problem is not named"

# Checkboxes nested past depth 2 are reported.
sed 's/^    - \[ \] Task 1.1$/    - [ ] Task 1.1\n        - [ ] Task 1.1.1/' "$TMP/good.md" > "$TMP/deep.md"
if sh "$LINT" "$TMP/deep.md" 2>"$TMP/err"; then
	fail "depth 3 nesting is not reported"
fi
grep -q 'deeper than 2 levels' "$TMP/err" || fail "the depth problem is not named"

# The template placeholder decision is reported; an explicit one passes.
if sh "$LINT" "$TEMPLATE" 2>"$TMP/err"; then
	fail "the placeholder decision is not reported"
fi
grep -q 'template placeholder' "$TMP/err" || fail "the placeholder problem is not named"

# --allow-draft permits a draft without Branch setup, Delivery, Complexity Check.
awk '
	/^## (Branch setup|Delivery|Complexity Check)/ { skip = 1; next }
	/^## / { skip = 0 }
	!skip { print }
' "$TMP/good.md" > "$TMP/draft.md"
if sh "$LINT" "$TMP/draft.md" 2>/dev/null; then
	fail "a draft without delivery sections passes without --allow-draft"
fi
sh "$LINT" "$TMP/draft.md" --allow-draft >/dev/null || fail "--allow-draft rejects a valid draft"


# A duplicate required section is reported.
cat "$TMP/good.md" > "$TMP/dup.md"
printf '\n## Goal\n' >> "$TMP/dup.md"
if sh "$LINT" "$TMP/dup.md" 2>"$TMP/err"; then
	fail "a duplicate section is not reported"
fi
grep -q 'duplicate section: ## Goal' "$TMP/err" || fail "the duplicate section is not named"

# A heading or checkbox inside a fenced code block does not count.
awk '/^## Risks$/ { print; print ""; print "```text"; print "## Goal"; print "        - [ ] buried checkbox"; print "```"; print ""; next } { print }' "$TMP/good.md" > "$TMP/fenced.md"
sh "$LINT" "$TMP/fenced.md" >/dev/null || fail "fenced content is not ignored"

# Tilde fences are stripped too.
awk '/^## Risks$/ { print; print ""; print "~~~"; print "## Goal"; print "~~~"; print ""; next } { print }' "$TMP/good.md" > "$TMP/tilde.md"
sh "$LINT" "$TMP/tilde.md" >/dev/null || fail "tilde-fenced content is not ignored"

# A fence does not close on a line with an info string.
awk '/^## Risks$/ { print; print ""; print "```"; print "## Goal"; print "```python"; print "## Files"; print "```"; print ""; next } { print }' "$TMP/good.md" > "$TMP/fenceinfo.md"
sh "$LINT" "$TMP/fenceinfo.md" >/dev/null || fail "a fence closing on an info-string line loses later content"

# A backtick info string containing a backtick is not a fence at all.
awk '/^## Risks$/ { print; print ""; print "```a`b"; print "## Goal"; print ""; next } { print }' "$TMP/good.md" > "$TMP/notfence.md"
if sh "$LINT" "$TMP/notfence.md" 2>"$TMP/err"; then
	fail "a duplicate section is not reported"
fi
grep -q 'duplicate section: ## Goal' "$TMP/err" || fail "an info string with a backtick opens a fence"

# A heading with closing hashes is recognized.
sed 's/^## Goal$/## Goal ##/' "$TMP/good.md" > "$TMP/closinghash.md"
sh "$LINT" "$TMP/closinghash.md" >/dev/null || fail "a heading with closing hashes is not recognized"

# Extra spaces after ## are fine.
sed 's/^## Files$/##  Files/' "$TMP/good.md" > "$TMP/spaces.md"
sh "$LINT" "$TMP/spaces.md" >/dev/null || fail "extra spaces after ## break section capture"

# A heading indented up to 3 spaces is recognized.
sed 's/^## Context$/  ## Context/' "$TMP/good.md" > "$TMP/indhead.md"
sh "$LINT" "$TMP/indhead.md" >/dev/null || fail "an indented heading is not recognized"

# + markers and multiple spaces after the marker count as checkboxes.
sed 's/^    - \[ \] Task 1.1$/    + [ ] Task 1.1\n        +   [ ] Task 1.1.1/' "$TMP/good.md" > "$TMP/deepplus.md"
if sh "$LINT" "$TMP/deepplus.md" 2>"$TMP/err"; then
	fail "+ nested checkboxes past depth 2 are not reported"
fi
grep -q 'deeper than 2 levels' "$TMP/err" || fail "the + nesting problem is not named"

# A 2-space sibling after 4-space children is the same depth, not deeper.
awk '/^    - \[ \] Task 1.2$/ { print; print "  - [ ] Task 1.3 sibling at 2 spaces"; next } { print }' "$TMP/good.md" > "$TMP/mixed.md"
sh "$LINT" "$TMP/mixed.md" >/dev/null || fail "mixed 2/4-space sibling indents false-positive on depth"

# Checkboxes outside Implementation Plan (TODOs) do not count for depth.
awk '/^## Acceptance$/ { print; print ""; print "        - [ ] deeply nested outside TODOs"; next } { print }' "$TMP/good.md" > "$TMP/scoped.md"
sh "$LINT" "$TMP/scoped.md" >/dev/null || fail "checkboxes outside the TODOs section affect depth"

# A bold decision value is recognized.
sed 's/- \*\*Decision:\*\* \[Proceed \/ Split\]/- **Decision:** **Proceed**/' "$TEMPLATE" > "$TMP/bold.md"
sh "$LINT" "$TMP/bold.md" >/dev/null || fail "a bold Proceed decision is not recognized"

# ProceedLater is not an explicit Proceed.
sed 's/- \*\*Decision:\*\* \[Proceed \/ Split\]/- **Decision:** ProceedLater/' "$TEMPLATE" > "$TMP/proclater.md"
if sh "$LINT" "$TMP/proclater.md" 2>"$TMP/err"; then
	fail "a ProceedLater decision passes"
fi
grep -q 'no explicit Proceed or Split' "$TMP/err" || fail "ProceedLater is not rejected"

# Naming both Proceed and Split is ambiguous.
sed 's#- \*\*Decision:\*\* \[Proceed / Split\]#- **Decision:** Proceed / Split#' "$TEMPLATE" > "$TMP/both.md"
if sh "$LINT" "$TMP/both.md" 2>"$TMP/err"; then
	fail "a Proceed / Split decision passes"
fi
grep -q 'must pick one' "$TMP/err" || fail "a both-words decision is not rejected"

# Bad usage exits 2.
CODE=0
sh "$LINT" 2>/dev/null || CODE=$?
[ "$CODE" -eq 2 ] || fail "missing arguments do not exit 2"
CODE=0
sh "$LINT" "$TMP/missing.md" >/dev/null 2>&1 || CODE=$?
[ "$CODE" -eq 1 ] || fail "a missing file does not exit 1"

sed 's/^## Implementation Plan (TODOs)$/## Implementation Plan (TODOs) ##/' "$TMP/deep.md" > "$TMP/deep-closing.md"
if sh "$LINT" "$TMP/deep-closing.md" 2>"$TMP/err"; then
	fail "closing hashes bypass TODO depth checks"
fi
grep -q 'deeper than 2 levels' "$TMP/err" || fail "closing-hash TODO depth problem is not named"
sed 's/^## Complexity Check$/## Complexity Check ##/' "$TMP/good.md" > "$TMP/decision-closing.md"
sh "$LINT" "$TMP/decision-closing.md" >/dev/null || fail "closing hashes break decision parsing"

echo "test-lint-plan: all tests passed"
