#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status
set -u  # Treat unset variables as an error

# Initialize desktop configuration files if they don't exist in the volume
HOME_DIR=/home/desktop
DEFAULT_DIR=/etc/desktop-defaults

echo "=== Desktop Initialization Script ==="
echo "HOME_DIR: $HOME_DIR"
echo "DEFAULT_DIR: $DEFAULT_DIR"
echo "Current user: $(whoami)"
echo "Current UID: $(id -u)"
echo "Current GID: $(id -g)"

# Detect target UID/GID from environment variables or volume ownership
TARGET_UID="${HOST_UID:-}"
TARGET_GID="${HOST_GID:-}"

# If not set via environment, try to detect from volume ownership
if [ -z "$TARGET_UID" ] || [ -z "$TARGET_GID" ]; then
    if [ -d "$HOME_DIR" ]; then
        VOLUME_UID=$(stat -c '%u' "$HOME_DIR" 2>/dev/null || echo "")
        VOLUME_GID=$(stat -c '%g' "$HOME_DIR" 2>/dev/null || echo "")
        if [ -n "$VOLUME_UID" ] && [ -n "$VOLUME_GID" ]; then
            TARGET_UID="${TARGET_UID:-$VOLUME_UID}"
            TARGET_GID="${TARGET_GID:-$VOLUME_GID}"
            echo "Detected UID/GID from volume: $TARGET_UID:$TARGET_GID"
        fi
    fi
fi

# If still not set, use current desktop user UID/GID
if [ -z "$TARGET_UID" ] || [ -z "$TARGET_GID" ]; then
    DESKTOP_UID=$(id -u desktop 2>/dev/null || echo "")
    DESKTOP_GID=$(id -g desktop 2>/dev/null || echo "")
    TARGET_UID="${TARGET_UID:-$DESKTOP_UID}"
    TARGET_GID="${TARGET_GID:-$DESKTOP_GID}"
    echo "Using desktop user UID/GID: $TARGET_UID:$TARGET_GID"
fi

echo "Target UID/GID: $TARGET_UID:$TARGET_GID"

# Get current desktop user UID/GID
CURRENT_DESKTOP_UID=$(id -u desktop 2>/dev/null || echo "")
CURRENT_DESKTOP_GID=$(id -g desktop 2>/dev/null || echo "")

# Modify desktop user to match target UID/GID if different
if [ -n "$TARGET_UID" ] && [ -n "$TARGET_GID" ] && \
   [ -n "$CURRENT_DESKTOP_UID" ] && [ -n "$CURRENT_DESKTOP_GID" ]; then
    if [ "$CURRENT_DESKTOP_UID" != "$TARGET_UID" ] || [ "$CURRENT_DESKTOP_GID" != "$TARGET_GID" ]; then
        echo ""
        echo "=== Modifying desktop user to match host UID/GID ==="
        echo "Current desktop UID/GID: $CURRENT_DESKTOP_UID:$CURRENT_DESKTOP_GID"
        echo "Target UID/GID: $TARGET_UID:$TARGET_GID"
        
        # Check if target group exists, create if not
        if ! getent group "$TARGET_GID" >/dev/null 2>&1; then
            echo "Creating group with GID $TARGET_GID..."
            groupadd -g "$TARGET_GID" desktop_group 2>/dev/null || {
                # If group with that GID exists, use it
                EXISTING_GROUP=$(getent group "$TARGET_GID" | cut -d: -f1)
                echo "Group with GID $TARGET_GID already exists: $EXISTING_GROUP"
                groupmod -g "$TARGET_GID" desktop 2>/dev/null || {
                    echo "Modifying desktop group to GID $TARGET_GID..."
                    usermod -g "$TARGET_GID" desktop 2>/dev/null || true
                }
            }
        fi
        
        # Modify desktop group to target GID
        if [ "$CURRENT_DESKTOP_GID" != "$TARGET_GID" ]; then
            echo "Modifying desktop group GID from $CURRENT_DESKTOP_GID to $TARGET_GID..."
            groupmod -g "$TARGET_GID" desktop 2>/dev/null || {
                echo "Warning: Could not modify group GID, trying alternative method..."
                # Alternative: change primary group
                EXISTING_GROUP=$(getent group "$TARGET_GID" | cut -d: -f1)
                if [ -n "$EXISTING_GROUP" ]; then
                    usermod -g "$EXISTING_GROUP" desktop 2>/dev/null || true
                fi
            }
        fi
        
        # Modify desktop user to target UID
        if [ "$CURRENT_DESKTOP_UID" != "$TARGET_UID" ]; then
            echo "Modifying desktop user UID from $CURRENT_DESKTOP_UID to $TARGET_UID..."
            usermod -u "$TARGET_UID" desktop 2>/dev/null || {
                echo "Warning: Could not modify user UID (may require container restart)"
            }
        fi
        
        echo "Desktop user modification completed"
        echo "New desktop UID/GID: $(id -u desktop 2>/dev/null || echo 'unknown'):$(id -g desktop 2>/dev/null || echo 'unknown')"
    else
        echo "Desktop user UID/GID already matches target: $TARGET_UID:$TARGET_GID"
    fi
fi

# Function to fix ownership of existing files
fix_ownership() {
    local target_dir="$1"
    local target_uid="$2"
    local target_gid="$3"
    
    echo ""
    echo "=== Fixing ownership of files in $target_dir ==="
    echo "Target ownership: $target_uid:$target_gid"
    
    if [ ! -d "$target_dir" ]; then
        echo "Directory $target_dir does not exist, skipping ownership fix"
        return 0
    fi
    
    # Try to fix ownership as root first
    if chown -R "$target_uid:$target_gid" "$target_dir" 2>/dev/null; then
        echo "✓ Ownership fixed successfully (as root)"
        return 0
    fi
    
    # If that fails, try as desktop user (for podman scenarios)
    echo "Attempting to fix ownership as desktop user..."
    if runuser -u desktop -- chown -R "$target_uid:$target_gid" "$target_dir" 2>/dev/null; then
        echo "✓ Ownership fixed successfully (as desktop user)"
        return 0
    fi
    
    echo "Warning: Could not fix ownership of $target_dir"
    echo "This may be normal in some container environments (e.g., podman with rootless mode)"
    return 1
}

# Fix ownership of existing files in home directory
if [ -n "$TARGET_UID" ] && [ -n "$TARGET_GID" ]; then
    fix_ownership "$HOME_DIR" "$TARGET_UID" "$TARGET_GID"
fi

# Check if home directory exists
if [ ! -d "$HOME_DIR" ]; then
    echo "ERROR: Home directory $HOME_DIR does not exist!"
    exit 1
fi

# Show current permissions of home directory
echo "Home directory info:"
ls -ld "$HOME_DIR" || true
stat -c "Owner: %U:%G, Permissions: %a" "$HOME_DIR" 2>/dev/null || true

# Detect if we're running with podman (volume has host ownership)
# Check if home directory is owned by desktop user
if [ -d "$HOME_DIR" ]; then
    OWNER=$(stat -c '%U' "$HOME_DIR" 2>/dev/null || echo "unknown")
    PERMS=$(stat -c '%a' "$HOME_DIR" 2>/dev/null || echo "unknown")
    echo "Home directory owner: $OWNER, permissions: $PERMS"
    if [ "$OWNER" != "desktop" ]; then
        PODMAN_MODE=true
        echo "*** Detected podman mode: volume has host ownership ($OWNER), using permissive permissions ***"
        
        # In podman mode, we can't modify permissions of mounted volumes as root
        # We'll work directly as desktop user instead
        echo "Note: In podman mode, will create directories as desktop user (root may not be able to modify mounted volumes)"
        
        # Check if desktop user can write to home directory
        echo "Testing if desktop user can write to home directory..."
        if runuser -u desktop -- touch "$HOME_DIR/.test_write" 2>&1; then
            runuser -u desktop -- rm -f "$HOME_DIR/.test_write" 2>&1
            echo "  ✓ Desktop user can write to home directory"
        else
            echo "  ✗ WARNING: Desktop user cannot write to home directory"
            echo "  This may cause issues. Home directory should have permissions 777 or be owned by desktop user."
        fi
        ls -ld "$HOME_DIR" || true
    else
        PODMAN_MODE=false
        echo "Normal docker mode: volume owned by desktop user"
    fi
else
    PODMAN_MODE=false
    echo "Normal docker mode (home directory check failed)"
fi

# Function to create directory with proper permissions
create_dir() {
    local dir="$1"
    local parent_dir=$(dirname "$dir")
    echo ""
    echo "Creating directory: $dir"
    echo "  Parent directory: $parent_dir"
    
    # Check parent directory permissions
    if [ -d "$parent_dir" ]; then
        echo "  Checking parent directory permissions..."
        PARENT_PERMS=$(stat -c '%a' "$parent_dir" 2>/dev/null || echo "unknown")
        PARENT_OWNER=$(stat -c '%U:%G' "$parent_dir" 2>/dev/null || echo "unknown")
        echo "  Parent permissions: $PARENT_PERMS, owner: $PARENT_OWNER"
        
        # Test write access to parent
        echo "  Testing write access to parent as current user ($(whoami))..."
        if touch "$parent_dir/.test_write" 2>&1; then
            rm -f "$parent_dir/.test_write" 2>&1
            echo "    ✓ Current user can write to parent"
        else
            echo "    ✗ Current user cannot write to parent"
        fi
        
        echo "  Testing write access to parent as desktop user..."
        if runuser -u desktop -- touch "$parent_dir/.test_write" 2>&1; then
            runuser -u desktop -- rm -f "$parent_dir/.test_write" 2>&1
            echo "    ✓ Desktop user can write to parent"
        else
            echo "    ✗ Desktop user cannot write to parent"
        fi
    fi
    
    if [ "$PODMAN_MODE" = "true" ]; then
        # With podman, try as desktop user first (since root may not be able to modify mounted volumes)
        echo "  Attempting as desktop user (podman mode)..."
        if runuser -u desktop -- mkdir -p "$dir" 2>&1; then
            echo "  ✓ Directory created as desktop user"
            # Try to set permissions, but don't fail if it doesn't work
            runuser -u desktop -- chmod 777 "$dir" 2>&1 || echo "  WARNING: Could not set permissions, but directory exists"
        else
            echo "  ✗ Failed as desktop user, trying as root..."
            # Fallback to root
            if mkdir -p "$dir" 2>&1; then
                echo "  ✓ Directory created as root"
                chmod 777 "$dir" 2>&1 || echo "  WARNING: Could not set permissions"
            else
                echo "  ✗ ERROR: Failed to create directory $dir even as root"
                echo "  Parent directory info:"
                ls -ld "$parent_dir" || true
                exit 1
            fi
        fi
    else
        # Normal docker mode, try as root first
        echo "  Attempting as root..."
        if mkdir -p "$dir" 2>&1; then
            echo "  ✓ Directory created as root"
            if chown desktop:desktop "$dir" 2>&1; then
                echo "  ✓ Ownership set to desktop:desktop"
            else
                echo "  WARNING: Failed to set ownership, trying as desktop user..."
                if runuser -u desktop -- mkdir -p "$dir" 2>&1; then
                    echo "  ✓ Directory created as desktop user"
                else
                    echo "  ✗ ERROR: Failed to create directory $dir"
                    exit 1
                fi
            fi
        else
            echo "  ✗ ERROR: Failed to create directory $dir as root"
            exit 1
        fi
    fi
    
    # Verify directory was created
    if [ ! -d "$dir" ]; then
        echo "  ✗ ERROR: Directory $dir does not exist after creation attempt!"
        exit 1
    fi
    
    # Show final permissions
    echo "  Final permissions:"
    ls -ld "$dir" || true
}

# Create necessary directories
echo ""
echo "=== Creating configuration directories ==="
create_dir "$HOME_DIR/.config"
create_dir "$HOME_DIR/.config/openbox"
create_dir "$HOME_DIR/.config/tint2"
create_dir "$HOME_DIR/.local"
create_dir "$HOME_DIR/.local/share"
create_dir "$HOME_DIR/.local/share/applications"

# Function to copy file with proper permissions
copy_file() {
    local src="$1"
    local dst="$2"
    local perms="${3:-666}"
    
    echo ""
    echo "Copying file: $src -> $dst"
    
    if [ ! -f "$src" ]; then
        echo "  ✗ ERROR: Source file $src does not exist!"
        exit 1
    fi
    
    # Ensure destination directory exists
    local dst_dir=$(dirname "$dst")
    if [ ! -d "$dst_dir" ]; then
        echo "  Creating destination directory: $dst_dir"
        create_dir "$dst_dir"
    fi
    
    if [ "$PODMAN_MODE" = "true" ]; then
        # With podman, try as desktop user first
        echo "  Copying as desktop user (podman mode)..."
        if runuser -u desktop -- cp "$src" "$dst" 2>&1; then
            echo "  ✓ File copied"
            # Try to set permissions, but don't fail if it doesn't work
            runuser -u desktop -- chmod "$perms" "$dst" 2>&1 || echo "  WARNING: Could not set permissions, but file exists"
        else
            echo "  ✗ Failed as desktop user, trying as root..."
            # Fallback to root
            if cp "$src" "$dst" 2>&1; then
                echo "  ✓ File copied as root"
                chmod "$perms" "$dst" 2>&1 || echo "  WARNING: Could not set permissions"
            else
                echo "  ✗ ERROR: Failed to copy file even as root"
                exit 1
            fi
        fi
    else
        # Normal docker mode
        echo "  Copying as root..."
        if cp "$src" "$dst" 2>&1; then
            echo "  ✓ File copied"
            if chown desktop:desktop "$dst" 2>&1; then
                echo "  ✓ Ownership set to desktop:desktop"
            else
                echo "  WARNING: Failed to set ownership, trying as desktop user..."
                if runuser -u desktop -- cp "$src" "$dst" 2>&1; then
                    echo "  ✓ File copied as desktop user"
                else
                    echo "  ✗ ERROR: Failed to copy file"
                    exit 1
                fi
            fi
        else
            echo "  ✗ ERROR: Failed to copy file"
            exit 1
        fi
    fi
    
    # Verify file was copied
    if [ ! -f "$dst" ]; then
        echo "  ✗ ERROR: File $dst does not exist after copy attempt!"
        exit 1
    fi
    
    echo "  Final file info:"
    ls -l "$dst" || true
}

# Copy Openbox menu if it doesn't exist
echo ""
echo "=== Copying Openbox menu ==="
if [ ! -f "$HOME_DIR/.config/openbox/menu.xml" ]; then
    copy_file "$DEFAULT_DIR/.config/openbox/menu.xml" "$HOME_DIR/.config/openbox/menu.xml" "666"
else
    echo "Menu.xml already exists, skipping"
fi

# Initialize or update autostart file
echo ""
echo "=== Initializing autostart file ==="
AUTOSTART_FILE="$HOME_DIR/.config/openbox/autostart"
if [ ! -f "$AUTOSTART_FILE" ]; then
    copy_file "$DEFAULT_DIR/.config/openbox/autostart" "$AUTOSTART_FILE" "777"
else
    echo "Autostart file already exists"
    # Ensure hsetroot is in autostart if not present
    if ! grep -q "hsetroot" "$AUTOSTART_FILE"; then
        echo "Adding hsetroot to autostart..."
        if [ "$PODMAN_MODE" = "true" ]; then
            echo 'hsetroot -solid "#123456" &' >> "$AUTOSTART_FILE" || {
                echo "  ✗ ERROR: Failed to append to autostart file"
                exit 1
            }
            chmod 777 "$AUTOSTART_FILE" || {
                echo "  ✗ ERROR: Failed to set permissions on autostart file"
                exit 1
            }
        else
            echo 'hsetroot -solid "#123456" &' >> "$AUTOSTART_FILE" || {
                echo "  ✗ ERROR: Failed to append to autostart file"
                exit 1
            }
            chown desktop:desktop "$AUTOSTART_FILE" || {
                echo "  ✗ ERROR: Failed to set ownership on autostart file"
                exit 1
            }
        fi
        echo "  ✓ hsetroot added to autostart"
    fi
fi

# Copy tint2 configuration if it doesn't exist
echo ""
echo "=== Copying tint2 configuration ==="
if [ ! -f "$HOME_DIR/.config/tint2/tint2rc" ]; then
    copy_file "$DEFAULT_DIR/.config/tint2/tint2rc" "$HOME_DIR/.config/tint2/tint2rc" "666"
else
    echo "tint2rc already exists, skipping"
fi

# Ensure README exists
echo ""
echo "=== Copying README ==="
if [ ! -f "$HOME_DIR/README.txt" ]; then
    copy_file "$DEFAULT_DIR/README.txt" "$HOME_DIR/README.txt" "666"
else
    echo "README.txt already exists, skipping"
fi

# Final permission fix
echo ""
echo "=== Final permission check ==="
if [ "$PODMAN_MODE" = "true" ]; then
    echo "Attempting to set permissive permissions for podman mode..."
    # Try as desktop user first
    if runuser -u desktop -- chmod -R 777 "$HOME_DIR/.config" "$HOME_DIR/.local" 2>&1; then
        echo "  ✓ Permissions set on .config/.local (as desktop user)"
    else
        echo "  WARNING: Could not set permissions as desktop user, trying as root..."
        chmod -R 777 "$HOME_DIR/.config" "$HOME_DIR/.local" 2>&1 || {
            echo "  WARNING: Could not set permissions even as root (this is normal in podman with mounted volumes)"
        }
    fi
    if runuser -u desktop -- chmod 666 "$HOME_DIR/README.txt" 2>&1; then
        echo "  ✓ Permissions set on README.txt (as desktop user)"
    else
        chmod 666 "$HOME_DIR/README.txt" 2>&1 || {
            echo "  WARNING: Could not set permissions on README.txt (this is normal in podman with mounted volumes)"
        }
    fi
else
    echo "Setting ownership for docker mode..."
    chown -R desktop:desktop "$HOME_DIR/.config" "$HOME_DIR/.local" 2>&1 || {
        echo "  WARNING: Failed to set ownership (may be normal if volume is mounted)"
    }
    chown desktop:desktop "$HOME_DIR/README.txt" 2>&1 || {
        echo "  WARNING: Failed to set ownership (may be normal if volume is mounted)"
    }
fi

echo ""
echo "=== Summary ==="
echo "Configuration files initialized successfully!"
echo "Home directory structure:"
ls -la "$HOME_DIR" 2>/dev/null || true
echo ""
echo "Config directory structure:"
ls -la "$HOME_DIR/.config" 2>/dev/null || true
echo ""
echo "=== Starting supervisord ==="

# Start supervisord directly as root
# supervisord.conf has user=desktop, so supervisord will handle user switching internally
# Running via runuser breaks /dev/fd/1 access for logging
echo "Starting supervisord (will run as desktop user via supervisord.conf)"
exec /usr/bin/supervisord
