#!/bin/bash
# Validates emulators.json. Requires jq.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
config="${EMULATORS_CONFIG:-$root/emulators.json}"

jq -e '
	def assert(cond; msg): if cond then . else error("emulators.json: " + msg) end;
	assert(.repository | type == "string" and test("^[a-z0-9][a-z0-9._-]*$");
		"repository must be a Docker Hub repository name")
	| assert(.emulators | type == "array" and length > 0; "emulators must be a non-empty array")
	| assert([.emulators[].api] | length == (unique | length); "duplicate api entries")
	| assert(.latest as $l | [.emulators[].api] | index($l) != null; "latest must name one of the listed APIs")
	| .emulators[]
	| assert(.api | type == "string" and test("^[0-9]+$"); "api must be a numeric string: \(.api)")
	| assert(.android | type == "string" and length > 0; "android is required for API \(.api)")
	| assert(.system_image | IN("default", "google_apis", "google_apis_playstore", "aosp_atd", "google_atd");
		"unsupported system_image for API \(.api): \(.system_image)")
' "$config" >/dev/null
