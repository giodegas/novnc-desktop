#!/bin/bash
set -e

# Initialize desktop configuration files if they don't exist in the volume
HOME_DIR=/home/desktop
DEFAULT_DIR=/etc/desktop-defaults

echo "=== Desktop Initialization Script ==="
echo "Current user: $(whoami) (UID=$(id -u), GID=$(id -g))"

# Check if home directory exists
if [ ! -d "$HOME_DIR" ]; then
    echo "ERROR: Home directory $HOME_DIR does not exist!"
    exit 1
fi

# Detect if we're running with userns_mode: keep-id (not root)
KEEP_ID_MODE=false
if [ "$(id -u)" != "0" ]; then
    KEEP_ID_MODE=true
    echo "Keep-id mode: running as non-root user"
fi

# Test write access
echo "Testing write access to $HOME_DIR..."
if touch "$HOME_DIR/.test_write" 2>/dev/null; then
    rm -f "$HOME_DIR/.test_write"
    echo "  OK: Can write to home directory"
else
    echo "  WARNING: Cannot write to home directory"
fi

# Create directory helper
create_dir() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir" && echo "Created: $dir" || echo "Failed to create: $dir"
    fi
}

# Copy file helper
copy_file() {
    local src="$1"
    local dst="$2"
    if [ ! -f "$dst" ] && [ -f "$src" ]; then
        cp "$src" "$dst" && echo "Copied: $dst" || echo "Failed to copy: $dst"
    fi
}

echo ""
echo "=== Creating directories ==="
create_dir "$HOME_DIR/.config/openbox"
create_dir "$HOME_DIR/.config/tint2"
create_dir "$HOME_DIR/.local/share/applications"

echo ""
echo "=== Copying configuration files ==="
copy_file "$DEFAULT_DIR/.config/openbox/menu.xml" "$HOME_DIR/.config/openbox/menu.xml"
copy_file "$DEFAULT_DIR/.config/openbox/autostart" "$HOME_DIR/.config/openbox/autostart"
copy_file "$DEFAULT_DIR/.config/tint2/tint2rc" "$HOME_DIR/.config/tint2/tint2rc"
copy_file "$DEFAULT_DIR/README.txt" "$HOME_DIR/README.txt"

echo ""
echo "=== Final status ==="
echo "Home directory:"
ls -la "$HOME_DIR" 2>/dev/null || true

echo ""
echo "=== Starting supervisord ==="
exec /usr/bin/supervisord
