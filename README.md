[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/QoUMOW?utm_medium=integration&utm_source=button&utm_campaign=crawl4ai)

<!-- railway-overview:start -->

# Deploy and Host Crawl4AI with Railway

Crawl4AI is an open-source web crawler and scraper that turns web pages into clean, LLM-ready Markdown and structured data. Its self-hosted server exposes a REST API, a browser playground, and an MCP endpoint, so AI agents, RAG pipelines, and automation tools can crawl the web on demand.

## About Hosting Crawl4AI

Hosting Crawl4AI means running the official Crawl4AI Docker image, which bundles a FastAPI server, headless Chromium, and a private Redis instance managed by supervisord. Since version 0.9 the server refuses to accept outside connections unless an API token is configured, so every request except the health check must send `Authorization: Bearer <token>`. Chromium needs generous memory and shared memory. This template pins the image by version and digest, generates the API token for you, gives the container 1 GiB of `/dev/shm`, gates deploys on the `/health` endpoint, and exposes the API on a public HTTPS domain. No database or volume is needed.

## Common Use Cases

- Turn web pages into clean Markdown for RAG ingestion and LLM context.
- Give AI agents (Claude Code and other MCP clients) a web-crawling tool over MCP.
- Extract structured data from pages with natural-language prompts through the `/llm/job` endpoint (requires an LLM API key).
- Run crawls from automation tools such as n8n over plain HTTP.
- Capture screenshots and PDFs of pages from a server-side headless browser.

## Dependencies for Crawl4AI Hosting

- The official Crawl4AI Docker image (`unclecode/crawl4ai`), pinned by version and digest in this repository's `Dockerfile`.
- Bundled inside the image: headless Chromium (Playwright), Redis (loopback only, password-protected), Gunicorn with Uvicorn workers, and supervisord.
- Optional: an OpenAI or Anthropic API key for LLM-based extraction and filtering.

### Deployment Dependencies

- Crawl4AI repository: https://github.com/unclecode/crawl4ai
- Crawl4AI documentation: https://docs.crawl4ai.com/
- Crawl4AI self-hosting guide: https://docs.crawl4ai.com/core/self-hosting/
- Template source and changelog: https://github.com/salmanalfariz24/crawl4ai-railway

### Implementation Details

**Plan requirement.** Crawl4AI recommends at least 4 GB of RAM for the container. Deploy on the Railway Hobby plan or higher; the Free and Trial plans allow 0.5 GB and 1 GB of RAM per service.

**Scaling.** Keep one replica. Background jobs (`/crawl/job`, `/llm/job`) are stored in the container's own Redis, and Railway does not route a client back to the same replica. Railway gives the single replica more CPU and memory as needed, up to your plan's limit.

**Variables.**

| Variable                 | Set by template                   | Purpose                                                                                                                                               |
| ------------------------ | --------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| `CRAWL4AI_API_TOKEN`     | Generated 64-character hex secret | Bearer token for every endpoint except `/health`. Without it the server listens only inside the container and the deploy fails its healthcheck.       |
| `SECRET_KEY`             | Generated 64-character hex secret | Signs the short-lived internal tokens Crawl4AI's MCP tools use to call its own API. Upstream asks for a fixed value in real deployments.              |
| `PORT`                   | `11235`                           | Tells Railway which port to route traffic and healthchecks to. Crawl4AI always listens on 11235.                                                      |
| `RAILWAY_SHM_SIZE_BYTES` | `1073741824`                      | Gives the container 1 GiB of `/dev/shm` for Chromium, matching Crawl4AI's `--shm-size=1g` recommendation.                                             |
| `OPENAI_API_KEY`         | Empty (optional)                  | Enables LLM features with the default provider `openai/gpt-4o-mini`.                                                                                  |
| `ANTHROPIC_API_KEY`      | Empty (optional)                  | Enables LLM features with Anthropic models. Also set `LLM_PROVIDER`.                                                                                  |
| `LLM_PROVIDER`           | Empty (optional)                  | Default LLM in LiteLLM `provider/model` format. Requests can only select models from this provider's family. Leave empty to use `openai/gpt-4o-mini`. |

**Find your token.** Railway dashboard → your Crawl4AI service → **Variables** → `CRAWL4AI_API_TOKEN`.

**Call the API.** Replace `<your-domain>` with the domain shown under **Settings → Networking**.

```bash
export CRAWL4AI_URL="https://<your-domain>"
export CRAWL4AI_API_TOKEN="<your token>"

# Health (no token)
curl "$CRAWL4AI_URL/health"

# Crawl one or more URLs (max 100 per request)
curl -X POST "$CRAWL4AI_URL/crawl" \
  -H "Authorization: Bearer $CRAWL4AI_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"urls": ["https://example.com"]}'

# Markdown for a single URL
curl -X POST "$CRAWL4AI_URL/md" \
  -H "Authorization: Bearer $CRAWL4AI_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://example.com"}'
```

**Connect an MCP client.** The MCP endpoint is `https://<your-domain>/mcp/sse` (SSE transport). It requires the same `Authorization: Bearer` header. For Claude Code:

```bash
claude mcp add --transport sse crawl4ai "https://<your-domain>/mcp/sse" \
  --header "Authorization: Bearer <your token>"
```

Railway closes HTTP requests after 15 minutes, so long MCP sessions over SSE are cut periodically; Claude Code reconnects automatically.

**Web UI.** `https://<your-domain>/playground` (request builder) and `https://<your-domain>/dashboard` (monitoring) load without a token; their API calls need the token.

**Private networking.** Other services in the same Railway project can call `http://${{Crawl4AI.RAILWAY_PRIVATE_DOMAIN}}:11235` with the same Bearer header.

### Why Deploy Crawl4AI on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Crawl4AI on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.

This template uses Crawl4AI (https://github.com/unclecode/crawl4ai). This product includes software developed by UncleCode (https://x.com/unclecode) as part of the Crawl4AI project (https://github.com/unclecode/crawl4ai).

<!-- railway-overview:end -->

## Updates

This repository pins one exact Crawl4AI image. When a new Crawl4AI release passes the automated smoke test, it is merged to `main` and Railway shows an update notice in projects deployed from this template. Updates are opt-in: review [`CHANGELOG.md`](CHANGELOG.md) before applying one.

## Maintaining this template

1. Dependabot opens a pull request every Monday (07:00 Asia/Jakarta) when a newer `unclecode/crawl4ai` release exists. It updates the tag and the digest in `Dockerfile`.
2. The `smoke` check builds the image and verifies health, version, authentication, a real crawl, the MCP endpoint, and `/dev/shm`. The `changelog` check fails until `CHANGELOG.md` contains the new image reference.
3. Read the upstream release notes and `deploy/docker/MIGRATION.md` at the new tag. On the pull request branch, add a release section to `CHANGELOG.md` that contains the exact image reference from `Dockerfile` in backticks.
4. When both checks pass, squash-merge. Then create the tag and GitHub release `vX.Y.Z` for the new `CHANGELOG.md` section.

Run the smoke test locally with `./scripts/smoke-test.sh` (needs Docker, curl, openssl, and python3).

## Security

See [SECURITY.md](SECURITY.md). Report vulnerabilities privately; never post tokens in issues.

## License and attribution

The files in this repository are licensed under the [Apache License 2.0](LICENSE). Crawl4AI is developed by UncleCode and licensed under the Apache License 2.0 with an attribution requirement; see [NOTICE](NOTICE).

This product includes software developed by UncleCode (https://x.com/unclecode) as part of the Crawl4AI project (https://github.com/unclecode/crawl4ai).

[![Powered by Crawl4AI](https://img.shields.io/badge/Powered%20by-Crawl4AI-blue?style=flat-square)](https://github.com/unclecode/crawl4ai)
