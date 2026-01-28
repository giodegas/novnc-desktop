#!/bin/bash
set -e

# Docker entrypoint: reconfigure desktop user with host UID/GID if needed
# This allows Docker to use the same UID/GID as the host user, similar to Podman's keep-id
# With Podman (userns_mode: keep-id), HOST_UID/HOST_GID are not set, so we skip reconfiguration

echo "=== Docker Entrypoint ==="
echo "Current user: $(whoami) (UID=$(id -u), GID=$(id -g))"

# Check if we're running as root and have HOST_UID/HOST_GID set (Docker mode)
# With Podman keep-id, these variables are not set, so we proceed normally
if [ "$(id -u)" = "0" ] && [ -n "$HOST_UID" ] && [ -n "$HOST_GID" ]; then
    echo "Reconfiguring desktop user with host UID/GID: $HOST_UID:$HOST_GID"
    
    # Get current desktop user UID/GID
    CURRENT_UID=$(id -u desktop 2>/dev/null || echo "")
    CURRENT_GID=$(id -g desktop 2>/dev/null || echo "")
    
    # Only reconfigure if UID/GID are different
    if [ "$CURRENT_UID" != "$HOST_UID" ] || [ "$CURRENT_GID" != "$HOST_GID" ]; then
        echo "Changing desktop user UID from $CURRENT_UID to $HOST_UID"
        echo "Changing desktop group GID from $CURRENT_GID to $HOST_GID"
        
        # Change group GID if needed
        if [ "$CURRENT_GID" != "$HOST_GID" ]; then
            # Check if target GID already exists
            if getent group "$HOST_GID" > /dev/null 2>&1; then
                EXISTING_GROUP=$(getent group "$HOST_GID" | cut -d: -f1)
                if [ "$EXISTING_GROUP" != "desktop" ]; then
                    echo "Warning: GID $HOST_GID already used by group $EXISTING_GROUP"
                    echo "Renaming group $EXISTING_GROUP to desktop-temp"
                    groupmod -n desktop-temp "$EXISTING_GROUP"
                fi
            fi
            groupmod -g "$HOST_GID" desktop
        fi
        
        # Change user UID if needed
        if [ "$CURRENT_UID" != "$HOST_UID" ]; then
            # Check if target UID already exists
            if getent passwd "$HOST_UID" > /dev/null 2>&1; then
                EXISTING_USER=$(getent passwd "$HOST_UID" | cut -d: -f1)
                if [ "$EXISTING_USER" != "desktop" ]; then
                    echo "Warning: UID $HOST_UID already used by user $EXISTING_USER"
                    echo "Renaming user $EXISTING_USER to desktop-temp"
                    usermod -l desktop-temp "$EXISTING_USER"
                fi
            fi
            usermod -u "$HOST_UID" desktop
        fi
        
        # Update ownership of home directory
        echo "Updating ownership of /home/desktop to $HOST_UID:$HOST_GID"
        chown -R "$HOST_UID:$HOST_GID" /home/desktop
        
        # Update ownership of other directories that desktop might need
        chown -R "$HOST_UID:$HOST_GID" /tmp/.X11-unix 2>/dev/null || true
    else
        echo "Desktop user already has correct UID/GID"
    fi
    
    # Switch to desktop user and execute init script
    echo "Switching to desktop user and starting initialization..."
    exec gosu desktop /usr/local/bin/init-desktop.sh "$@"
else
    # Not root or no HOST_UID/HOST_GID set, run init script as-is
    echo "Running as non-root or without HOST_UID/HOST_GID, proceeding normally"
    exec /usr/local/bin/init-desktop.sh "$@"
fi
