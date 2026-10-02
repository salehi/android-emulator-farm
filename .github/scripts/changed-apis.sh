#!/bin/bash
# Prints which APIs a push needs to publish, compared with commit BASE:
#
#   all          the image sources (docker/) changed, or BASE is unknown
#   24 30 ...    emulators.json entries that were added or changed, plus the
#                API that "latest" now points to if it moved
#   (nothing)    no published image is affected
#
#   .github/scripts/changed-apis.sh BASE
#
# Needs the full git history (actions/checkout with fetch-depth: 0) and jq.
set -euo pipefail

base="${1:-}"

if [[ -z "$base" || "$base" =~ ^0+$ ]] || ! git cat-file -e "${base}^{commit}" 2>/dev/null; then
	echo all
	exit 0
fi

if ! git diff --quiet "$base" HEAD -- docker/; then
	echo all
	exit 0
fi

if ! old="$(git show "${base}:emulators.json" 2>/dev/null)"; then
	echo all
	exit 0
fi

jq -r --argjson old "$old" '
	. as $new
	| [ $new.emulators[] | select(. as $e | ($old.emulators | index([$e])) == null) | .api ]
	  + (if $new.latest != $old.latest then [$new.latest] else [] end)
	| unique
	| join(" ")
' emulators.json
