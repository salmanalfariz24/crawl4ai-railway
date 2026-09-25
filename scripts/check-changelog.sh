#!/usr/bin/env bash
# Fails unless CHANGELOG.md records the exact image reference pinned in Dockerfile.
set -euo pipefail

cd "$(dirname "$0")/.."

IMAGE_REF="$(sed -nE 's#^FROM (unclecode/crawl4ai:[0-9]+\.[0-9]+\.[0-9]+@sha256:[0-9a-f]{64})$#\1#p' Dockerfile)"
if [ -z "$IMAGE_REF" ]; then
  echo "FAIL: Dockerfile must be: FROM unclecode/crawl4ai:X.Y.Z@sha256:<64 hex chars>" >&2
  exit 1
fi
if ! grep -qF "\`${IMAGE_REF}\`" CHANGELOG.md; then
  echo "FAIL: CHANGELOG.md has no entry containing \`${IMAGE_REF}\`." >&2
  echo "Add a release section for this image (see 'Maintaining this template' in README.md)." >&2
  exit 1
fi
echo "PASS: CHANGELOG.md records ${IMAGE_REF}"
