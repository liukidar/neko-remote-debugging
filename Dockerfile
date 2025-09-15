# Installs Google Chrome browser and socat (network proxy tool)
# ADDED: socat package for creating network proxy to solve Chrome's localhost-only binding
ARG BASE_IMAGE=ghcr.io/m1k1o/neko/base:latest
FROM $BASE_IMAGE

ARG SRC_URL="https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"

RUN set -eux; \
    apt-get update; \
    wget -O /tmp/google-chrome.deb "${SRC_URL}"; \
    apt-get install -y --no-install-recommends openbox socat xdotool scrot xvfb /tmp/google-chrome.deb; \
    # Clean up
    apt-get clean -y; \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/* /tmp/google-chrome.deb

# Copy configuration files
COPY supervisord.conf /etc/neko/supervisord/google-chrome.conf
COPY --chown=neko preferences.json /home/neko/.config/google-chrome/Default/Preferences
COPY policies.json /etc/opt/chrome/policies/managed/policies.json
COPY openbox.xml /etc/neko/openbox.xml
COPY neko.yaml /etc/neko/neko.yaml

# Copy extension
COPY --chown=neko extension/ /home/neko/extension/

# Create necessary directories and dummy audio config
RUN mkdir -p /tmp/chrome-profile && \
    chmod -R 777 /tmp/chrome-profile && \
    # Pre-create chrome profile structure for faster startup
    mkdir -p /tmp/chrome-profile/Default && \
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
    chown -R neko:neko /home/neko/.asoundrc && \
    # Create uBlock Origin configuration to enable it by default
    mkdir -p /home/neko/.config/google-chrome/Default/Extensions/cjpalhdlnbpafiamejdnhcphjbkeiagm && \
    chown -R neko:neko /home/neko/.config/google-chrome && \
    # Pre-warm Chrome by creating cache directories
    mkdir -p /tmp/chrome-profile/Default/Local\ Storage && \
    mkdir -p /tmp/chrome-profile/Default/Session\ Storage && \
    mkdir -p /tmp/chrome-profile/ShaderCache && \
    chmod -R 777 /tmp/chrome-profile