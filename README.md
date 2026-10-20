# Korram

Random video, voice and text chats with verified people. Nigeria first.

- Spec: [`docs/PRD.md`](docs/PRD.md) · Working rules: [`CLAUDE.md`](CLAUDE.md)
- Designs: `design/screens/*.dc.html` (open in a browser; 390 × 844 frames)
- Milestone plans: `docs/plans/` · Open questions: [`docs/questions.md`](docs/questions.md)

## Layout

| Path | What |
|---|---|
| `backend/` | Django 5.2, DRF, Channels, Celery (Python 3.12, managed with `uv`) |
| `app/` | Flutter app (Android + iOS) |
| `admin/` | React + Vite moderator console |
| `infra/` | Docker Compose for local development |

## Run it

Needs Docker, Flutter 3.32, Node 22 and `uv`.

```sh
make up            # postgres, redis, minio, livekit, api, worker, matcher, admin
curl localhost:8100/api/v1/health   # {"status":"ok","db":true,"redis":true}
cd app && flutter run               # Welcome screen
```

| Service | URL |
|---|---|
| API | http://localhost:8100/api/v1/ (OpenAPI schema at `/api/v1/schema/`) |
| Websocket | ws://localhost:8100/ws/?token=<access JWT> |
| Moderator console | http://localhost:5174 |
| MinIO console | http://localhost:9001 (credentials in `infra/.env`) |
| LiveKit | ws://localhost:7880 |
| Postgres / Redis | localhost:5433 / localhost:6380 (offset to avoid local installs) |

## Test

```sh
make test   # backend (inside the api container), app, admin
make lint
```

`make test-e2e` runs the app's real API layer against the running stack (codes are read
from the fake SMS provider's log lines). After changing the API, run `make api-client` to
regenerate the Dart client from the OpenAPI schema; CI fails if they drift.

### Dev flags

| Where | Flag | Values |
|---|---|---|
| `infra/.env` | `FAKE_LIVENESS` | `pass` / `fail` / `underage` (fake selfie outcome) |
| `infra/.env` | `PROVIDER_SMS`, `PROVIDER_IDENTITY`, … | `fake` until real providers are chosen |
| `flutter run --dart-define` | `API_BASE_URL` | default `http://10.0.2.2:8100` (Android emulator) / `http://127.0.0.1:8100` |
| `flutter run --dart-define` | `SOCIAL_SIGN_IN` | `fake` (default), `real`, `off` |

In development the phone code is printed in the API logs:
`docker compose -f infra/docker-compose.yml logs api | grep "fake sms code"`.
Manual selfie reviews are approved or rejected in Django admin at
http://localhost:8100/django-admin/ (create a login with
`docker compose -f infra/docker-compose.yml exec api python manage.py createsuperuser`).

### Matching load test (M2)

```sh
docker compose -f infra/docker-compose.yml --profile load up -d api-load   # uvicorn, 4 workers
docker compose -f infra/docker-compose.yml exec api \
  python manage.py loadtest --users 500 --duration 180 --url ws://api-load:8000/ws/
```

It fails if any blocked pair is matched or the median wait is 10 s or more. Run it on a
machine with free memory: swapping causes multi-second stalls that look like server bugs.

App golden images (`app/test/goldens/`) are rendered on macOS. After an intended UI change,
run `flutter test --update-goldens --tags golden`.
