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

# Cloud Run sets PORT; default 8080 for local docker run
ENV PORT=8080
EXPOSE 8080

# Must listen on 0.0.0.0 so Cloud Run health checks work
CMD exec sh -c "uvicorn app.main:app --host 0.0.0.0 --port ${PORT}"
