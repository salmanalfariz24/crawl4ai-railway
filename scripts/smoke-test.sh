#!/usr/bin/env bash
# Smoke test for the Crawl4AI Railway template.
# Builds the repository Dockerfile, runs it the way Railway runs it, and checks
# the public contract documented in README.md. Used by CI and runnable locally.
# Requirements: docker, curl, openssl, python3.
set -euo pipefail

cd "$(dirname "$0")/.."

IMAGE="crawl4ai-railway:smoke"
CONTAINER="crawl4ai-smoke"
HOST_PORT="${HOST_PORT:-11235}"
BASE_URL="http://127.0.0.1:${HOST_PORT}"
HEALTH_TIMEOUT_SEC="${HEALTH_TIMEOUT_SEC:-120}"
EXPECTED_SHM_BYTES=1073741824

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

cleanup() { docker rm -f "$CONTAINER" >/dev/null 2>&1 || true; }
trap cleanup EXIT

# 1. The Dockerfile must be exactly one pinned FROM line.
[ "$(grep -c . Dockerfile)" -eq 1 ] || fail "Dockerfile must contain exactly one non-empty line"
EXPECTED_VERSION="$(sed -nE 's#^FROM unclecode/crawl4ai:([0-9]+\.[0-9]+\.[0-9]+)@sha256:[0-9a-f]{64}$#\1#p' Dockerfile)"
[ -n "$EXPECTED_VERSION" ] || fail "Dockerfile must be: FROM unclecode/crawl4ai:X.Y.Z@sha256:<64 hex chars>"
pass "Dockerfile pins Crawl4AI ${EXPECTED_VERSION} by digest"

# 2. Build exactly what Railway builds.
docker build --pull -t "$IMAGE" .
pass "image built"

# 3. Run it the way Railway runs it: token and SECRET_KEY set, PORT=11235, 1 GiB /dev/shm.
TOKEN="$(openssl rand -hex 32)"
SECRET="$(openssl rand -hex 32)"
cleanup
docker run -d --name "$CONTAINER" \
  --shm-size=1g \
  -e CRAWL4AI_API_TOKEN="$TOKEN" \
  -e SECRET_KEY="$SECRET" \
  -e PORT=11235 \
  -p "127.0.0.1:${HOST_PORT}:11235" \
  "$IMAGE" >/dev/null

# 4. Wait for /health (no token needed).
deadline=$(( $(date +%s) + HEALTH_TIMEOUT_SEC ))
until curl -fsS "${BASE_URL}/health" >/dev/null 2>&1; do
  if [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER")" != "true" ]; then
    docker logs "$CONTAINER" >&2 || true
    fail "container exited before /health answered"
  fi
  if [ "$(date +%s)" -ge "$deadline" ]; then
    docker logs "$CONTAINER" >&2 || true
    fail "/health did not answer within ${HEALTH_TIMEOUT_SEC}s"
  fi
  sleep 2
done
pass "/health answered"

# 5. /health reports status ok and the pinned version.
HEALTH_JSON="$(curl -fsS "${BASE_URL}/health")"
echo "$HEALTH_JSON" | EXPECTED_VERSION="$EXPECTED_VERSION" python3 -c '
import json, os, sys
d = json.load(sys.stdin)
assert d.get("status") == "ok", d
assert d.get("version") == os.environ["EXPECTED_VERSION"], d
' || fail "/health returned ${HEALTH_JSON}; expected status ok and version ${EXPECTED_VERSION}"
pass "/health reports version ${EXPECTED_VERSION}"

# 6. POST /crawl without a token is rejected.
code="$(curl -s -o /dev/null -w '%{http_code}' -X POST "${BASE_URL}/crawl" \
  -H 'Content-Type: application/json' -d '{"urls":["https://example.com"]}')"
[ "$code" = "401" ] || fail "unauthenticated POST /crawl returned ${code}, expected 401"
pass "unauthenticated POST /crawl -> 401"

# 7. POST /crawl with a wrong token is rejected.
code="$(curl -s -o /dev/null -w '%{http_code}' -X POST "${BASE_URL}/crawl" \
  -H 'Authorization: Bearer wrong-token' \
  -H 'Content-Type: application/json' -d '{"urls":["https://example.com"]}')"
[ "$code" = "401" ] || fail "wrong-token POST /crawl returned ${code}, expected 401"
pass "wrong-token POST /crawl -> 401"

# 8. POST /crawl with the token crawls https://example.com.
CRAWL_JSON="$(curl -fsS --max-time 120 -X POST "${BASE_URL}/crawl" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H 'Content-Type: application/json' -d '{"urls":["https://example.com"]}')" \
  || fail "authenticated POST /crawl did not return HTTP 2xx"
echo "$CRAWL_JSON" | python3 -c '
import json, sys
d = json.load(sys.stdin)
assert d.get("success") is True, "top-level success is not true"
r = d["results"][0]
assert r.get("success") is True, "results[0].success is not true: %s" % r.get("error_message")
md = r.get("markdown") or {}
assert (md.get("raw_markdown") or "").strip(), "results[0].markdown.raw_markdown is empty"
' || fail "authenticated POST /crawl response failed validation"
pass "authenticated POST /crawl -> success true with markdown"

# 9. MCP SSE endpoint: 401 without a token, endpoint event with a token.
code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "${BASE_URL}/mcp/sse")"
[ "$code" = "401" ] || fail "unauthenticated GET /mcp/sse returned ${code}, expected 401"
SSE_OUT="$(curl -s -N --max-time 5 -H "Authorization: Bearer ${TOKEN}" "${BASE_URL}/mcp/sse" || true)"
echo "$SSE_OUT" | grep -q '^event: endpoint' || fail "authenticated GET /mcp/sse did not send 'event: endpoint'"
pass "MCP SSE: 401 without token, endpoint event with token"

# 10. /dev/shm inside the container is exactly 1 GiB.
docker exec "$CONTAINER" df -h /dev/shm
SHM_BYTES="$(docker exec "$CONTAINER" df -B1 --output=size /dev/shm | tail -n 1 | tr -d ' ')"
[ "$SHM_BYTES" = "$EXPECTED_SHM_BYTES" ] || fail "/dev/shm is ${SHM_BYTES} bytes, expected ${EXPECTED_SHM_BYTES}"
pass "/dev/shm is ${EXPECTED_SHM_BYTES} bytes (1 GiB)"

echo "ALL SMOKE CHECKS PASSED for Crawl4AI ${EXPECTED_VERSION}"
