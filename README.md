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
| Moderator console | http://localhost:5174 (create a login: see below) |
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
regenerate the Dart client (`app/packages/korram_api`, its own package so the code
generators don't share dependency versions with the app); CI fails if they drift.

`make test-calls` runs the M3 call acceptance: two headless LiveKit participants in the
LiveKit container's network namespace, on `tc netem`-shaped 4G and 3G links, with mute,
camera-off and 5 s / 15 s outages.

### Moderator console (M4)

```sh
docker compose -f infra/docker-compose.yml exec api \
  python manage.py create_moderator +2348000000001 'a-strong-password'
```

Then sign in at http://localhost:5174 with that phone and password. The `moderator` Compose
service is the moderation agent: a hidden participant in every video call that samples frames
(1 s for the first 30 s, then 2 s) and acts on hits (SF-2, SF-3). With the fake provider,
a magenta frame counts as explicit and a cyan frame as someone under 18. `make test-calls`
includes the end-to-end check.

### Calls on a real phone (dev)

LiveKit tells clients which IP to send media to (`127.0.0.1` by default: right for the
emulator and the call tests). For a phone on the same Wi-Fi as your Mac:

1. In `infra/.env` set `LIVEKIT_NODE_IP=<mac-lan-ip>` and
   `LIVEKIT_URL=ws://<mac-lan-ip>:7880`, then `make up`.
2. `cd app && flutter run --dart-define=API_BASE_URL=http://<mac-lan-ip>:8100`

On mobile data behind carrier NAT, calls need TURN (LiveKit's built-in TURN on 443/TLS);
that's configured with hosting, not in local dev (docs/questions.md #24).

### Dev flags

| Where | Flag | Values |
|---|---|---|
| `infra/.env` | `FAKE_LIVENESS` | `pass` / `fail` / `underage` (fake selfie outcome) |
| `infra/.env` | `PROVIDER_SMS`, `PROVIDER_IDENTITY`, … | `fake` until real providers are chosen |
| `flutter run --dart-define` | `API_BASE_URL` | default `http://10.0.2.2:8100` (Android emulator) / `http://127.0.0.1:8100` |
| `flutter run --dart-define` | `SOCIAL_SIGN_IN` | `fake` (default), `real`, `off` |
| `infra/.env` | `PROVIDER_PUSH` | `fake` (default: pushes are logged) / `fcm` with `FCM_PROJECT_ID` and `FCM_CREDENTIALS_JSON` (service-account key) |
| `flutter run --dart-define` | `PUSH` | unset (default: no Firebase) / `fcm` (needs `google-services.json` / `GoogleService-Info.plist`) |
| `infra/.env` | `PROVIDER_STORE_RECEIPTS` | `fake` (default: tokens `fake:<product>:<txn>`) / `real` with `PLAY_PACKAGE_NAME`, `PLAY_CREDENTIALS_JSON`, `PLAY_RTDN_SECRET`, `APPLE_BUNDLE_ID`, `APPLE_APP_ID`, `APPLE_ENVIRONMENT`, `APPLE_ROOT_CERTS_DIR` |

In development the phone code is printed in the API logs:
`docker compose -f infra/docker-compose.yml logs api | grep "fake sms code"`.
Pushes to friends who are offline are logged the same way: `grep "fake push to"`.

**Coins (M6).** Store webhooks are `POST /api/v1/webhooks/google?secret=…` (Pub/Sub push) and
`POST /api/v1/webhooks/apple` (App Store Server Notifications v2); in development they need a
public HTTPS tunnel. The gift catalogue is edited in Django admin. Check the ledger with
`docker compose -f infra/docker-compose.yml exec api python manage.py check_ledger` (also runs
nightly).
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
