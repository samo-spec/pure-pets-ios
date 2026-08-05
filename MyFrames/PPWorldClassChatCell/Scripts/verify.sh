#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

swift test
find Sources Tests XcodeTests -name '*.swift' -print0 | xargs -0 -n1 swiftc -parse
python3 -m json.tool Sources/PPChatCellUI/Resources/PPChatCell.xcstrings >/dev/null

if rg -n 'TODO|TBD|FIXME|error\.localizedDescription|AsyncImage|quickReplies, id: \\.self|id: UUID\(' Sources Tests; then
  echo "Guardrail scan failed."
  exit 1
fi

echo "PP chat cell verification passed."
