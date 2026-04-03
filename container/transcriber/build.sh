#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="nanoclaw-transcriber:latest"

echo "Building transcriber image..."
docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"

# Create model cache volume if it doesn't exist
if ! docker volume inspect nanoclaw-transcriber-models &>/dev/null; then
    echo "Creating model cache volume..."
    docker volume create nanoclaw-transcriber-models
fi

echo ""
echo "Build complete!"
echo "Image: $IMAGE_NAME"
echo "Model cache: nanoclaw-transcriber-models (persistent volume)"
echo ""
echo "First transcription will download models (~2GB). Subsequent runs use cache."
echo ""
echo "Test with:"
echo "  docker run --rm -v /path/to/audio.mp3:/input/audio.mp3:ro \\"
echo "    -v nanoclaw-transcriber-models:/models \\"
echo "    -e HUGGINGFACE_TOKEN=hf_... \\"
echo "    $IMAGE_NAME --audio /input/audio.mp3 --json"
