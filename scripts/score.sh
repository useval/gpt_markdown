#!/usr/bin/env bash
#
# The pub.dev gate: packaging validation plus the full pana score.
#
# pana awards 160 points across eleven categories. Two of them — "dependencies
# support latest version" and "supports latest stable SDKs" — decay on their
# own as Flutter and the ecosystem move, so this is worth running on a
# schedule and not only before a release.
#
#   ./scripts/score.sh          # require all 160 points
#   ./scripts/score.sh 150      # accept any score of 150 or better
set -euo pipefail

cd "$(dirname "$0")/.."

THRESHOLD="${1:-160}"

# pana's --exit-code-threshold is a DEFICIT, not a score: it fails when
# (max - granted) exceeds the number given. Passing the score straight through
# meant "fail if you lose more than 160 of 160", which can never happen, so the
# gate silently passed at any score. Convert to the deficit we will tolerate.
MAX_POINTS=160
DEFICIT=$(( MAX_POINTS - THRESHOLD ))

printf '\n\033[1m▸ publish dry run\033[0m\n'
# Catches packaging problems pana does not: oversized archives, files that are
# checked in but gitignored, layout conventions.
flutter pub publish --dry-run || true

printf '\n\033[1m▸ pana\033[0m\n'
if ! command -v pana >/dev/null 2>&1; then
  dart pub global activate pana >/dev/null
fi

# --exit-code-threshold makes the score a build failure rather than a number
# somebody has to read.
dart pub global run pana \
  --no-warning \
  --exit-code-threshold "$DEFICIT" \
  . 2>&1 | tee /tmp/pana-report.md | grep -E '^### |^Points:'

printf '\n\033[32m✓ score is at or above %s of %s\033[0m\n' \
  "$THRESHOLD" "$MAX_POINTS"
printf 'full report: /tmp/pana-report.md\n'
