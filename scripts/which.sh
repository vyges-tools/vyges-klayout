#!/usr/bin/env bash
# which.sh — resolve a commit / short / tag / date / 'latest' / 'master-latest' to a
# pullable image ref + tarball URL from index.json. Prototype of the eventual
# `vyges-klayout which` resolver. ("newest build <= commit X" is a CLI feature.)
# Usage: scripts/which.sh <commit|short|tag|date|latest|master-latest>
set -euo pipefail
Q="${1:?usage: which.sh <commit|short|tag|date|latest|master-latest>}"
IDX="${IDX:-index.json}"
[ -f "$IDX" ] || { echo "no index.json" >&2; exit 1; }

case "$Q" in
  latest)        sel='[.builds[]|select(.channel=="release")][0]' ;;
  master-latest) sel='[.builds[]|select(.channel=="nightly")][0]' ;;
  *)             sel="[.builds[]|select((.commit|startswith(\"$Q\")) or .short==\"$Q\" or .version==\"$Q\" or .date==\"$Q\")][0]" ;;
esac

row=$(jq -c "$sel" "$IDX")
[ "$row" != "null" ] || { echo "no build matches '$Q'" >&2; exit 1; }
echo "$row" | jq -r '"image:   \(.image_ref)\ndigest:  \(.image_digest)\ntarball: \(.tarball_url)\ngds-view: \(.gds_view_version)"'
