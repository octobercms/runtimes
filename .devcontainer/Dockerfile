ARG DEV_IMAGE=ghcr.io/octobercms/runtime-dev:php85
FROM ${DEV_IMAGE}

COPY .devcontainer/post-start.sh /usr/local/bin/devcontainer-post-start.sh
RUN chmod +x /usr/local/bin/devcontainer-post-start.sh
