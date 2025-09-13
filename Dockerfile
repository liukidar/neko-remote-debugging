# Installs Chromium browser and socat (network proxy tool)
# ADDED: socat package for creating network proxy to solve Chromium's localhost-only binding
ARG BASE_IMAGE=ghcr.io/m1k1o/neko/base:latest
FROM $BASE_IMAGE

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends openbox socat xdotool scrot chromium xvfb; \
    # Clean up
    apt-get clean -y; \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/*

# Copy configuration files
COPY supervisord.conf /etc/neko/supervisord/chromium.conf
COPY --chown=neko preferences.json /home/neko/.config/chromium/Default/Preferences
COPY policies.json /etc/chromium/policies/managed/policies.json
COPY openbox.xml /etc/neko/openbox.xml
COPY neko.yaml /etc/neko/neko.yaml

# Create chromium profile directory with correct permissions
RUN mkdir -p /tmp/chromium-profile && \
    chmod -R 777 /tmp/chromium-profile