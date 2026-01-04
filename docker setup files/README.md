# 3D Slicer + nnInteractive Docker Image for RunPod (Lite)

> **Note:** This is the **lite version** without Blender and Fiji. For the full version, see the `main` branch.

This folder contains everything needed to build a Docker image for running 3D Slicer with the nnInteractive AI segmentation extension on RunPod (or any GPU machine).

## What's Included in the Image

- **3D Slicer 5.10.0** - Medical image visualization platform
- **nnInteractive Extension** - AI-assisted segmentation tool
- **PyTorch Nightly (CUDA 12.8)** - Supports Blackwell, Ada, Ampere GPUs
- **TurboVNC + VirtualGL** - Optimized remote 3D visualization
- **noVNC** - Browser-based VNC fallback (same desktop session)
- **Pre-downloaded Model Weights** - Works immediately, no downloads on startup
- **Claude Code CLI** - AI coding assistant from Anthropic
- **File Transfer** - Web-based file manager for uploads/downloads
- **Google Chrome** - Default web browser
- **GitHub CLI + lazygit** - Git workflow with visual terminal UI

## Prerequisites

### 1. Install Docker Desktop

- **Windows:** https://docs.docker.com/desktop/install/windows-install/
- **Mac:** https://docs.docker.com/desktop/install/mac-install/

### 2. Create Docker Hub Account

Go to https://hub.docker.com/signup and create a free account.
Remember your username!

## Build Instructions

### Step 1: Download This Folder

Download all files in this folder to your laptop. You should have:
```
docker-build/
├── Dockerfile
├── xstartup
├── slicer.desktop
├── nninteractive.desktop
├── filebrowser.desktop
├── chrome.desktop
├── github.desktop
├── github-launcher
├── start-filebrowser
├── start.sh
├── .gitattributes
└── README.md (this file)
```

### Step 2: Open Terminal

- **Windows:** Right-click in the folder → "Open in Terminal"
- **Mac:** Right-click → "New Terminal at Folder"

### Step 3: Log In to Docker Hub

```bash
docker login
```
Enter your Docker Hub username and password when prompted.

### Step 4: Build the Image

Replace `YOUR_USERNAME` with your Docker Hub username:

```bash
docker build -t YOUR_USERNAME/slicer-nninteractive:v1 .
```

**Note:** This takes 15-30 minutes and downloads ~8GB of packages.

### Step 5: Push to Docker Hub

```bash
docker push YOUR_USERNAME/slicer-nninteractive:v1
```

## RunPod Setup

### Create a Template

1. Go to RunPod → **Templates** → **New Template**

2. Fill in these settings:

| Setting | Value |
|---------|-------|
| Template Name | `3D Slicer + nnInteractive` |
| Container Image | `YOUR_USERNAME/slicer-nninteractive:v1` |
| Container Disk | `20 GB` |
| Volume Disk | Your data volume size |
| Volume Mount Path | `/workspace` |
| Expose HTTP Ports | `5901, 6080, 8000, 8080` |
| Expose TCP Ports | `22` |

3. Save the template

### Start a Pod

1. Create a new pod using your template
2. Wait for it to start (should be fast since image is pre-built)
3. Connect via VNC on port 5901

## Connecting

### TurboVNC (recommended for best performance)
- **Port:** 5901 (internal) → Check RunPod for exposed TCP port
- **Password:** `vncpass`
- **Client:** Download TurboVNC from https://turbovnc.org/
- **Connection:** Use RunPod's direct TCP port (e.g., `{pod_ip}:{tcp_port}`)

TurboVNC is optimized for VirtualGL and provides the best performance for 3D applications like 3D Slicer.

### noVNC (browser-based fallback)
- **Port:** 6080
- **URL:** `https://{pod_id}-6080.proxy.runpod.net/` (auto-redirects and logs in)
- **Password:** `vncpass` (auto-filled)
- No client install needed - works in any modern browser
- Just click the RunPod HTTP 6080 shortcut for instant desktop access
- Same desktop session as TurboVNC - you can use both simultaneously

### SSH Access
- **Port:** 22
- **Username:** root
- **Password:** `runpod`

### nnInteractive API
- **Port:** 8000
- Start from desktop icon or run: `nninteractive-slicer-server --host 0.0.0.0 --port 8000`

### File Transfer (Web-based file manager)
- **Port:** 8080
- **Username:** `admin`
- **Password:** `runpod`
- **Root:** `/` (full filesystem access)
- Start from desktop icon "File Transfer" or run: `start-filebrowser`
- Access via: `https://{pod_id}-8080.proxy.runpod.net`

### Claude Code CLI
- Run from terminal: `claude`
- Requires `ANTHROPIC_API_KEY` environment variable

### GitHub (Desktop Shortcut)
The "GitHub" desktop shortcut provides a streamlined Git workflow:

**First Run:**
1. Click the "GitHub" desktop icon
2. Authenticate via browser (GitHub CLI)
3. Select a repository from your list to clone
4. Opens automatically in lazygit

**Subsequent Runs:**
1. Click "GitHub" icon
2. See all your repos with `[CLONED]` tags for local repos
3. Select any repo:
   - **Cloned repos**: Opens directly in lazygit
   - **Uncloned repos**: Clones to `/GITHUB` then opens lazygit

**Repository Location:** All repos are cloned to `/GITHUB`

**Lazygit Quick Keys:**
| Key | Action |
|-----|--------|
| `space` | Stage/unstage file |
| `c` | Commit |
| `p` | Pull |
| `P` | Push |
| `?` | Show all keybindings |
| `q` | Quit |

## Using the Environment

1. **Connect via VNC** to port 5901
2. **Click "nnInteractive Server"** desktop icon to start the AI backend
3. **Click "3D Slicer"** desktop icon to launch Slicer
   - Slicer opens directly to the nnInteractive module
   - Server URL is pre-configured to `http://0.0.0.0:8000`
4. Load your medical images and start segmenting!

## Your Data

- Mount your network volume at `/workspace`
- Your medical images and projects will be accessible there
- The Docker image contains tools only, not your data

## Troubleshooting

### Build fails at PyTorch installation
PyTorch nightly builds update daily. If it fails:
1. Wait a few hours and try again
2. Or check https://download.pytorch.org/whl/nightly/cu128 for available versions

### Slicer won't start
Run this inside the container to check for missing libraries:
```bash
ldd /opt/slicer/bin/Slicer.bin | grep "not found"
```

### nnInteractive extension not showing
The module is installed directly into Slicer at `/opt/slicer/lib/Slicer-5.10/qt-scripted-modules/SlicerNNInteractive.py`. If it's not showing:
1. Verify the file exists: `ls /opt/slicer/lib/Slicer-5.10/qt-scripted-modules/SlicerNNInteractive.py`
2. Check Slicer's error log in `/tmp/Slicer-/` for Python errors
3. Restart Slicer

### GPU not detected
1. Ensure pod has a GPU assigned
2. Run `nvidia-smi` to verify GPU is visible
3. Run `python -c "import torch; print(torch.cuda.is_available())"` to test PyTorch

### PyTorch CUDA capability warning (sm_XX not compatible)
If you see a warning like `GPU with CUDA capability sm_120 is not compatible with the current PyTorch installation`, the installed PyTorch doesn't support your GPU architecture. To fix:
```bash
uv pip install \
    --python /opt/uv-tools/nninteractive-slicer-server/bin/python \
    --upgrade --pre \
    torch torchvision \
    --index-url https://download.pytorch.org/whl/nightly/cu128
```
Then verify with:
```bash
/opt/uv-tools/nninteractive-slicer-server/bin/python -c "import torch; print(torch.cuda.get_arch_list())"
```
The output should include your GPU's architecture (e.g., `sm_120` for Blackwell).

### GPU-accelerated applications not using GPU
3D Slicer uses VirtualGL with NVIDIA EGL for GPU-accelerated OpenGL rendering via the wrapper script at `/usr/local/bin/Slicer`.

The wrapper script configures:
- `__EGL_VENDOR_LIBRARY_FILENAMES` - Points to NVIDIA EGL
- `__GLX_VENDOR_LIBRARY_NAME` - Forces NVIDIA GLX
- `VGL_DISPLAY` - Uses EGL display

To verify GPU usage, run `nvtop` while Slicer is running - you should see GPU activity.

## Customization

### Change VNC Password
Edit the Dockerfile, find this line:
```dockerfile
echo "vncpass" | vncpasswd -f > /root/.vnc/passwd
```
Replace `vncpass` with your preferred password.

### Change SSH Password
Edit `start.sh`, find this line:
```bash
echo "root:runpod" | chpasswd
```
Replace `runpod` with your preferred password.

### Change VNC Resolution
Set the `VNC_RESOLUTION` environment variable when starting the container:
```
VNC_RESOLUTION=2560x1440
```

## Technical Details

| Component | Version/Details |
|-----------|-----------------|
| Base Image | `nvidia/cuda:12.8.0-runtime-ubuntu24.04` |
| Python | 3.12 |
| PyTorch | Nightly (CUDA 12.8) |
| 3D Slicer | 5.10.0 (latest stable) |
| VNC Server | TurboVNC 3.1.4 + noVNC (browser) |
| Desktop | XFCE4 |
| GPU Acceleration | VirtualGL 3.1.4 (EGL mode) |
| File Transfer | Latest (filebrowser.org) |
| Claude Code | Latest (@anthropic-ai/claude-code) |
| Google Chrome | Latest stable (default browser) |

## GPU Compatibility

The PyTorch nightly build supports these GPU architectures:
- **sm_86** - RTX 3080 Ti, RTX 3090 (Ampere)
- **sm_89** - RTX 4090, RTX 6000 Ada (Ada Lovelace)
- **sm_100** - Future GPUs
- **sm_120** - RTX PRO 6000 Blackwell

## Remote Desktop Technology Choices

When running on RunPod, there are constraints on how remote desktop access works. We evaluated several options:

### Options Evaluated

| Technology | GPU Encoding | Protocol | Verdict |
|------------|--------------|----------|---------|
| **TigerVNC** | ❌ CPU | TCP | ❌ Basic, no VirtualGL optimization |
| **KasmVNC** | ❌ CPU | TCP | ❌ Good browser UX but slow for 3D |
| **Selkies-GStreamer** | ✅ NVENC | UDP (WebRTC) | ❌ Requires UDP - incompatible with RunPod |
| **Moonlight/Sunshine** | ✅ NVENC | UDP | ❌ Requires UDP - incompatible with RunPod |
| **TurboVNC + noVNC** | ❌ CPU | TCP | ✅ **Best choice for RunPod** |

### Why TurboVNC?

1. **Designed for VirtualGL** - TurboVNC is specifically optimized for remote 3D visualization workflows
2. **Best native performance** - TurboVNC client provides the lowest latency for 3D applications
3. **Works with RunPod** - Direct TCP connection bypasses HTTP proxy limitations
4. **Browser fallback** - noVNC proxies to TurboVNC for the same desktop session

### RunPod Network Constraints

- **HTTP Proxy** (`proxy.runpod.net`): Only supports HTTP/HTTPS, not raw UDP
- **Direct TCP Ports**: RunPod exposes TCP ports with mapped port numbers
- **No UDP**: RunPod does not support UDP port forwarding

### Why GPU-Accelerated Streaming Doesn't Work

All GPU-accelerated streaming solutions use UDP for low-latency video delivery:

- **Selkies-GStreamer**: Uses WebRTC which requires UDP for peer-to-peer video streaming. While signaling works over TCP, the actual video stream needs UDP ports 47998-48000.

- **Moonlight/Sunshine**: Sunshine server was tested and successfully detected NVENC encoders (H.264, HEVC, AV1). However, Moonlight's game streaming protocol requires UDP ports 47998-48000 for video/audio. TCP-only RTSP (port 48010) is insufficient for the actual stream.

**Bottom line**: Until RunPod adds UDP port forwarding, GPU-accelerated stream encoding (NVENC) is not possible. TurboVNC with CPU-based encoding remains the best available option.

### Recommended Setup

1. **For 3D work**: Use TurboVNC client connected to RunPod's exposed TCP port
2. **For quick checks**: Use noVNC via browser (same desktop session)
3. **Both can be used simultaneously** - they share the same X session

## Sources & Credits

- [SlicerNNInteractive](https://github.com/coendevente/SlicerNNInteractive) - Extension by Coen de Vente
- [3D Slicer](https://www.slicer.org/) - Medical imaging platform
- [nnInteractive](https://github.com/MIC-DKFZ/nnInteractive) - AI segmentation framework
- [TurboVNC](https://turbovnc.org/) - High-performance VNC for 3D visualization
- [VirtualGL](https://virtualgl.org/) - GPU acceleration for remote 3D apps
- [File Browser](https://filebrowser.org/) - Web-based file manager
- [Claude Code](https://github.com/anthropics/claude-code) - AI coding assistant by Anthropic

## Version History

> **Branch: without-blender-and-fiji** - This is a lighter version of the image without Blender and Fiji to reduce image size.

- **v11** - January 2026
  - **Fixed GitHub desktop shortcut** - Changed `xfce4-terminal -e` to `xfce4-terminal -x` with full path
    - The `-e` flag is deprecated in newer xfce4-terminal versions
    - Now uses: `Exec=xfce4-terminal -x /usr/local/bin/github-launcher`
  - **Fixed Chrome default browser for CLI tools** (gh auth, xdg-open)
    - Added xdg-settings/xdg-mime configuration in Dockerfile
    - Created chrome-root.desktop entry for xdg-open compatibility
    - `gh auth login --web` now correctly opens Chrome with `--no-sandbox`
  - **Fixed Windows line ending issues** when building Docker on Windows
    - Added `.gitattributes` to force LF line endings for all scripts (prevents Git CRLF conversion)
    - Added CRLF safeguard in Dockerfile as backup (`sed -i 's/\r$//'` on all scripts)

- **v10** - January 2026
  - **Added GitHub workflow** with desktop shortcut for streamlined Git operations
  - Installed GitHub CLI (`gh`) for authentication and repo management
  - Installed lazygit - visual terminal UI for Git
  - Added `github-launcher` script that handles:
    - Browser-based GitHub authentication on first run
    - Lists all repos with `[CLONED]` indicator for local repos
    - Clones selected repos to `/GITHUB` directory
    - Opens lazygit automatically after selection
  - Fixed Chrome default browser to use `--no-sandbox` for Docker compatibility

- **v9** - January 2026
  - Improved VirtualGL configuration for 3D Slicer
  - Wrapper script at `/usr/local/bin/Slicer` with EGL mode

- **v8** - January 2026
  - **Replaced TigerVNC with TurboVNC** for optimized 3D visualization performance
  - TurboVNC is specifically designed for VirtualGL workflows
  - Comprehensive evaluation of remote desktop alternatives:
    - KasmVNC: Works but CPU-only encoding
    - Selkies-GStreamer: Has NVENC but requires UDP (WebRTC) - incompatible with RunPod
    - Moonlight/Sunshine: Has NVENC but requires UDP - incompatible with RunPod
  - Conclusion: RunPod's TCP-only limitation prevents GPU-accelerated streaming
  - Best setup: TurboVNC for native client + noVNC for browser fallback (same session)
  - Added comprehensive documentation on remote desktop technology choices

- **v7** - January 2026
  - noVNC now auto-redirects and auto-logs in when accessing the root URL
  - No more manual navigation to vnc.html or password entry
  - Just click the RunPod HTTP 6080 shortcut for instant desktop access

- **v6** - January 2026
  - Added noVNC for browser-based VNC access (port 6080)
  - No client installation needed - access desktop from any browser
  - Both native VNC (5901) and noVNC (6080) connect to same session

- **v5** - January 2026
  - **CRITICAL FIX:** Added explicit PyTorch nightly upgrade step for Blackwell GPU (sm_120) support
  - Fixed issue where `uv tool install` resolved to stable PyTorch (cu124, sm_50-sm_90 only)
  - Now explicitly upgrades to PyTorch nightly cu128 which includes sm_100 and sm_120 architectures
  - Verified working on NVIDIA RTX PRO 6000 Blackwell Server Edition

- **v4** - January 2026
  - Internal improvements

- **v3** - January 2026
  - Fixed VNC password creation using `vncpasswd -f` flag for non-interactive stdin input
  - Updated VirtualGL to 3.1.4 with proper installation verification
  - Added tigervnc-tools package for password management
  - Slicer wrapper now gracefully falls back if VirtualGL unavailable

- **v2** - January 2025
  - Added Claude Code CLI (Anthropic's AI coding assistant)
  - Added File Transfer (web-based file manager on port 8080)
  - File Transfer credentials: admin / runpod
  - File Transfer serves root filesystem (/)
  - Added Google Chrome as default browser
  - Improved 3D Slicer GPU acceleration with NVIDIA EGL
  - Slicer auto-opens to nnInteractive module on startup
  - nnInteractive server URL pre-configured (http://0.0.0.0:8000)

- **v1** - Initial release (December 2024)
  - 3D Slicer 5.10.0
  - PyTorch nightly cu128
  - Pre-downloaded model weights
