#!/bin/bash

set -euo pipefail

# Ensure we run from repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
cd "$REPO_ROOT"

VERSION=$(grep -Po '__version__\s*=\s*"\K[^" ]+' src/k7/__init__.py || echo 0.0.0)

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required. Please install Docker."
  exit 1
fi

# Build CLI onefile image
echo "Building K7 CLI onefile image..."
docker build --platform linux/amd64 -t k7-cli-builder -f src/k7/cli/Dockerfile.cli .

# Extract binary
mkdir -p dist
container_id=$(docker create --platform linux/amd64 k7-cli-builder)
docker cp "$container_id":/app/k7.bin ./dist/k7 || docker cp "$container_id":/app/k7.cli.bin ./dist/k7 || true
docker rm -v "$container_id" >/dev/null

if [ ! -f ./dist/k7 ]; then
  # Nuitka default onefile name is module name with .bin; try to locate it
  echo "Attempting to locate built binary in image..."
  echo "Build did not produce expected output. Please check Dockerfile build stage."
  exit 1
fi
chmod +x ./dist/k7

echo "Creating Debian package for version $VERSION..."
PKG_DIR=dist/k7_${VERSION}_amd64
mkdir -p "$PKG_DIR/DEBIAN" "$PKG_DIR/usr/local/bin"
cat > "$PKG_DIR/DEBIAN/control" <<'EOF'
Package: k7
Version: __VERSION__
Section: utils
Priority: optional
Architecture: amd64
Maintainer: K7 Team <support@example.com>
Description: K7 CLI for sandbox management
 Provides the `k7` command with embedded installer playbook.
EOF
sed -i "s/__VERSION__/$VERSION/" "$PKG_DIR/DEBIAN/control"
cp ./dist/k7 "$PKG_DIR/usr/local/bin/k7"
chmod 0755 "$PKG_DIR/usr/local/bin/k7"

dpkg-deb --build "$PKG_DIR"

echo "Built Debian package at: ${PKG_DIR}.deb"
echo "Next step: run 'make install' to install the CLI."