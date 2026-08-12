# Food Rx API — Cloud Run / container deploy
# Build from repo root:  docker build -f backend/Dockerfile backend
# Or from backend/:      docker build -t foodrx-api .

FROM python:3.12-slim

WORKDIR /app

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# Install dependencies first (better layer caching)
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Application code (package is `app`)
COPY app ./app

# Create ChromaDB directory so volume mount has a target
RUN mkdir -p app/knowledge/chroma_db

# Cloud Run sets PORT; default 8080 for local docker run
ENV PORT=8080
EXPOSE 8080

# Must listen on 0.0.0.0 so Cloud Run health checks work.
# --proxy-headers/--forwarded-allow-ips: Cloud Run terminates TLS and proxies
# every request, so without these uvicorn sees Cloud Run's internal IP as the
# client for every request — collapsing the per-IP rate limiter (app/rate_limit.py)
# onto a single shared bucket instead of limiting each real client separately.
CMD exec sh -c "uvicorn app.main:app --host 0.0.0.0 --port ${PORT} --proxy-headers --forwarded-allow-ips='*'"
