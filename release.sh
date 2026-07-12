#!/bin/bash
set -euo pipefail

# Usage: ./release.sh <version>   e.g. ./release.sh 2.2.1
# Bumps Version.txt + Xcode MARKETING_VERSION, commits, tags vX.Y.Z, and pushes.
# The pushed tag triggers .github/workflows/release.yml to build and publish the release.

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
PBXPROJ="$ROOT_DIR/iGlance/iGlance/OpenGlance.xcodeproj/project.pbxproj"
VERSION_FILE="$ROOT_DIR/Version.txt"

if [ $# -ne 1 ]; then
  echo "Usage: $0 <version>  (e.g. $0 2.2.1)" >&2
  exit 1
fi

VERSION="$1"
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: version must look like X.Y.Z (got '$VERSION')" >&2
  exit 1
fi

echo "=== Setting version to $VERSION ==="
printf '[version]%s[/version]\n' "$VERSION" > "$VERSION_FILE"

# Update MARKETING_VERSION only in the main OpenGlance target (lines 1008/1038).
if ! grep -q "MARKETING_VERSION = $VERSION;" "$PBXPROJ"; then
  sed -i '' -E "s/^( *)(MARKETING_VERSION = )[0-9.]+;/\1\2$VERSION;/" "$PBXPROJ"
fi

echo "=== Committing version bump ==="
git -C "$ROOT_DIR" add "$VERSION_FILE" "$PBXPROJ"
git -C "$ROOT_DIR" commit -m "chore: release v$VERSION

Co-authored-by: CommandCodeBot <noreply@commandcode.ai>"

TAG="v$VERSION"
echo "=== Creating and pushing tag $TAG ==="
git -C "$ROOT_DIR" tag -a "$TAG" -m "Release v$VERSION"
git -C "$ROOT_DIR" push origin master
git -C "$ROOT_DIR" push origin "$TAG"

echo "=== Done. Pushed $TAG; the release workflow will build and publish it. ==="
