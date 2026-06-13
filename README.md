# October CMS Runtimes

Official Docker runtime images for [October CMS](https://octobercms.com). These images provide a shared foundation for local development, GitHub Codespaces, and production deployments.

## Images

The following images are published to GitHub Container Registry (GHCR) under the `octobercms` organization.

| Image                                                                                | Purpose                                                  |
| ------------------------------------------------------------------------------------ | -------------------------------------------------------- |
| [`runtime-base`](https://github.com/octobercms/runtimes/pkgs/container/runtime-base) | Shared PHP foundation used by the other images           |
| [`runtime-dev`](https://github.com/octobercms/runtimes/pkgs/container/runtime-dev)   | Development environments, dev containers, and Codespaces |
| [`runtime-prod`](https://github.com/octobercms/runtimes/pkgs/container/runtime-prod) | Production deployments                                   |

### Base (`runtime-base`)

The base image is the shared layer for all runtimes. It is not intended to be run directly.

- PHP 8.5 FPM
- Composer 2
- Extensions required by October CMS
- Working directory: `/var/www/html`

Nginx and Supervisor are intentionally excluded so future worker or scheduler runtimes can reuse the same base.

### Dev (`runtime-dev`)

Extends the base image for local and cloud development.

- PostgreSQL and SQLite drivers
- Nginx with the October CMS 4.x routing configuration
- Basic shell tooling (`bash`, `less`)

### Prod (`runtime-prod`)

Extends the base image for production use.

- Nginx with the October CMS 4.x routing configuration
- PHP-FPM production settings
- Supervisor managing Nginx and PHP-FPM
- Entrypoint that prepares October storage directories
- `/_health` endpoint for container health checks

## Usage

Pull a published image:

```bash
docker pull ghcr.io/octobercms/runtime-dev:php85
docker pull ghcr.io/octobercms/runtime-prod:php85
```

Use the prod image as a base in an application Dockerfile:

```dockerfile
FROM ghcr.io/octobercms/runtime-prod:php85

COPY . /var/www/html
RUN composer install --no-dev --optimize-autoloader
```

Mount your October CMS project at `/var/www/html`. The web root is the project root, matching October's expected layout.

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

Build the base image first, then build dev or prod against it:

```bash
docker build -t runtime-base:local -f images/base/Dockerfile .

docker build -t runtime-dev:local \
  --build-arg BASE_IMAGE=runtime-base:local \
  -f images/dev/Dockerfile .

docker build -t runtime-prod:local \
  --build-arg BASE_IMAGE=runtime-base:local \
  -f images/prod/Dockerfile .
```

Run the prod image locally:

```bash
docker run --rm -p 8080:80 runtime-prod:local
curl http://localhost:8080/_health
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
└── prod/Dockerfile          # Production runtime

scripts/
├── entrypoint.sh                 # Prepares storage directories on startup
├── healthcheck.sh                # Checks /_health from inside the container
└── devcontainer-smoke-test.sh    # Installs October CMS and verifies /_health and / return HTTP 200

.devcontainer/
├── devcontainer.json             # Dev container configuration
├── Dockerfile                    # Dev runtime wrapper for Codespaces
├── post-create.sh                # Installs October CMS into /var/www/html
├── post-start.sh                 # Starts PHP-FPM and Nginx
└── configure-app-url.sh          # Sets APP_URL and LINK_POLICY for dev/Codespaces
```

Opening this repository in a dev container clones [octobercms/october](https://github.com/octobercms/october) into `/var/www/html` during `postCreateCommand`, then starts the web stack on port 80 during `postStartCommand`.

The devcontainer smoke test uses the same install flow and verifies `/_health` and `/` both return HTTP 200.

## CI and publishing

**CI** runs on every push and pull request. It builds all three images and runs smoke tests for PHP, extensions, Nginx configuration, the prod `/_health` endpoint, and a devcontainer flow that installs October CMS and verifies the homepage responds.

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

## License

[MIT](https://github.com/octobercms/runtimes/blob/main/LICENSE)

Copyright (c) 2026-present, October CMS.
