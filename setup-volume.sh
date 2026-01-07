#!/bin/bash
# Setup script to prepare the home-desktop volume directory with correct permissions

VOLUME_DIR="$(dirname "$0")/home-desktop"

# Create directory if it doesn't exist
mkdir -p "$VOLUME_DIR"

# Set permissions to allow container user to write
# This allows the desktop user in the container to create files
chmod 777 "$VOLUME_DIR" 2>/dev/null || {
    echo "Warning: Could not set permissions on $VOLUME_DIR"
    echo "You may need to run this script with sudo or adjust permissions manually"
}

echo "Volume directory prepared: $VOLUME_DIR"
ls -ld "$VOLUME_DIR"
