# Aerchain Kill-the-Quote — container deploy (Fly.io / Render / Railway / VPS).
# Vercel-style serverless does NOT work here (SQLite writes, background Ollama,
# Tesseract binary, 20–130s model answers). This image runs the full stack.
# Cheap path: set KTQ_PROVIDER_MODE=groq + key and skip the local model
# (512MB–1GB RAM suffices). Offline path needs ~8GB RAM for the 7B model.
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    OLLAMA_HOST=127.0.0.1:11434

RUN apt-get update && apt-get install -y --no-install-recommends \
      tesseract-ocr curl ca-certificates zstd \
    && rm -rf /var/lib/apt/lists/*

# Ollama binary (no daemon at build time; serve starts in entrypoint)
RUN curl -sL https://github.com/ollama/ollama/releases/latest/download/ollama-linux-amd64.tar.zst \
      -o /tmp/ollama.tar.zst \
    && tar --zstd -xf /tmp/ollama.tar.zst -C /usr/local \
    && rm /tmp/ollama.tar.zst \
    && ollama --version

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY app/ ./app/
COPY static/ ./static/
COPY scripts/ ./scripts/
COPY setup.sh run.sh ./
COPY .env.example ./

# persistent state lives here — mount a volume on it (data/aerchain.db,
# data/uploads, .ollama models, .env)
VOLUME ["/app/data", "/root/.ollama"]
RUN mkdir -p /app/data /app/.run

EXPOSE 8000
COPY entrypoint.sh ./
ENTRYPOINT ["./entrypoint.sh"]
