#!/usr/bin/env bash
# Raises the patch number of the plugin version (1.0.4 -> 1.0.5).
#
# Usage: bump-version.sh <commit before the push>
#
# Does nothing when:
# - there is no previous commit (first push to the branch), or
# - the push already changed the version by hand (e.g. to 2.0.0).
# Prints the new version on stdout when it bumps, nothing otherwise.
set -euo pipefail

FILE=.claude-plugin/plugin.json
BEFORE="${1:-}"

if [ -z "$BEFORE" ] || ! git cat-file -e "$BEFORE^{commit}" 2>/dev/null; then
  echo "No previous commit: keeping the version as is." >&2
  exit 0
fi

now=$(jq -r '.version // empty' "$FILE")
was=$(git show "$BEFORE:$FILE" 2>/dev/null | jq -r '.version // empty' || true)

if [ -z "$now" ]; then
  echo "error: $FILE has no version field." >&2
  exit 1
fi

if [ "$was" != "$now" ]; then
  echo "Version was changed by hand ($was -> $now): keeping it." >&2
  exit 0
fi

if ! [[ "$now" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  echo "error: version '$now' is not in the form X.Y.Z." >&2
  exit 1
fi

next="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.$((BASH_REMATCH[3] + 1))"

# Replace only the version value, keeping the rest of the file as is.
tmp=$(mktemp)
sed -E "s/(\"version\"[[:space:]]*:[[:space:]]*\")$now(\")/\1$next\2/" "$FILE" > "$tmp"
mv "$tmp" "$FILE"

if [ "$(jq -r '.version' "$FILE")" != "$next" ]; then
  echo "error: could not write version $next to $FILE." >&2
  exit 1
fi

echo "$next"
