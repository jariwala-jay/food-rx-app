# MyFoodRx Backend

FastAPI backend for the MyFoodRx app.

## Setup

```bash
cd backend
python3 -m venv venv
source venv/bin/activate   # On Windows: venv\Scripts\activate
pip3 install -r requirements.txt
```

## Run the server

Activate the virtual environment first, then start uvicorn:

```bash
source venv/bin/activate
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Or without activating (using the venv's Python directly):

```bash
./venv/bin/python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

API will be available at `http://localhost:8000`. Docs at `http://localhost:8000/docs`.

> **Note:** On first startup, the RAG service embeds all 177 knowledge chunks and stores them in ChromaDB (`app/knowledge/chroma_db/`). Subsequent startups load from ChromaDB instantly with no API calls.

## Clear RAG cache

To force re-embedding (e.g. after knowledge base changes):

```bash
# Delete ChromaDB vector store
rm -rf backend/app/knowledge/chroma_db

# Clear MongoDB response cache
python3 backend/clear_rag_cache.py

# Or skip the database
python3 backend/clear_rag_cache.py --skip-db
```

## Run RAGAS evaluation

```bash
cd backend
python3 evaluation/run_ragas.py                        # all 40 questions
python3 evaluation/run_ragas.py --category Diabetes    # single category
```

Requires `GEMINI_API_KEY` and `GROQ_API_KEY` in your `.env` file. Reports are saved to `evaluation/reports/`.

## Run with Docker

```bash
# From repo root
docker-compose up --build    # first run — builds image and embeds chunks
docker-compose up            # subsequent runs — loads from ChromaDB volume
docker-compose down          # stop
docker-compose down -v       # stop and delete ChromaDB volume (forces re-embed)
```

## Deploy to Google Cloud Run (real devices)

See **[DEPLOYMENT.md](./DEPLOYMENT.md)** for steps, runtime env vars, and Flutter `API_BASE_URL`.