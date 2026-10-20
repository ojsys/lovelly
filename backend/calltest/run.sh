#!/usr/bin/env sh
# M3 call acceptance: real LiveKit, two headless participants, shaped network.
#   backend/calltest/run.sh     (needs `make up`)
set -eu
cd "$(dirname "$0")"
COMPOSE="docker compose -f ../../infra/docker-compose.yml"
docker build -q -t korram-calltest . >/dev/null
$COMPOSE exec -T api python manage.py calltest_setup \
  | docker run --rm -i --network container:korram-livekit-1 --cap-add NET_ADMIN korram-calltest
