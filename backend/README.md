# Food Rx Backend

FastAPI backend for the Food Rx app.

## Setup

```bash
cd backend
python3 -m venv venv
source venv/bin/activate   # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

## Run the server

Activate the virtual environment first, then start uvicorn:

```bash
source venv/bin/activate
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Or without activating (using the venv’s Python directly):

```bash
./venv/bin/python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

API will be available at `http://localhost:8000`. Docs at `http://localhost:8000/docs`.

## Deploy to Google Cloud Run (real devices)

See **[DEPLOYMENT.md](./DEPLOYMENT.md)** for steps, runtime env vars, and Flutter `API_BASE_URL`.
