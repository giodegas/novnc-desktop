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

### Using Docker Compose (Recommended for Docker)

```bash
# Prepare the volume directory with correct permissions
./setup-volume.sh

# Build and start the container using docker-compose.yaml
# The container will automatically use your host UID/GID
docker compose -f docker-compose.yaml up -d
```

**Note:** The `docker-compose.yaml` file automatically passes your host UID/GID to the container via environment variables. The `docker-entrypoint.sh` script reconfigures the `desktop` user to match your host user, ensuring correct file permissions in the volume.

### Using Podman Compose (Recommended for Podman)

Podman uses `docker-compose-podman.yaml` which includes `userns_mode: keep-id` to map your host UID/GID directly:

```bash
# Prepare the volume directory with correct permissions
./setup-volume.sh

# Build and start the container using docker-compose-podman.yaml
# Podman requires disabling pod mode due to userns_mode: keep-id
PODMAN_COMPOSE_IN_POD=0 podman compose -f docker-compose-podman.yaml up -d
```

**Note:** With Podman, `userns_mode: keep-id` automatically maps your host UID/GID, so no user reconfiguration is needed. The container runs with your host user identity directly.

### Using Docker directly

```bash
docker run -p 8080:8080 -d --name mydesktop -e "TZ=Europe/Rome" novnc-desktop
```

Eventually change your time zone, like "TZ=America/Los_Angeles"

### Access

In browser, open: `http://localhost:8080/`

## Volume Persistence

Both `docker-compose.yaml` (Docker) and `docker-compose-podman.yaml` (Podman) mount `./home-desktop` to `/home/desktop`, allowing you to:

- Persist files and configurations across container restarts
- Access your files from the host system
- Keep your desktop customizations

On first start, the container automatically initializes desktop configuration files (Openbox menu, tint2 panel, autostart) if they don't exist.

**Reset configuration**: Stop the container, remove `home-desktop/`, run `./setup-volume.sh`, and restart.

## File Permissions

Both Docker and Podman configurations use your host UID/GID, ensuring correct file permissions:

- **Docker** (`docker-compose.yaml`): Uses `docker-entrypoint.sh` to reconfigure the `desktop` user with your host UID/GID at container startup. The script reads `HOST_UID` and `HOST_GID` from environment variables (automatically set from your shell's `UID` and `GID`).

- **Podman** (`docker-compose-podman.yaml`): Uses `userns_mode: keep-id` to run with your host UID/GID directly. No user reconfiguration is needed as Podman handles the mapping automatically.

Files created in the volume will have the correct ownership automatically in both cases, matching your host user.

If you need to manually fix ownership from the host:

```bash
sudo chown -R $(id -u):$(id -g) home-desktop/
```

## Troubleshooting

### Podman: "--userns and --pod cannot be set together"

```bash
export PODMAN_COMPOSE_IN_POD=0
podman compose up -d
```

### Podman: "Can't drop privilege as nonroot user"

Verify that `user=desktop` is commented out in `supervisord.conf` (line 6):

```
# user=desktop  # Commented out for userns_mode: keep-id compatibility
```

### Permission denied on volume files

Fix ownership from the host:

```bash
sudo chown -R $(id -u):$(id -g) home-desktop/
```

### Podman: Container stops after logout (RHEL/AlmaLinux/Fedora)

On systems with systemd (RHEL 9, AlmaLinux 9, Fedora, etc.), Podman rootless containers are tied to the user session. When you logout or close your SSH session, systemd terminates all user processes, including your containers.

**Symptoms:**
- Container exits with `SIGTERM` after some time
- Container stops when you close the terminal or SSH session
- Container status shows "Exited" after logout

**Solution:** Enable "linger" for your user to allow processes to persist after logout:

```bash
# Check current linger status
loginctl show-user $USER | grep Linger

# Enable linger (requires sudo)
sudo loginctl enable-linger $USER
```

After enabling linger:
- The user's systemd manager starts at boot (before login)
- Containers continue running after logout
- Containers persist until explicitly stopped

**Verify linger is enabled:**

```bash
ls /var/lib/systemd/linger/
```

Your username should appear in the list.
