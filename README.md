# October Cloud Runtimes

Official Docker runtime images for [October Cloud](https://octobercms.cloud). These images provide a shared foundation for local development, GitHub Codespaces, and production deployments.

[Click here to stay informed &rarr;](https://www.reddit.com/r/octobercms/)

## Images

The following images are published to GitHub Container Registry (GHCR) under the `octobercms` organization.

| Image                                                                                    | Purpose                                                  |
| ---------------------------------------------------------------------------------------- | -------------------------------------------------------- |
| [`runtime-base`](https://github.com/octobercms/runtimes/pkgs/container/runtime-base)     | Lean shared October/PHP foundation                       |
| [`runtime-build`](https://github.com/octobercms/runtimes/pkgs/container/runtime-build)   | Composer/Node tooling for app image builds               |
| [`runtime-dev`](https://github.com/octobercms/runtimes/pkgs/container/runtime-dev)       | Local/development runtime                                |
| [`runtime-prod`](https://github.com/octobercms/runtimes/pkgs/container/runtime-prod)     | Production HTTP/web runtime                              |
| [`runtime-worker`](https://github.com/octobercms/runtimes/pkgs/container/runtime-worker) | Production queue-worker runtime (CLI)                    |

```text
runtime-base
├── runtime-build
│   └── runtime-dev
└── runtime-prod

runtime-worker   (php:8.5-cli lineage; not derived from runtime-base)
```

### Base (`runtime-base`)

The base image is the lean shared layer for web runtimes. It is not intended to be run directly.

- PHP 8.5 FPM
- Extensions required by October CMS
- Working directory: `/var/www/html`
- No Node, Composer, git, or other build-only tooling

### Build (`runtime-build`)

Extends the base image with tooling for CodeBuild and multi-stage application Dockerfiles.

- Composer 2
- Node.js 24 with npm, pnpm, and yarn
- `git`, `jq`, `unzip`

Use this image (or a stage `FROM` it) to run `composer install` and front-end builds, then copy artifacts into `runtime-prod` / `runtime-worker`.

### Dev (`runtime-dev`)

Extends the build image for local and cloud development.

- PostgreSQL and SQLite drivers
- Nginx with the October CMS 4.x routing configuration
- Basic shell tooling (`bash`, `less`)
- Inherits Composer and Node from `runtime-build`

### Prod (`runtime-prod`)

Extends the base image for production HTTP/web use.

- Nginx with the October CMS 4.x routing configuration
- PHP-FPM production settings (including OPcache)
- Supervisor managing Nginx, PHP-FPM, and an opt-in scheduler
- Entrypoint that prepares October storage directories without a recursive `chown` on every start
- `/_alive` (liveness) and `/_health` (readiness via PHP)

The scheduler is opt-in. Set `OCTOBER_SCHEDULER_ENABLED=true` to run `php artisan schedule:work` when `/var/www/html/artisan` is present. When disabled, Supervisor does not start a scheduler process. Queue workers are not started by this image; run them on separate compute with `runtime-worker`.

### Worker (`runtime-worker`)

Built from `php:8.5-cli` for isolated production queue execution (no FPM, Nginx, or Supervisor). Platforms such as October Cloud can run the same application revision on `runtime-prod` (web) and `runtime-worker` (queues).

- PostgreSQL and SQLite drivers and production PHP settings (including OPcache)
- `pcntl` / `posix` for graceful worker signal handling
- Default process: `php artisan queue:work` as `www-data`
- Entrypoint that prepares October storage directories, then drops privileges
- No Nginx, PHP-FPM, Supervisor, scheduler, Node, Composer, or HTTP health endpoint

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
docker pull ghcr.io/octobercms/runtime-build:php85
```

Multi-stage application Dockerfile (recommended):

```dockerfile
FROM ghcr.io/octobercms/runtime-build:php85 AS build
WORKDIR /var/www/html
COPY . .
RUN composer install --no-dev --optimize-autoloader \
 && npm ci && npm run build

FROM ghcr.io/octobercms/runtime-prod:php85
COPY --from=build --chown=www-data:www-data /var/www/html /var/www/html
```

The same application filesystem works with the worker runtime by changing the final stage to `runtime-worker`. Mount your October CMS project at `/var/www/html`. The web root is the project root, matching October's expected layout.

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

Build the base image first, then build and specialized runtimes:

```bash
docker build -t runtime-base:local -f images/base/Dockerfile .

docker build -t runtime-build:local \
  --build-arg BASE_IMAGE=runtime-base:local \
  -f images/build/Dockerfile .

docker build -t runtime-dev:local \
  --build-arg BUILD_IMAGE=runtime-build:local \
  -f images/dev/Dockerfile .

docker build -t runtime-prod:local \
  --build-arg BASE_IMAGE=runtime-base:local \
  -f images/prod/Dockerfile .

docker build -t runtime-worker:local \
  -f images/worker/Dockerfile .
```

Run the prod image locally:

```bash
docker run --rm -p 8080:80 runtime-prod:local
curl http://localhost:8080/_alive
```

Run the worker image locally (mount an October/Laravel app that includes `artisan`):

```bash
docker run --rm -v "$PWD:/var/www/html" runtime-worker:local
# or with a platform-specific override:
docker run --rm -v "$PWD:/var/www/html" runtime-worker:local \
  php artisan queue:work --tries=3
```

## Project structure

```
.github/workflows/
├── ci.yml                   # Build and smoke test all images
└── publish.yml              # Publish images to GHCR

config/
├── nginx/default.conf       # October CMS Nginx configuration
├── php/runtime.ini          # Production PHP settings (incl. OPcache)
├── php-fpm/zz-runtime.conf  # PHP-FPM pool settings
└── supervisor/supervisord.conf

images/
├── base/Dockerfile          # Lean shared PHP-FPM foundation
├── build/Dockerfile         # Composer/Node build tooling
├── dev/Dockerfile           # Development runtime
├── prod/Dockerfile          # Production HTTP/web runtime
└── worker/Dockerfile        # Production queue-worker runtime (CLI)

scripts/
├── docker/install-october-php-extensions.sh  # Shared extension install for base/worker
├── entrypoint.sh                 # Prepares storage directories on startup
├── healthcheck.sh                # Checks /_alive from inside the container
├── scheduler.sh                  # Supervisor wrapper for php artisan schedule:work
├── prod-scheduler-smoke-test.sh  # Verifies schedule:work lifecycle in runtime-prod
├── worker-queue-smoke-test.sh    # Verifies queue:work lifecycle in runtime-worker
├── fixtures/                     # Minimal Laravel probes used by smoke tests
└── devcontainer-smoke-test.sh    # Installs October CMS and verifies /_alive and / return HTTP 200

.devcontainer/
├── devcontainer.json             # Dev container configuration
├── Dockerfile                    # Dev runtime wrapper for Codespaces
├── post-create.sh                # Installs October CMS into /var/www/html
├── post-start.sh                 # Starts PHP-FPM and Nginx
└── configure-app-url.sh          # Sets APP_URL and LINK_POLICY for dev/Codespaces
```

Opening this repository in a dev container clones [octobercms/october](https://github.com/octobercms/october) into `/var/www/html` during `postCreateCommand`, then starts the web stack on port 80 during `postStartCommand`.

The devcontainer smoke test uses the same install flow and verifies `/` and `/_alive` both return HTTP 200.

## CI and publishing

**CI** runs on every push and pull request. It builds all five images and runs smoke tests for PHP, extensions, Nginx configuration, prod liveness (`/_alive`) and readiness (`/_health` via PHP), the production scheduler lifecycle, worker queue processing, and a devcontainer flow that installs October CMS and verifies the homepage responds.

**Publish** pushes images to GHCR when:

- Changes are pushed to `main`
- A GitHub Release is published
- A git tag matching `v*` is pushed
- The workflow is triggered manually from the Actions tab

Images are published as public packages on GHCR and can be pulled without authentication.

## Health checks

The prod image separates liveness from readiness:

| Path       | Behavior                                      | Use for                                      |
| ---------- | --------------------------------------------- | -------------------------------------------- |
| `GET /_alive`  | Static nginx `200 ok` (does not hit PHP)  | Docker `HEALTHCHECK`, process liveness       |
| `GET /_health` | Passed to PHP-FPM / `index.php`           | ALB / target-group readiness                 |

`scripts/healthcheck.sh` probes `/_alive` so container health does not depend on application config. Orchestrators that should wait until the app can serve traffic must probe `/_health` (October Cloud serves this via `HealthCheckResponse` when the cloud module is present).

The worker image does not expose an HTTP health endpoint. Rely on process or orchestrator task state instead.

## Storage ownership

The entrypoint creates required storage directories with `mkdir -p`. It does **not** run a recursive `chown` on every start. Ownership should be set at image build time (`COPY --chown=www-data:www-data`). Set `OCTOBER_CHOWN_STORAGE=true` only when a volume layout requires a one-time recursive repair.

## License

[MIT](https://github.com/octobercms/runtimes/blob/main/LICENSE)

Copyright (c) 2026-present, October CMS.
