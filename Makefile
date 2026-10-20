COMPOSE = docker compose -f infra/docker-compose.yml

.PHONY: up down logs test test-backend test-app test-admin test-e2e test-calls api-client lint

up: infra/.env
	$(COMPOSE) up -d --build --wait

down:
	$(COMPOSE) down

logs:
	$(COMPOSE) logs -f

infra/.env:
	cp infra/.env.example infra/.env

test: test-backend test-app test-admin

test-backend:
	$(COMPOSE) exec -T api pytest -q

test-app:
	cd app && flutter test

test-admin:
	cd admin && npm test

# App <-> live dev API (needs `make up`).
test-e2e:
	cd app && flutter test --tags e2e --run-skipped -j 1 test/e2e  # one backend: run files in turn

# Regenerate the Dart API client after backend API changes.
api-client:
	app/packages/korram_api/tool/gen_api.sh

# M3: two headless LiveKit participants on shaped 4G / 3G links (needs `make up`).
test-calls:
	backend/calltest/run.sh

lint:
	cd backend && uv run ruff check . && uv run ruff format --check .
	cd app && flutter analyze
	cd admin && npm run lint
