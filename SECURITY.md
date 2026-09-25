# Security Policy

## Scope

This repository contains only Railway template configuration for Crawl4AI: a
one-line `Dockerfile`, documentation, and CI. It does not contain Crawl4AI
source code.

| Problem | Where to report |
| --- | --- |
| A vulnerability in this template's configuration or CI (for example, a setting that exposes a deployment without authentication) | Privately, through this repository's **Security → Report a vulnerability** form |
| A vulnerability in Crawl4AI itself (server, crawler, Docker image) | Upstream, following https://github.com/unclecode/crawl4ai/blob/main/SECURITY.md |
| A vulnerability in Railway's platform | Railway, following https://railway.com/bug-bounty (email bugbounty@railway.com) |

Do not open public issues for security problems.

## Supported versions

Only the latest release of this template (the newest entry in `CHANGELOG.md`)
receives fixes.

## Response

The maintainer acknowledges private reports within 7 days and publishes a fix
or mitigation, with a `### Security` entry in `CHANGELOG.md`, as soon as one is
available.

## If your API token leaks

Your `CRAWL4AI_API_TOKEN` grants full (admin-scope) access to your deployment.
If it leaks, open your Railway service → **Variables**, replace
`CRAWL4AI_API_TOKEN` with a new value (for example the output of
`openssl rand -hex 32`), and deploy the staged change. The old token stops
working when the new deployment is live.
