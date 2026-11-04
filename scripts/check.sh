#!/usr/bin/env bash
#
# Format, analyse and test everything. CI runs this exact script, so a green
# run locally means a green run on CI — there is only one definition of
# "passing".
#
#   ./scripts/check.sh           # check formatting, do not modify
#   ./scripts/check.sh --fix     # apply formatting instead of failing on it
#   ./scripts/check.sh --golden  # also compare the golden images
#
# Goldens are off by default, CI included: text rasterisation differs between
# platforms, so they only match on the machine that generated them.
set -euo pipefail

cd "$(dirname "$0")/.."

FIX=0
for arg in "$@"; do
  case "$arg" in
    --fix) FIX=1 ;;
    --golden) export GPT_MARKDOWN_GOLDENS=1 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

# The package plus the apps that exercise it. The example is what pub.dev
# shows; the widgetbook is the catalogue used to inspect components;
# example_ai_chat is the streaming harness. Each is a separate package and is
# resolved and analysed in its own context — the root `analysis_options.yaml`
# excludes them for exactly that reason.
PACKAGES=("." "example" "example_ai_chat" "widgetbook")

step() { printf '\n\033[1m▸ %s\033[0m\n' "$1"; }

for package in "${PACKAGES[@]}"; do
  step "$package — dependencies"
  (cd "$package" && flutter pub get >/dev/null)
done

step "format"
# The Dart files git knows about — committed or new, not ignored. `.` would
# also walk git-ignored folders (build output, a local demo/) that CI never
# sees, and fail locally on files that are not part of the project.
dart_files() { git ls-files --cached --others --exclude-standard -- '*.dart'; }
if [[ $FIX -eq 1 ]]; then
  dart_files | xargs dart format
else
  # Formatting is part of the 50-point analysis category on pub.dev, so it is
  # a hard failure rather than a warning.
  dart_files | xargs dart format --output=none --set-exit-if-changed
fi

for package in "${PACKAGES[@]}"; do
  step "$package — analyze"
  # --fatal-infos so a lint that only warns locally cannot reach a release.
  (cd "$package" && flutter analyze --fatal-infos --fatal-warnings)
done

for package in "${PACKAGES[@]}"; do
  step "$package — test"
  (cd "$package" && flutter test)
done

printf '\n\033[32m✓ all checks passed\033[0m\n'
