# October Cloud Runtimes

Official Docker runtime images for [October Cloud](https://octobercms.cloud). These images provide a shared foundation for local development, GitHub Codespaces, and production deployments.

[Click here to stay informed &rarr;](https://www.reddit.com/r/octobercms/)

## Images

The following images are published to GitHub Container Registry (GHCR) under the `octobercms` organization.

| Image                                                                                    | Purpose                                                  |
| ---------------------------------------------------------------------------------------- | -------------------------------------------------------- |
| [`runtime-base`](https://github.com/octobercms/runtimes/pkgs/container/runtime-base)     | Shared October/PHP foundation                            |
| [`runtime-dev`](https://github.com/octobercms/runtimes/pkgs/container/runtime-dev)       | Local/development runtime                                |
| [`runtime-prod`](https://github.com/octobercms/runtimes/pkgs/container/runtime-prod)     | Production HTTP/web runtime                              |
| [`runtime-worker`](https://github.com/octobercms/runtimes/pkgs/container/runtime-worker) | Production queue-worker runtime                          |

```text
runtime-base
├── runtime-dev
├── runtime-prod
└── runtime-worker
```

### Base (`runtime-base`)

The base image is the shared layer for all runtimes. It is not intended to be run directly.

- PHP 8.5 FPM
- Composer 2
- Node.js 24 with npm, pnpm, and yarn
- Extensions required by October CMS
- Working directory: `/var/www/html`

Nginx and Supervisor are intentionally excluded so worker and web runtimes can reuse the same base.

### Dev (`runtime-dev`)

Extends the base image for local and cloud development.

- PostgreSQL and SQLite drivers
- Nginx with the October CMS 4.x routing configuration
- Basic shell tooling (`bash`, `less`)

### Prod (`runtime-prod`)

Extends the base image for production HTTP/web use.

- Nginx with the October CMS 4.x routing configuration
- PHP-FPM production settings
- Supervisor managing Nginx, PHP-FPM, and `php artisan schedule:work`
- Entrypoint that prepares October storage directories
- `/_health` endpoint for container health checks

The scheduler is opt-in. Set `OCTOBER_SCHEDULER_ENABLED=true` to run `php artisan schedule:work` when `/var/www/html/artisan` is present. Queue workers are not started by this image; run them on separate compute with `runtime-worker`.

### Worker (`runtime-worker`)

Extends the base image for isolated production queue execution. Platforms such as October Cloud can run the same application revision on `runtime-prod` (web) and `runtime-worker` (queues).

- PostgreSQL and SQLite drivers and production PHP settings
- `pcntl` / `posix` for graceful worker signal handling
- Default process: `php artisan queue:work` as `www-data`
- Entrypoint that prepares October storage directories, then drops privileges
- No Nginx, PHP-FPM service, Supervisor, scheduler, or HTTP health endpoint

Queue backend, timeout, retry, sleep, and concurrency arguments are left to the platform. Override the command when needed:

```bash
docker run --rm ghcr.io/octobercms/runtime-worker:php85 \
  php artisan queue:work sqs --timeout=90 --tries=3
```

Worker health should be based on process/task state (for example ECS task health), not HTTP reachability. Logs go to stdout/stderr for the container logging driver.

## Usage

Pull a published image:

```bash
docker pull ghcr.io/octobercms/runtime-dev:php85
docker pull ghcr.io/octobercms/runtime-prod:php85
docker pull ghcr.io/octobercms/runtime-worker:php85
```

Use the prod image as a base in an application Dockerfile:

```dockerfile
FROM ghcr.io/octobercms/runtime-prod:php85

COPY . /var/www/html
RUN composer install --no-dev --optimize-autoloader
```

The same application image layering works with the worker runtime by changing the base image to `runtime-worker` (or by running the built application filesystem under the worker runtime). Mount your October CMS project at `/var/www/html`. The web root is the project root, matching October's expected layout.

## Tags

Each publish pushes several tags per image:

| Tag                         | Example                                 | Notes                                      |
| --------------------------- | --------------------------------------- | ------------------------------------------ |
| `php85`                     | `runtime-prod:php85`                    | Moving tag for the current PHP 8.5 runtime |
| `latest`                    | `runtime-prod:latest`                   | Moving tag for the latest publish          |
| `php85-YYYY.MM.DD`          | `runtime-prod:php85-2026.06.11`         | Date pin (UTC)                             |
| `php85-YYYY.MM.DD-SHORTSHA` | `runtime-prod:php85-2026.06.11-abc1234` | Immutable pin per build                    |
| `php85-X.Y.Z`               | `runtime-prod:php85-1.0.0`              | Version pin from a release or `v*` tag     |
| `X.Y.Z`                     | `runtime-prod:1.0.0`                    | Version pin from a release or `v*` tag     |

For production, prefer an immutable tag such as a date-SHA or semver tag rather than `php85` or `latest`.

## Local builds

Build the base image first, then build the specialized runtimes against it:

```bash
docker build -t runtime-base:local -f images/base/Dockerfile .

docker build -t runtime-dev:local \
  --build-arg BASE_IMAGE=runtime-base:local \
  -f images/dev/Dockerfile .

docker build -t runtime-prod:local \
  --build-arg BASE_IMAGE=runtime-base:local \
  -f images/prod/Dockerfile .

docker build -t runtime-worker:local \
  --build-arg BASE_IMAGE=runtime-base:local \
  -f images/worker/Dockerfile .
```

Run the prod image locally:

```bash
docker run --rm -p 8080:80 runtime-prod:local
curl http://localhost:8080/_health
```

Run the worker image locally:

```bash
docker run --rm runtime-worker:local
# or with a platform-specific override:
docker run --rm runtime-worker:local php artisan queue:work --tries=3
```

## Project structure

```
.github/workflows/
├── ci.yml                   # Build and smoke test all images
└── publish.yml              # Publish images to GHCR

config/
├── nginx/default.conf       # October CMS Nginx configuration
├── php/runtime.ini          # Production PHP settings
├── php-fpm/zz-runtime.conf  # PHP-FPM pool settings
└── supervisor/supervisord.conf

images/
├── base/Dockerfile          # Shared PHP foundation
├── dev/Dockerfile           # Development runtime
├── prod/Dockerfile          # Production HTTP/web runtime
└── worker/Dockerfile        # Production queue-worker runtime

scripts/
├── entrypoint.sh                 # Prepares storage directories on startup
├── healthcheck.sh                # Checks /_health from inside the container
├── scheduler.sh                  # Supervisor wrapper for php artisan schedule:work
├── prod-scheduler-smoke-test.sh  # Verifies schedule:work lifecycle in runtime-prod
├── worker-queue-smoke-test.sh    # Verifies queue:work lifecycle in runtime-worker
├── fixtures/                     # Minimal Laravel probes used by smoke tests
└── devcontainer-smoke-test.sh    # Installs October CMS and verifies /_health and / return HTTP 200

.devcontainer/
├── devcontainer.json             # Dev container configuration
├── Dockerfile                    # Dev runtime wrapper for Codespaces
├── post-create.sh                # Installs October CMS into /var/www/html
├── post-start.sh                 # Starts PHP-FPM and Nginx
└── configure-app-url.sh          # Sets APP_URL and LINK_POLICY for dev/Codespaces
```

Opening this repository in a dev container clones [octobercms/october](https://github.com/octobercms/october) into `/var/www/html` during `postCreateCommand`, then starts the web stack on port 80 during `postStartCommand`.

The devcontainer smoke test uses the same install flow and verifies `/` and `/_health` both return HTTP 200.

## CI and publishing

**CI** runs on every push and pull request. It builds all four images and runs smoke tests for PHP, extensions, Nginx configuration, the prod `/_health` endpoint, the production scheduler lifecycle, worker queue processing, and a devcontainer flow that installs October CMS and verifies the homepage responds.

**Publish** pushes images to GHCR when:

- Changes are pushed to `main`
- A GitHub Release is published
- A git tag matching `v*` is pushed
- The workflow is triggered manually from the Actions tab

Images are published as public packages on GHCR and can be pulled without authentication.

## Health checks

The prod image exposes a static health endpoint that does not hit PHP:

```
GET /_health → 200 ok
```

This is used by the Docker `HEALTHCHECK` instruction and by `scripts/healthcheck.sh`.

The worker image does not expose an HTTP health endpoint. Rely on process or orchestrator task state instead.

## License

[MIT](https://github.com/octobercms/runtimes/blob/main/LICENSE)

Copyright (c) 2026-present, October CMS.
