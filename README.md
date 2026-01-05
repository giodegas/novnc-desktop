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

### Run

```bash
docker run -p 8080:8080 -d --name mydesktop -e "TZ=Europe/Rome" novnc-desktop
```

Eventually change your time zone, like "TZ=America/Los_Angeles"

In browser, open: `http://localhost:8080/
`
