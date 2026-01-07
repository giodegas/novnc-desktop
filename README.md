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
git clone https://github.com/prbinu/novnc-desktop.git
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
# or with podman-compose:
podman-compose up -d
```

The `setup-volume.sh` script prepares the `home-desktop` directory with the correct permissions so the container can write configuration files.

**Volume Persistence**: The `docker-compose.yaml` file mounts `./home-desktop` to `/home/desktop` in the container, allowing you to:
- Persist your files and configurations across container restarts
- Access your files from the host system
- Keep your desktop customizations

**Automatic Configuration**: On first start, the container automatically initializes the desktop configuration files (Openbox menu, tint2 panel, autostart scripts) if they don't exist in the volume. This ensures the desktop always has a working configuration.

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
