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
	/^## Files$/ && !done { print "## Context"; print ""; done = 1 }
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

# Bad usage exits 2.
CODE=0
sh "$LINT" 2>/dev/null || CODE=$?
[ "$CODE" -eq 2 ] || fail "missing arguments do not exit 2"
CODE=0
sh "$LINT" "$TMP/missing.md" >/dev/null 2>&1 || CODE=$?
[ "$CODE" -eq 1 ] || fail "a missing file does not exit 1"

echo "test-lint-plan: all tests passed"
