# Food Rx API – Endpoint list for Flutter

Base URL: `API_BASE_URL` (e.g. `https://your-api.example.com` or `http://10.0.2.2:8000` for Android emulator).

All authenticated requests must send:

```http
Authorization: Bearer <access_token>
```

---

## Implemented (auth slice)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/health` | No | Liveness check. |
| POST | `/auth/register` | No | Body: `{ "email", "password", ...userData }`. Returns `access_token`, `user_id`, `email`, `user`. |
| POST | `/auth/login` | No | Body: `{ "email", "password" }`. Returns `access_token`, `user_id`, `email`, `user`. |
| GET | `/auth/me` | Yes | Returns current user document (same shape as Flutter `UserModel.fromJson`). |

---

## To implement (same order as refactor)

### Auth & profile

| Method | Path | Description |
|--------|------|-------------|
| PATCH | `/auth/profile` | Body: partial user updates. Replaces `updateUserProfile`. |
| POST | `/auth/profile-photo` | Multipart: profile image. Returns `profilePhotoId`. Replaces `uploadProfilePhoto`. |
| GET | `/api/profile-photos/{photo_id}` | Returns image bytes (e.g. `image/jpeg`). Replaces `getProfilePhoto`. |
| POST | `/auth/forgot-password` | Body: `{ "email" }`. Sends reset email; returns success. Replaces `generatePasswordResetToken`. |
| POST | `/auth/validate-reset-token` | Body: `{ "token" }`. Returns valid/user id or error. |
| POST | `/auth/reset-password` | Body: `{ "token", "newPassword" }`. Replaces `resetPassword`. |

### Education (articles & bookmarks)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/education/articles` | Query: `category`, `userId`, `bookmarksOnly`, `searchQuery`. Replaces article list + bookmarks. |
| GET | `/education/categories` | Distinct categories. Replaces `getCategories`. |
| PUT | `/education/articles/{article_id}/bookmark` | Body: `{ "isBookmarked": true \| false }`. Replaces `updateArticleBookmark`. |

### Pantry

| Method | Path | Description |
|--------|------|-------------|
| GET | `/pantry/items` | Query: `isPantryItem` (bool). Returns list. Replaces `getPantryItems`. |
| POST | `/pantry/items` | Body: pantry item fields. Returns `id`. Replaces `addPantryItem`. |
| PATCH | `/pantry/items/{id}` | Body: partial updates. Replaces `updatePantryItem`. |
| DELETE | `/pantry/items/{id}` | Replaces `deletePantryItem`. |
| GET | `/pantry/expiring` | Query: `daysThreshold`. Replaces `getExpiringItems`. |

### Recipes

| Method | Path | Description |
|--------|------|-------------|
| GET | `/recipes/saved` | Returns saved recipes for user. |
| POST | `/recipes/saved` | Body: recipe. Replaces `saveRecipe`. |
| DELETE | `/recipes/saved/{recipe_id}` | Replaces `unsaveRecipe`. |
| POST | `/recipes/cooked` | Body: recipe. Replaces `cookRecipe`. |

### Trackers

| Method | Path | Description |
|--------|------|-------------|
| GET | `/trackers` | List user trackers. |
| POST | `/trackers` | Create tracker. |
| PATCH | `/trackers/{id}` | Update tracker. |
| DELETE | `/trackers/{id}` | Delete tracker. |
| GET | `/trackers/progress` | Query: `trackerId`, `periodType`, etc. |
| POST | `/trackers/progress` | Log progress. |

### Notifications

| Method | Path | Description |
|--------|------|-------------|
| GET | `/notifications` | List for user (query: filters). |
| POST | `/notifications` | Create (e.g. from backend jobs). |
| POST | `/notifications/broadcast` | Create same notification for all users. Header: `X-Broadcast-Secret`. Body: `{ "title", "message", "type" }`. Requires `BROADCAST_SECRET` in .env. |
| PATCH | `/notifications/{id}/read` | Mark one as read. |
| POST | `/notifications/mark-all-read` | Mark all as read. |
| DELETE | `/notifications/{id}` | Delete one. |
| DELETE | `/notifications` | Delete all for user. |

### Tips

| Method | Path | Description |
|--------|------|-------------|
| GET | `/tips` | Returns tips (replace tip_service collection read). |

---

## Flutter refactor mapping

- **Auth**: `AuthController` → call `POST /auth/login`, `POST /auth/register`, `GET /auth/me`; store `access_token` and `user_id` (e.g. SharedPreferences). Use `Authorization: Bearer <token>` for all API calls.
- **Profile photo**: Replace `MongoDBService.getProfilePhoto(photoId)` with `GET /api/profile-photos/{photoId}` (same bytes).
- **Education**: `MongoArticleRepository` → new `HttpArticleRepository` that calls `/education/*`.
- **Pantry**: `PantryController` / `MongoPantryRepository` → HTTP client to `/pantry/*`.
- **Recipes**: `MongoRecipeRepository` → HTTP client to `/recipes/*`.
- **Trackers**: `TrackerService` / `TrackerProgressService` → HTTP client to `/trackers/*`.
- **Notifications**: `NotificationService` / `NotificationManager` → HTTP client to `/notifications/*`.
- **Tips**: `TipService` → `GET /tips`.

Remove `mongo_dart` and `MongoDBService` from the Flutter app once all calls are migrated.
