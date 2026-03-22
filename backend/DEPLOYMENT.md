# Deploy Food Rx API (FastAPI) to Google Cloud Run

This guide deploys the **backend** so real devices can call a public **HTTPS** URL (no laptop required).

## 1. Runtime config — what you need and where to get it

Set these on **Cloud Run → your service → Variables & secrets** (or pass `--set-env-vars` / `--update-env-vars`).

| Variable | Required | Where to get it |
|----------|----------|------------------|
| **`MONGODB_URL`** | **Yes** | **MongoDB Atlas** → your cluster → **Connect** → Drivers → copy URI. Include **database name** in the path, e.g. `...mongodb.net/myfoodrx_staging?...` — the API uses `get_default_database()` from the URI. Use **Database Access** user + password (URL-encode special chars in password). |
| **`SECRET_KEY`** | **Yes** (prod) | Generate a long random string (e.g. `openssl rand -hex 32`). **Do not** use `change-me-in-production`. Used to sign JWTs; changing it **invalidates** existing user tokens. |
| **`BROADCAST_SECRET`** | No | Only if you use `POST /notifications/broadcast` with header auth. Omit or set a strong random value. |

**Notes**

- **Atlas Network Access**: allow **`0.0.0.0/0`** (or Cloud Run’s egress — advanced) so Cloud Run can reach MongoDB.
- **Same URI as Flutter?** Often **same cluster**, but you can use **`myfoodrx_staging`** for staging API and production DB for prod — match your app’s `API_BASE_URL` build.
- **Local `.env`**: your Mac’s `MONGODB_URL` is a good **template**, but **never commit** secrets. Copy values from Atlas / password manager into Cloud Run only.

Pydantic reads **uppercase** env names: `MONGODB_URL`, `SECRET_KEY`, `BROADCAST_SECRET`.

---

## 2. Prerequisites

- [Google Cloud SDK](https://cloud.google.com/sdk) (`gcloud`) installed and logged in: `gcloud auth login`
- Project selected: `gcloud config set project YOUR_PROJECT_ID` (e.g. `myfoodrx-firebase` or `myfoodrx-staging`)
- Billing enabled on the project
- **APIs enabled** (first deploy may prompt; or enable manually): **Cloud Run**, **Cloud Build**, **Artifact Registry**

---

## 3. Deploy from your machine (recommended)

From the **`backend`** folder (where `Dockerfile` lives):

```bash
cd /path/to/food-rx-app/backend

gcloud config set project YOUR_GCP_PROJECT_ID

gcloud run deploy foodrx-api \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars "MONGODB_URL=YOUR_FULL_ATLAS_URI,SECRET_KEY=YOUR_LONG_RANDOM_SECRET"
```

- Replace **`YOUR_FULL_ATLAS_URI`** with the real connection string (no angle brackets; URL-encode password if needed).
- Replace **`YOUR_LONG_RANDOM_SECRET`** with e.g. output of `openssl rand -hex 32`.
- **`--allow-unauthenticated`**: public API (typical for mobile app + JWT). To require IAM only, omit it and use authenticated calls (more setup).

First deploy can take **several minutes** (build + push + deploy).

At the end, `gcloud` prints the **service URL**, e.g. `https://foodrx-api-xxxxx-uc.a.run.app`.

---

## 4. Verify

```bash
curl -sS "https://YOUR_SERVICE_URL/health"
# Expect: {"status":"ok"}

open "https://YOUR_SERVICE_URL/docs"
```

---

## 5. Point the Flutter app at the API

In the project root **`.env`** (or CI secrets for release builds):

```env
API_BASE_URL=https://YOUR_SERVICE_URL
```

**No trailing slash** unless your client code expects it — match what `lib/core/services/api_client.dart` uses.

Rebuild the app:

```bash
flutter clean && flutter pub get && flutter run
```

Test on a **real device** on Wi‑Fi or cellular; the phone does **not** need your Mac.

---

## 6. Updates (new code)

After changing Python code:

```bash
cd backend
gcloud run deploy foodrx-api --source . --region us-central1
```

Add `--update-env-vars` only when changing secrets/config.

---

## 7. Troubleshooting

| Issue | What to check |
|-------|----------------|
| Build fails | Logs in Cloud Console → **Cloud Build** |
| `502` / container failed to start | **Cloud Run → Logs**; ensure `PORT` is used (Dockerfile does) |
| Mongo connection errors | `MONGODB_URL`, Atlas **Network Access**, password encoding |
| JWT / login odd after deploy | New `SECRET_KEY` invalidates old tokens — users sign in again |
| Wrong database | URI must include DB path: `...net/myfoodrx_staging?...` |

---

## 8. Optional: private networking / secrets

- Use **Secret Manager** for `MONGODB_URL` and `SECRET_KEY` and reference secrets from Cloud Run (more secure than plain env vars for large teams).

---

## Docker build locally (optional)

```bash
cd backend
docker build -t foodrx-api .
docker run --rm -p 8080:8080 \
  -e MONGODB_URL="mongodb+srv://..." \
  -e SECRET_KEY="dev-secret" \
  -e PORT=8080 \
  foodrx-api
curl http://localhost:8080/health
```
