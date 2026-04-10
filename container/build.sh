#!/bin/bash
# Build the NanoClaw agent container image

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

IMAGE_NAME="nanoclaw-agent"
TAG="${1:-latest}"
CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-docker}"

echo "Building NanoClaw agent container image..."
echo "Image: ${IMAGE_NAME}:${TAG}"

${CONTAINER_RUNTIME} build -t "${IMAGE_NAME}:${TAG}" .

echo ""
echo "Build complete!"
echo "Image: ${IMAGE_NAME}:${TAG}"

# Pre-build Linux-compatible node_modules for the shared library vectorstore.
# The library lives on the host (macOS) but runs inside Linux containers.
# Native bindings (better-sqlite3, sqlite-vec) must match the container OS.
LIBRARY_DIR="$(cd "$SCRIPT_DIR/.." && pwd)/groups/global/library"
LINUX_MODULES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)/data/library-linux-modules"

if [ -f "$LIBRARY_DIR/package.json" ]; then
  echo ""
  echo "Building Linux-compatible node_modules for shared library..."
  mkdir -p "$LINUX_MODULES_DIR"
  ${CONTAINER_RUNTIME} run --rm \
    -v "$LIBRARY_DIR/package.json:/build/package.json:ro" \
    -v "$LINUX_MODULES_DIR:/build/node_modules" \
    node:22-slim \
    sh -c 'cd /build && npm install --omit=dev 2>&1'
  echo "Library Linux modules ready at: $LINUX_MODULES_DIR"
fi

echo ""
echo "Test with:"
echo "  echo '{\"prompt\":\"What is 2+2?\",\"groupFolder\":\"test\",\"chatJid\":\"test@g.us\",\"isMain\":false}' | ${CONTAINER_RUNTIME} run -i ${IMAGE_NAME}:${TAG}"
