#!/bin/bash
# Prints the publish matrix as compact JSON: {"include":[{...}, ...]}.
#
#   .github/scripts/matrix.sh IMAGE REVISION [APIS]
#
# IMAGE     namespace/repository, without a tag
# REVISION  git commit used for the immutable api<API>-<REVISION> tag
# APIS      "all" (default) or API numbers separated by spaces or commas
#
# Each entry carries api, android, system_image, and tags (newline-separated).
# Requires jq.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
image="${1:?usage: matrix.sh IMAGE REVISION [APIS]}"
revision="${2:?usage: matrix.sh IMAGE REVISION [APIS]}"
apis="${3:-all}"

"$root/scripts/validate.sh"

# "30, 34 36" -> ["30","34","36"]; "all" -> null
wanted="$(jq -cn --arg apis "$apis" '
	($apis | gsub("^\\s+|\\s+$"; "")) as $a
	| if $a == "" or $a == "all" then null
	  else [$a | splits("[\\s,]+") | select(length > 0)] | unique end')"

jq -c --arg image "$image" --arg rev "$revision" --argjson wanted "$wanted" '
	.latest as $latest
	| [.emulators[].api] as $known
	| if $wanted != null and ($wanted - $known | length) > 0
	  then error("unknown API(s): \($wanted - $known | join(" ")). Known: \($known | join(" "))")
	  else . end
	| {include: [.emulators[]
		| select($wanted == null or (.api | IN($wanted[])))
		| . + {tags: ([
			"\($image):api\(.api)",
			"\($image):\(.api)",
			"\($image):android-\(.android)",
			"\($image):api\(.api)-\(.system_image)",
			"\($image):api\(.api)-\($rev)"
		] + (if .api == $latest then ["\($image):latest"] else [] end) | join("\n"))}
	]}
' "$root/emulators.json"
