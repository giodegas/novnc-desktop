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

```bash
# Prepare the volume directory with correct permissions
./setup-volume.sh

# Build and start the container
docker-compose up -d
```

### Using Podman Compose

Podman requires disabling pod mode due to `userns_mode: keep-id`:

```bash
PODMAN_COMPOSE_IN_POD=0 podman compose up -d
```

### Using Docker directly

```bash
docker run -p 8080:8080 -d --name mydesktop -e "TZ=Europe/Rome" novnc-desktop
```

Eventually change your time zone, like "TZ=America/Los_Angeles"

### Access

In browser, open: `http://localhost:8080/`

## Volume Persistence

The `docker-compose.yaml` mounts `./home-desktop` to `/home/desktop`, allowing you to:

- Persist files and configurations across container restarts
- Access your files from the host system
- Keep your desktop customizations

On first start, the container automatically initializes desktop configuration files (Openbox menu, tint2 panel, autostart) if they don't exist.

**Reset configuration**: Stop the container, remove `home-desktop/`, run `./setup-volume.sh`, and restart.

## File Permissions

When using Podman with `userns_mode: keep-id`, the container runs with your host UID/GID, so files created in the volume will have the correct ownership automatically.

When using Docker, files in the volume may be owned by the container's `desktop` user (UID 1000). To fix ownership from the host:

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
