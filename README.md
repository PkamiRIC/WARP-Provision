# WARP Provision

Provisioning repo for WARP devices.

## Quick start (Pi)
```
git clone <REPO_URL>
cd warp-provision
chmod +x bootstrap.sh scripts/*.sh
sudo ./bootstrap.sh --prod --app-ref v1.2.3
```

## What it does
- Installs OS packages, Python venv, vendor drivers/libraries
- Writes `/etc/warp/env`
- Pulls the app repo at the requested ref
- Builds and runs both UIs (Next.js + Vite) by default
- Installs and starts systemd services
- Runs a smoke test

## Required config
1) Environment file:
- If `/etc/warp/env` does not exist, `bootstrap.sh` creates it from `deploy/env.example`.
- Edit it to set `APP_REPO_URL` (and any overrides):
```
sudo nano /etc/warp/env
```

2) Device config:
```
sudo mkdir -p /etc/warp
sudo cp config/device3.yaml.example /etc/warp/device3.yaml
sudo nano /etc/warp/device3.yaml
```

## Modes
- Production:
```
sudo ./bootstrap.sh --prod --app-ref v1.2.3
```
- Development:
```
sudo ./bootstrap.sh --dev --app-ref main
```

Optional VNC install:
```
sudo ./bootstrap.sh --prod --vnc --app-ref v1.2.3
```

Skip UI setup:
```
sudo ./bootstrap.sh --prod --no-ui --app-ref v1.2.3
```

## Logs
Bootstrap logs to `/var/log/warp/bootstrap.log`.
