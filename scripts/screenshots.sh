#!/usr/bin/env bash
#
# Regenerates the README showcase images into `screenshots/`, and the docs'
# images into `docs/images/` and streaming clip into `docs/videos/`.
#
# The generator lives in `tool/screenshots/` and runs through the Flutter test
# harness, which is the supported way to rasterise a widget to a file without
# opening a window. It is not part of the test suite: `flutter test` only looks
# in `test/`, so this never runs on CI and never gates a build.
#
# Unlike the golden files, these images are not compared against anything. They
# are documentation, so they can be regenerated on any machine.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "▸ rendering"
flutter test tool/screenshots/generate_test.dart --update-goldens

echo "▸ encoding the streaming clip"
if command -v ffmpeg >/dev/null; then
  mkdir -p docs/videos
  ffmpeg -loglevel error -y -framerate 12.5 -i build/streaming-frames/%03d.png \
    -c:v libx264 -pix_fmt yuv420p -crf 24 -movflags +faststart \
    docs/videos/streaming.mp4
  # WebM first in the page: some Chromium builds have no H.264.
  ffmpeg -loglevel error -y -framerate 12.5 -i build/streaming-frames/%03d.png \
    -c:v libvpx-vp9 -b:v 0 -crf 36 -pix_fmt yuv420p -row-mt 1 \
    docs/videos/streaming.webm
else
  echo "  ffmpeg not found — skipped docs/videos/streaming.{webm,mp4}"
fi

echo
echo "✓ screenshots updated — review them before committing"
git status --short screenshots docs/images docs/videos
