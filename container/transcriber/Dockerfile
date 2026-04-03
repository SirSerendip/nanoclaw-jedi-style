FROM python:3.12-slim

# Install ffmpeg for audio conversion
RUN apt-get update && \
    apt-get install -y --no-install-recommends ffmpeg && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python dependencies (cached layer)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY src/ src/

# Models cache at /models (mount a volume for persistence)
ENV HF_HOME=/models
ENV TORCH_HOME=/models/torch

ENTRYPOINT ["python", "-m", "transcriber.cli"]
