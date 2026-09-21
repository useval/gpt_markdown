# Task runner for gpt_markdown. `just` with no argument lists everything.
#
# Notes that do not fit on a recipe's one-line summary:
#
# * `score` takes a couple of minutes — it resolves dependencies and runs a
#   full analysis. pana awards 160 points across eleven categories, and two of
#   them ("dependencies support latest version", "supports latest stable SDKs")
#   decay without anyone touching the code, so a score that was 160 last month
#   may not be today. That is why `score.sh` also runs on a weekly schedule.
# * `publish-dry` catches what pana does not: oversized archives, files that
#   are committed but gitignored, layout conventions.
# * The `run-*` recipes go through `fvm`, which pins Flutter to the version in
#   `.fvmrc`. This is not a preference: `val_3d` calls flutter_gpu APIs that
#   changed in 3.46 (explicit draw counts) and 3.47 (async `fromAsset`, removed
#   `TextureCoordinateSystem`), so gen-UI only compiles below those. A bare
#   `flutter run` uses whatever SDK is on PATH and will fail to build.
# * `release` is the only recipe with an outward effect. It re-runs the gate,
#   refuses a dirty tree or a changelog with no heading for the version in
#   pubspec.yaml, then prompts before pushing the tag. Pushing the tag is what
#   publishes to pub.dev — the publish workflow triggers on nothing else.

_default:
    @just --list --unsorted

# pub.dev points you will get after publishing. Fails under the threshold.
score threshold="160":
    ./scripts/score.sh {{threshold}}

# Same, but never fails — for seeing where the points went.
score-soft:
    ./scripts/score.sh 0

# Full pana report from the last `just score`, with every suggestion.
score-report:
    @test -f /tmp/pana-report.md || (echo "run 'just score' first" && exit 1)
    @cat /tmp/pana-report.md

# Packaging check only. Much faster than a full score.
publish-dry:
    flutter pub publish --dry-run

# Format, analyse and test the package and all three apps. CI runs this script.
check:
    ./scripts/check.sh

# Same, applying formatting instead of failing on it.
fix:
    ./scripts/check.sh --fix

# Run the example app on the pinned SDK. `just run-example ios`, etc.
run-example device="macos":
    cd example && fvm flutter run -d {{device}}

# Run the AI chat example on the pinned SDK.
run-ai-chat device="macos":
    cd example_ai_chat && fvm flutter run -d {{device}}

# Which SDK the `run-*` recipes will actually use.
sdk:
    @fvm flutter --version | head -2

# Everything a release needs to pass, ordered to fail fastest.
release-check: check publish-dry score

# Ship it. Verifies, then asks before tagging; CI publishes from the tag.
release:
    ./scripts/release.sh
