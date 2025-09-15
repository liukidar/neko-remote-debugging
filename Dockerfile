# Installs Chrome for Testing (developer-friendly) and required tools
# ADDED: socat package for creating network proxy to solve Chrome's localhost-only binding
ARG BASE_IMAGE=ghcr.io/m1k1o/neko/base:latest
FROM $BASE_IMAGE

# Install Node.js and required packages
RUN set -eux; \
    apt-get update; \
    # Install Node.js 20.x
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -; \
    apt-get install -y --no-install-recommends \
        nodejs \
        openbox \
        socat \
        xdotool \
        scrot \
        xvfb \
        # Chrome for Testing dependencies
        libasound2 \
        libatk-bridge2.0-0 \
        libdrm2 \
        libxkbcommon0 \
        libxss1 \
        libgconf-2-4 \
        libxrandr2 \
        libasound2 \
        libpangocairo-1.0-0 \
        libatk1.0-0 \
        libcairo-gobject2 \
        libgtk-3-0 \
        libgdk-pixbuf2.0-0; \
    # Install Chrome for Testing using Puppeteer
    npx @puppeteer/browsers install chrome@stable --path /opt/chrome; \
    # Create symlink for easier access
    CHROME_PATH=$(find /opt/chrome -name "chrome" -type f | head -1); \
    ln -sf "$CHROME_PATH" /usr/bin/google-chrome; \
    ln -sf "$CHROME_PATH" /usr/bin/chrome; \
    # Clean up
    apt-get clean -y; \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/* /root/.npm

# Copy configuration files
COPY supervisord.conf /etc/neko/supervisord/google-chrome.conf
COPY --chown=root preferences.json /home/neko/.config/google-chrome/Default/Preferences
# Copy policies for Chrome for Testing
COPY policies.json /etc/opt/chrome/policies/managed/policies.json
# COPY openbox.xml /etc/neko/openbox.xml
COPY neko.yaml /etc/neko/neko.yaml

# Copy extension
COPY --chown=root extension/ /home/neko/extension/

# Create necessary directories and dummy audio config
RUN mkdir -p /tmp/chrome-profile && \
    chmod -R 777 /tmp/chrome-profile && \
    # Create policies directory for Chrome for Testing
    mkdir -p /etc/opt/chrome/policies/managed && \
    # Pre-create chrome profile structure for faster startup
    mkdir -p /tmp/chrome-profile/Default && \
    # Create X11 socket directory for the X server
    mkdir -p /tmp/.X11-unix && \
    chmod 1777 /tmp/.X11-unix && \
    # Create directory for Neko input driver socket
    mkdir -p /tmp && \
    chown -R root:root /tmp && \
    # Create recordings directory for video recording
    mkdir -p /recording && \
    chown -R root:root /recording && \
    chmod -R 775 /recording && \
    # Create dummy ALSA config for audio support without actual audio
    mkdir -p /home/neko/.asoundrc.d && \
    echo 'pcm.!default { type null }' > /home/neko/.asoundrc && \
    echo 'ctl.!default { type null }' >> /home/neko/.asoundrc && \
    chown -R root:root /home/neko/.asoundrc && \
    # Create uBlock Origin configuration to enable it by default
    mkdir -p /home/neko/.config/google-chrome/Default/Extensions/cjpalhdlnbpafiamejdnhcphjbkeiagm && \
    chown -R root:root /home/neko/.config/google-chrome && \
    # Pre-warm Chrome by creating cache directories
    mkdir -p /tmp/chrome-profile/Default/Local\ Storage && \
    mkdir -p /tmp/chrome-profile/Default/Session\ Storage && \
    mkdir -p /tmp/chrome-profile/ShaderCache && \
    chmod -R 777 /tmp/chrome-profile

# Add startup script to log current user
RUN echo '#!/bin/bash' > /usr/local/bin/startup.sh && \
    echo 'echo "Container starting as user: $(whoami) (UID: $(id -u), GID: $(id -g))"' >> /usr/local/bin/startup.sh && \
    echo 'echo "User details: $(id)"' >> /usr/local/bin/startup.sh && \
    echo 'touch /recording/file.txt' >> /usr/local/bin/startup.sh && \
    echo 'exec "$@"' >> /usr/local/bin/startup.sh && \
    chmod +x /usr/local/bin/startup.sh

ENTRYPOINT ["/usr/local/bin/startup.sh"]
