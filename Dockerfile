# Installs Chromium browser and socat (network proxy tool)
# ADDED: socat package for creating network proxy to solve Chromium's localhost-only binding
ARG BASE_IMAGE=ghcr.io/m1k1o/neko/base:latest
FROM $BASE_IMAGE

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends openbox socat xdotool scrot chromium xvfb ; \
    # Clean up
    apt-get clean -y; \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/*

# Copy configuration files
COPY supervisord.conf /etc/neko/supervisord/chromium.conf
COPY --chown=neko preferences.json /home/neko/.config/chromium/Default/Preferences
COPY policies.json /etc/chromium/policies/managed/policies.json
COPY openbox.xml /etc/neko/openbox.xml
COPY neko.yaml /etc/neko/neko.yaml

# Copy extension
COPY --chown=neko extension/ /home/neko/extension/

# Create necessary directories and dummy audio config
RUN mkdir -p /tmp/chromium-profile && \
    chmod -R 777 /tmp/chromium-profile && \
    # Create X11 socket directory for the X server
    mkdir -p /tmp/.X11-unix && \
    chmod 1777 /tmp/.X11-unix && \
    # Create directory for Neko input driver socket
    mkdir -p /tmp && \
    chown -R neko:neko /tmp && \
    # Create dummy ALSA config for audio support without actual audio
    mkdir -p /home/neko/.asoundrc.d && \
    echo 'pcm.!default { type null }' > /home/neko/.asoundrc && \
    echo 'ctl.!default { type null }' >> /home/neko/.asoundrc && \
    chown -R neko:neko /home/neko/.asoundrc