#!/bin/sh
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
check_dir=$(mktemp -d)
trap 'rm -rf "$check_dir"' EXIT
xcrun swiftc -module-cache-path "$check_dir/cache" "$repo_dir/Sightline/VoiceCommandParser.swift" "$repo_dir/tests/VoiceCommandParserChecks.swift" -o "$check_dir/parser-checks"
"$check_dir/parser-checks"
