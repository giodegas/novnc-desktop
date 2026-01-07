# noVNC-desktop

A relatively small noVNC (web-based) desktop Docker image

Originally from repo: https://hub.docker.com/r/prbinu/novnc-desktop

## Features

* Debian Trixie slim Docker base image (optimized size, ~60MB base)
* [easy-novnc](https://github.com/geek1011/easy-novnc) - A Golang based noVNC binary
* [TigerVNC](https://tigervnc.org/) - supports auto screen resizing (both x86_64 and ARM64)
* [Openbox](http://openbox.org/wiki/Main_Page) - A light weight window manager
* Firefox ESR - Browser (no snap dependencies, from Debian repositories)
* Non-root user (desktop) for improved security
* Includes basic utilities such as `ssh`, `curl` , `uv`  etc.
* Volume persistence support with automatic configuration initialization

This Dockerfile is derived from <a href="https://www.digitalocean.com/community/tutorials/how-to-remotely-access-gui-applications-using-docker-and-caddy-on-debian-9" target="_blank">how-to-remotely-access-gui-applications-using-docker-and-caddy-on-debian-9</a>

## Screenshots

<p align="center">
  <img src="images/terminal.png" width="80%" height="80%">
</p>

<p align="center">
  <img src="images/firefox.png" width="80%" height="80%">
</p>

## Build

### Intel architectures

```bash
git clone https://github.com/giodegas/novnc-desktop.git
cd novnc-desktop

docker build --squash -t novnc-desktop .
```

### ARM64 architectures

(including RaspberryPI and Apple M1)

```bash
git clone https://github.com/giodegas/novnc-desktop.git
cd novnc-desktop

docker build -t novnc-desktop -f Dockerfile.arm64 .
```

## Run

### Using Docker Compose (Recommended)

Docker Compose is the recommended way to run the container, especially if you want to persist your data:

```bash
# Prepare the volume directory with correct permissions
./setup-volume.sh

# Build and start the container
docker-compose up -d
```

#### Using Podman Compose

When using podman-compose with `userns_mode: keep-id`, you need to disable pod mode to avoid conflicts:

```bash
# Set the environment variable to disable pod mode
export PODMAN_COMPOSE_IN_POD=0

# Build and start the container
podman compose up -d
```

Or in a single command:

```bash
PODMAN_COMPOSE_IN_POD=0 podman compose up -d
```

**Note**: The `userns_mode: keep-id` option in `docker-compose.yaml` maps the container user to your host UID/GID. This is incompatible with podman's default pod mode, hence the need for `PODMAN_COMPOSE_IN_POD=0`.

The `setup-volume.sh` script prepares the `home-desktop` directory with the correct permissions so the container can write configuration files.

**Volume Persistence**: The `docker-compose.yaml` file mounts `./home-desktop` to `/home/desktop` in the container, allowing you to:
- Persist your files and configurations across container restarts
- Access your files from the host system
- Keep your desktop customizations

**Automatic Configuration**: On first start, the container automatically initializes the desktop configuration files (Openbox menu, tint2 panel, autostart scripts) if they don't exist in the volume. This ensures the desktop always has a working configuration.

**Podman Support**: The container is compatible with both Docker and Podman. When using Podman:

- The `userns_mode: keep-id` option maps the container user to your host UID/GID
- You must set `PODMAN_COMPOSE_IN_POD=0` to avoid conflicts between `--userns` and `--pod` flags
- The `supervisord.conf` has `user=desktop` commented out for compatibility with non-root execution
- The initialization script automatically detects when running with podman and uses permissive permissions

**File Ownership Management**: The container automatically manages file ownership to match your host user. On startup, the initialization script:
- Detects the target UID/GID from environment variables (`HOST_UID` and `HOST_GID`) or automatically from the mounted volume ownership
- Modifies the `desktop` user in the container to match the target UID/GID
- Fixes ownership of all existing files in the volume to match the host user

This ensures that files created in the container have the same ownership as your host user, making it easy to access and modify files from both the container and the host system.

To manually specify the UID/GID, set environment variables before starting:

```bash
export HOST_UID=$(id -u)
export HOST_GID=$(id -g)
docker-compose up -d
```

If not specified, the script will automatically detect the UID/GID from the volume ownership.

### Using Docker directly

```bash
docker run -p 8080:8080 -d --name mydesktop -e "TZ=Europe/Rome" novnc-desktop
```

Eventually change your time zone, like "TZ=America/Los_Angeles"

### Access

In browser, open: `http://localhost:8080/`

## Volume Management

The container uses a volume to persist user data. The initialization script (`init-desktop.sh`) automatically:
- Creates necessary configuration directories if they don't exist
- Copies default configuration files (Openbox menu, tint2 panel, autostart)
- Ensures the desktop environment is properly configured

If you need to reset the desktop configuration, you can:
1. Stop the container: `docker-compose down`
2. Remove the volume directory: `rm -rf home-desktop`
3. Recreate it: `./setup-volume.sh`
4. Restart: `docker-compose up -d`

The container will automatically reinitialize all configuration files on the next start.

## File Ownership

The container automatically manages file ownership to ensure files in the `home-desktop` volume match your host user's ownership. This feature:

- **Automatic Detection**: If `HOST_UID` and `HOST_GID` environment variables are not set, the script automatically detects the UID/GID from the mounted volume ownership
- **User Modification**: The `desktop` user in the container is modified to use the target UID/GID, ensuring all files created have the correct ownership
- **Ownership Fix**: On each startup, the script fixes ownership of all existing files in the volume to match the target UID/GID

### Manual Configuration

To explicitly set the UID/GID, export environment variables before starting the container:

```bash
export HOST_UID=$(id -u)
export HOST_GID=$(id -g)
docker-compose up -d
```

Or create a `.env` file in the same directory as `docker-compose.yaml`:

```bash
HOST_UID=1001
HOST_GID=1001
```

Then start with:

```bash
docker-compose --env-file .env up -d
```

### Fixing Existing Files

If you have existing files with incorrect ownership, the container will automatically fix them on startup. However, if you need to fix ownership manually from the host:

```bash
sudo chown -R $(id -u):$(id -g) home-desktop/
```

The container will maintain this ownership on subsequent starts.

## Troubleshooting

### Podman: "--userns and --pod cannot be set together"

This error occurs when running podman-compose with `userns_mode: keep-id`. Solution:

```bash
export PODMAN_COMPOSE_IN_POD=0
podman compose up -d
```

### Podman: "Can't drop privilege as nonroot user"

This supervisord error occurs if `user=desktop` is set in `supervisord.conf` while running as non-root (with `userns_mode: keep-id`). The provided `supervisord.conf` has this line commented out. If you see this error, verify that line 6 in `supervisord.conf` is commented:

```
# user=desktop  # Commented out for userns_mode: keep-id compatibility
```

### Permission denied on volume files

If files in `home-desktop` have incorrect ownership, fix them from the host:

```bash
sudo chown -R $(id -u):$(id -g) home-desktop/
```
