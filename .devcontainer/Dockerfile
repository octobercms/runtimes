ARG DEV_IMAGE=ghcr.io/octobercms/runtime-dev:php85
FROM ${DEV_IMAGE}

COPY .devcontainer/post-create.sh /usr/local/bin/devcontainer-post-create.sh
COPY .devcontainer/post-start.sh /usr/local/bin/devcontainer-post-start.sh
COPY .devcontainer/configure-app-url.sh /usr/local/bin/devcontainer-configure-app-url.sh

RUN chmod +x \
    /usr/local/bin/devcontainer-post-create.sh \
    /usr/local/bin/devcontainer-post-start.sh \
    /usr/local/bin/devcontainer-configure-app-url.sh
