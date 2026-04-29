#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${DEBOX_SKILL_CLI_VERSION:-0.1.0}"
DIST_DIR="$ROOT_DIR/dist/v$VERSION"

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

build_one() {
  local goos="$1"
  local goarch="$2"
  local output="$DIST_DIR/debox-$VERSION-$goos-$goarch"

  CGO_ENABLED=0 GOOS="$goos" GOARCH="$goarch" \
    go build -trimpath -ldflags="-s -w" -o "$output" "$ROOT_DIR/cmd/debox-cli"
}

build_one darwin arm64
build_one darwin amd64
build_one linux arm64
build_one linux amd64

(
  cd "$DIST_DIR"
  shasum -a 256 debox-"$VERSION"-* > checksums.txt
)

printf 'Built release assets in %s\n' "$DIST_DIR"
