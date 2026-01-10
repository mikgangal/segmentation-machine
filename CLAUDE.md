# Claude Code Quick Reference - Segmentation Machine

This file helps Claude Code sessions (especially those running inside the pod) understand the project context.

## Project Overview

**Segmentation Machine** - Docker image and launcher for GPU-powered 3D Slicer workstations on RunPod.

## Related Repository

**`../web-interface---for-segmentation/`** - The web application that manages sessions
- Users login at https://medical-segmentation.com
- Launches pods using RunPod API
- Tracks usage, handles payments
- **Heartbeat system** auto-terminates pods when users close browser

## Project Structure

```
segmentation-machine/
├── docker setup files/
│   ├── Dockerfile              # Main image definition
│   ├── start.sh                # Container entrypoint
│   ├── xstartup                # VNC desktop startup
│   ├── *.desktop               # Desktop shortcuts
│   └── DicomWatcher/           # DICOM auto-loader scripts
├── runpod-launcher/            # Go CLI for one-click launch
│   └── README.md
├── 3d printing/                # 3D printing integration
└── image files/                # Supporting images
```

## Docker Image Components

| Component | Version | Purpose |
|-----------|---------|---------|
| Base | Ubuntu 24.04 + CUDA 12.8 | Runtime |
| 3D Slicer | 5.10.0 | Medical image viewer |
| nnInteractive | Latest | AI segmentation |
| PyTorch | Nightly cu128 | GPU inference |
| TurboVNC | 3.1.4 | Remote desktop |
| noVNC | Latest | Browser VNC access |
| File Browser | Latest | Web file upload |
| Blender | 5.0.1 | 3D modeling |
| Fiji | Latest | Image analysis |
| Claude Code | Latest | AI coding assistant |

## Desktop Environment

- **XFCE4** with TurboVNC
- Desktop shortcuts in `/root/Desktop/Tools/`
- XFCE autostart: `/root/.config/autostart/`

## Key Files for Pod-Side Development

| File | Purpose |
|------|---------|
| `docker setup files/Dockerfile` | Image definition |
| `docker setup files/start.sh` | Container entrypoint |
| `docker setup files/xstartup` | VNC session startup |
| `docker setup files/DicomWatcher/start-file-watcher.sh` | File watcher + DICOM loader |

## Ports

| Port | Service | Access |
|------|---------|--------|
| 5901 | TurboVNC | Native VNC client |
| 6080 | noVNC | Browser (proxied through web app) |
| 8080 | File Browser | Web file upload |
| 8000 | nnInteractive | AI server |
| 22 | SSH | Terminal |

## Building & Pushing

```bash
cd "docker setup files"

# Build
docker build -t mikgangal/3dslicer-nninteractive:v18 .

# Push
docker push mikgangal/3dslicer-nninteractive:v18

# Update RunPod template with new image tag
```

## Pending Work: In-Pod Notifications

The web app's heartbeat system will terminate stale pods. To warn users first:

1. **Add notification tools** to Dockerfile:
   ```dockerfile
   RUN apt-get update && apt-get install -y --no-install-recommends \
       libnotify-bin zenity \
       && rm -rf /var/lib/apt/lists/*
   ```

2. **Option A: RunPod Exec API** - Web app calls exec to show notification:
   ```bash
   notify-send -u critical "Session Ending" "Save your work! Terminating in 60 seconds."
   # or
   zenity --warning --title="Session Ending" --text="Terminating in 60 seconds"
   ```

3. **Option B: Guardian Agent** - Script in pod polls web app for termination signal:
   - Add to XFCE autostart
   - Polls `/api/session-status` every 30 seconds
   - Shows countdown when termination is pending

## VirtualGL Usage

GPU-accelerated apps use VirtualGL for rendering:

```bash
# Wrapper scripts already handle this
/usr/local/bin/Slicer    # Runs: vglrun -d egl /opt/slicer/Slicer
/usr/local/bin/Blender   # Runs: vglrun -d egl /opt/blender/blender
/usr/local/bin/Fiji      # Runs: vglrun -d egl /opt/fiji/fiji-linux-x64
```

## Sync Between Repositories

When working on features that span both repos:

1. **Web app** (web-interface---for-segmentation) - API endpoints, heartbeat, session management
2. **Pod image** (segmentation-machine) - Desktop notifications, guardian scripts

Use GitHub to sync:
```bash
# From web app session
git push

# From pod session
cd /GITHUB/segmentation-machine
git pull  # or push your changes
```

## Current Docker Image

- Registry: `mikgangal/3dslicer-nninteractive`
- Current version: v16-v18 (check RunPod template)
- Template ID: `3ikte0az1e`
