#!/bin/sh
set -eu

ROOT=$(git rev-parse --show-toplevel)
FILE="$ROOT/rules/snail.md"
START='<!-- skills:start -->'
END='<!-- skills:end -->'

list() {
	for f in "$ROOT"/skills/snail-*/SKILL.md; do
		awk '
			NR == 1 && $0 != "---" { exit }
			NR > 1 && $0 == "---" { exit }
			/^name: / { sub(/^name: /, ""); name = $0 }
			/^description: / { sub(/^description: /, ""); desc = $0 }
			END {
				i = index(desc, ". ")
				if (i > 0) desc = substr(desc, 1, i - 1)
				sub(/\.$/, "", desc)
				if (name != "" && desc != "") printf "- `%s` — %s\n", name, desc
			}
		' "$f"
	done
}

render() {
	awk -v start="$START" -v end="$END" -v list="$1" '
		$0 == start { print; print ""; while ((getline line < list) > 0) print line; print ""; skip = 1; next }
		$0 == end { skip = 0 }
		!skip { print }
	' "$FILE"
}

awk -v s="$START" -v e="$END" '
	$0 == s { sl = NR; ns++ }
	$0 == e { el = NR; ne++ }
	END { exit !(ns == 1 && ne == 1 && sl < el) }
' "$FILE" || {
	echo "gen-skills-index: markers missing or out of order in rules/snail.md" >&2
	exit 1
}

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
list > "$TMP/list"
render "$TMP/list" > "$TMP/out"

if [ "${1:-}" = "--check" ]; then
	if ! diff "$FILE" "$TMP/out" >/dev/null; then
		echo "gen-skills-index: skill list in rules/snail.md is out of date; run scripts/gen-skills-index.sh" >&2
		diff "$FILE" "$TMP/out" | head -20 >&2
		exit 1
	fi
	echo "gen-skills-index: skill list is up to date"
	exit 0
fi

cat "$TMP/out" > "$FILE"
echo "gen-skills-index: updated rules/snail.md"
