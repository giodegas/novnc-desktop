#!/bin/bash
# Don't use set -e, we need to handle errors gracefully when volume is mounted

# Initialize desktop configuration files if they don't exist in the volume
HOME_DIR=/home/desktop
DEFAULT_DIR=/etc/desktop-defaults

# Create necessary directories
# Try as root first, if that fails (e.g., volume mounted), try as desktop user
mkdir -p "$HOME_DIR/.config/openbox" 2>/dev/null || \
    runuser -u desktop -- mkdir -p "$HOME_DIR/.config/openbox" 2>/dev/null || true

mkdir -p "$HOME_DIR/.config/tint2" 2>/dev/null || \
    runuser -u desktop -- mkdir -p "$HOME_DIR/.config/tint2" 2>/dev/null || true

mkdir -p "$HOME_DIR/.local/share/applications" 2>/dev/null || \
    runuser -u desktop -- mkdir -p "$HOME_DIR/.local/share/applications" 2>/dev/null || true

# Copy Openbox menu if it doesn't exist
if [ ! -f "$HOME_DIR/.config/openbox/menu.xml" ]; then
    cp "$DEFAULT_DIR/.config/openbox/menu.xml" "$HOME_DIR/.config/openbox/menu.xml" || \
        runuser -u desktop -- cp "$DEFAULT_DIR/.config/openbox/menu.xml" "$HOME_DIR/.config/openbox/menu.xml"
    chown desktop:desktop "$HOME_DIR/.config/openbox/menu.xml" 2>/dev/null || true
fi

# Initialize or update autostart file
AUTOSTART_FILE="$HOME_DIR/.config/openbox/autostart"
if [ ! -f "$AUTOSTART_FILE" ]; then
    # Copy default autostart file
    cp "$DEFAULT_DIR/.config/openbox/autostart" "$AUTOSTART_FILE" || \
        runuser -u desktop -- cp "$DEFAULT_DIR/.config/openbox/autostart" "$AUTOSTART_FILE"
    chown desktop:desktop "$AUTOSTART_FILE" 2>/dev/null || true
    chmod +x "$AUTOSTART_FILE" 2>/dev/null || runuser -u desktop -- chmod +x "$AUTOSTART_FILE" 2>/dev/null || true
else
    # Ensure hsetroot is in autostart if not present
    if ! grep -q "hsetroot" "$AUTOSTART_FILE"; then
        echo 'hsetroot -solid "#123456" &' >> "$AUTOSTART_FILE" || \
            runuser -u desktop -- sh -c "echo 'hsetroot -solid \"#123456\" &' >> \"$AUTOSTART_FILE\""
        chown desktop:desktop "$AUTOSTART_FILE" 2>/dev/null || true
    fi
fi

# Copy tint2 configuration if it doesn't exist
if [ ! -f "$HOME_DIR/.config/tint2/tint2rc" ]; then
    cp "$DEFAULT_DIR/.config/tint2/tint2rc" "$HOME_DIR/.config/tint2/tint2rc" || \
        runuser -u desktop -- cp "$DEFAULT_DIR/.config/tint2/tint2rc" "$HOME_DIR/.config/tint2/tint2rc"
    chown desktop:desktop "$HOME_DIR/.config/tint2/tint2rc" 2>/dev/null || true
fi

# Ensure README exists
if [ ! -f "$HOME_DIR/README.txt" ]; then
    cp "$DEFAULT_DIR/README.txt" "$HOME_DIR/README.txt" || \
        runuser -u desktop -- cp "$DEFAULT_DIR/README.txt" "$HOME_DIR/README.txt"
    chown desktop:desktop "$HOME_DIR/README.txt" 2>/dev/null || true
fi

# Fix ownership of home directory (only for files we created/modified)
chown -R desktop:desktop "$HOME_DIR/.config" "$HOME_DIR/.local" 2>/dev/null || true
chown desktop:desktop "$HOME_DIR/README.txt" 2>/dev/null || true

# Switch to desktop user and start supervisord
# Use runuser if available (better for containers), otherwise fall back to su
if command -v runuser >/dev/null 2>&1; then
    exec runuser -u desktop -- /usr/bin/supervisord
else
    exec su desktop -c "/usr/bin/supervisord"
fi
