#!/usr/bin/env sh
# Regenerates the Dart API client from the backend's OpenAPI schema (PRD: API).
# Usage: tool/gen_api.sh [schema URL]   (default: the local compose API)
set -eu
cd "$(dirname "$0")/.."
curl -sf "${1:-http://127.0.0.1:8100/api/v1/schema/}" -o api/openapi.yaml
rm -rf lib/api/generated
dart run swagger_parser
dart run build_runner build --delete-conflicting-outputs
# The generator emits casts the analyzer flags; silence them in generated files only.
for f in lib/api/generated/models/*_enum.dart; do
  grep -q 'ignore_for_file: unnecessary_cast' "$f" || sed -i.bak '1s|^|// ignore_for_file: unnecessary_cast\n|' "$f" && rm -f "$f.bak"
done
dart format -l 100 lib/api/generated >/dev/null
