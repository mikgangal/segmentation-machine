# 3D Slicer + nnInteractive Docker Image for RunPod

This folder contains everything needed to build a Docker image for running 3D Slicer with the nnInteractive AI segmentation extension on RunPod (or any GPU machine).

## What's Included in the Image

- **3D Slicer 5.10.0** - Medical image visualization platform
- **nnInteractive Extension** - AI-assisted segmentation tool
- **PyTorch Nightly (CUDA 12.8)** - Supports Blackwell, Ada, Ampere GPUs
- **TurboVNC + VirtualGL** - Optimized remote 3D visualization
- **noVNC** - Browser-based VNC fallback (same desktop session)
- **Pre-downloaded Model Weights** - Works immediately, no downloads on startup
- **Claude Code CLI** - AI coding assistant from Anthropic
- **File Transfer + DICOM Watcher** - Auto-starts on VNC connect, web uploads + auto-load into Slicer
- **Firefox** - Default web browser (pre-configured, no setup prompts)
- **GitHub CLI + lazygit** - Git workflow with visual terminal UI
- **nvtop** - GPU monitoring tool
- **Fiji (ImageJ)** - Scientific image analysis platform
- **Blender 5.0.1** - 3D modeling, animation, and rendering
- **3D Model Export** - One-click export of all segments as STL/OBJ for 3D printing
- **DICOM Utilities** - watchdog for folder monitoring

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
├── start.sh
├── github-launcher
├── firefox-policies.json
├── DicomWatcher/               # DICOM watcher + file transfer
│   ├── start-file-watcher.sh   # Hybrid: file browser + DICOM auto-loader + nnInteractive
│   ├── file-watcher.desktop    # XFCE autostart entry
│   └── filebrowser.desktop     # Tools folder shortcut
├── slicer.desktop              # Tools folder
├── nninteractive.desktop       # Tools folder - manual restart for server
├── export-segments.py          # Slicer script for STL/OBJ export (loaded via .slicerrc.py)
├── export-stl.sh               # Export trigger script (installed to /usr/local/bin)
├── export-stl.desktop          # Desktop shortcut ("Create 3D Models")
├── print-3d-models.sh          # Slicer launcher with on-demand download
├── print-3d-models.desktop     # Desktop shortcut ("Print 3D Models")
├── firefox.desktop             # Tools folder
├── github.desktop              # Tools folder
├── fiji.desktop                # Tools folder
├── blender.desktop             # Tools folder
├── nvtop.desktop               # Tools folder
├── claude.desktop              # Tools folder
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
- **Auto-starts** with the DICOM watcher when you connect to VNC
- Manual restart: Use the `nnInteractive Server` desktop icon if needed

### DICOM Watcher + AI Segmentation (Auto-starts on VNC connect)

This hybrid service **automatically launches when you connect to VNC** - no manual startup required.

- **File Transfer Port:** 8080
- **nnInteractive Port:** 8000
- **Username:** `admin`
- **Password:** `runpod`
- **Root:** `/` (full filesystem access)
- **Access:** `https://{pod_id}-8080.proxy.runpod.net/files/FILE%20TRANSFERS/`

**What happens when you connect to VNC:**
1. XFCE desktop starts
2. Terminal window opens automatically with the service log
3. nnInteractive server starts on port 8000 (ready for AI segmentation)
4. File browser starts on port 8080
5. Folder watcher monitors `/FILE TRANSFERS` for new DICOM uploads
6. Any uploaded DICOM folder auto-loads ALL series into 3D Slicer
7. User selects which volume to segment in nnInteractive module

**Closing the terminal stops all services** (file browser, nnInteractive, watcher). To restart manually, double-click "File Transfer + DICOM Watcher" in the Tools folder.

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

### DICOM Auto-Loader (Integrated)

The DICOM auto-loader is **integrated into the File Transfer service** and starts automatically when you connect to VNC.

#### Workflow:
1. Connect to VNC - file watcher starts automatically
2. Upload a DICOM folder via the web interface (port 8080)
3. Watcher waits for upload to complete (detects when files stop arriving)
4. Launches 3D Slicer with GPU acceleration
5. Imports folder into Slicer's DICOM database
6. Loads ALL series into Slicer
7. Switches to nnInteractive module - user selects which volume to segment

**Supported DICOM formats:**
- `.dcm`, `.DCM`, `.dicom` extensions
- Extensionless DICOM files (common in medical imaging)
- Any modality: MRI, CT, ultrasound, PET, etc.

**Dependencies:**
- `watchdog` - Folder monitoring

The actual DICOM parsing and loading is handled by 3D Slicer's robust DICOM module.

### Create 3D Models (Desktop Shortcut)

Click the "Create 3D Models" icon on the desktop to export all segments from running Slicer instances as STL files.

**How it works:**
1. Click "Create 3D Models" on desktop
2. All running Slicer instances check for the export trigger
3. Each Slicer exports its segments to `/FILE TRANSFERS/Export_{timestamp}/`
4. Skips internal nnInteractive segments (`<bg>`, `<fg>`)
5. Creates a summary file with export details

**Output:**
```
/FILE TRANSFERS/
└── Export_20260109_143052/
    ├── Liver.stl
    ├── Kidney_Left.stl
    ├── Kidney_Right.stl
    ├── combined_all_segments.obj   ← All segments in one file
    └── EXPORT_SUMMARY.txt
```

- **Individual STL files** - One per segment, for separate printing/editing
- **Combined OBJ file** - All segments together, preserving spatial relationships

**Notes:**
- Slicer must be running for export to work
- Each Slicer instance exports independently
- STL files are named after the segment names
- Download via File Browser (port 8080)

### Print 3D Models (Desktop Shortcut)

Click the "Print 3D Models" icon to launch slicer software and prepare your exported models for 3D printing.

**Supported Slicers (downloaded on-demand):**

| Slicer | Cloud Printers | Other Compatible Printers |
|--------|----------------|---------------------------|
| OrcaSlicer | Bambu Lab (X1, P1, A1) | Prusa, Voron, Creality, Anycubic, Artillery |
| PrusaSlicer | Prusa (MK3, MK4, Mini, XL) | Generic FDM printers |
| Cura | UltiMaker | Creality, Anker, Elegoo, many others |
| Luban | Snapmaker (all models) | - |

**How it works:**
1. Click "Print 3D Models" on desktop
2. Select your slicer software (matched to your printer brand)
3. If not cached, the latest version downloads automatically (~150-300 MB)
4. Select which export to load (if multiple exist)
5. Review the "Next Steps" instructions
6. Press Enter to launch the slicer with your model loaded

**Slicer cache location:** `/workspace/.slicers/` (persists across pod restarts)

**Sending to your printer:**
- **Cloud printing:** Log in to your printer's cloud service within the slicer, then send directly
- **Manual transfer:** Export G-code to `/FILE TRANSFERS/`, download via browser (port 8080), copy to USB/SD

## Using the Environment

1. **Connect via VNC** to port 5901
   - nnInteractive server auto-starts on port 8000
   - File browser auto-starts on port 8080
2. **Click "3D Slicer"** desktop icon to launch Slicer
   - Slicer opens directly to the nnInteractive module
   - Server URL is pre-configured to `http://0.0.0.0:8000`
3. Load your medical images and start segmenting!

**Note:** If you need to restart the nnInteractive server, use the "nnInteractive Server" desktop icon.

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
3D Slicer, Blender, and Fiji all use VirtualGL with NVIDIA EGL for GPU-accelerated OpenGL rendering. Each has a wrapper script that sets the required environment variables:

| Application | Wrapper Script |
|-------------|----------------|
| 3D Slicer | `/usr/local/bin/Slicer` |
| Blender | `/usr/local/bin/Blender` |
| Fiji (ImageJ) | `/usr/local/bin/Fiji` |

The wrapper scripts configure:
- `__EGL_VENDOR_LIBRARY_FILENAMES` - Points to NVIDIA EGL
- `__GLX_VENDOR_LIBRARY_NAME` - Forces NVIDIA GLX
- `VGL_DISPLAY` - Uses EGL display

To verify GPU usage, run `nvtop` while any of these apps is running - you should see GPU activity.

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
| Node.js | 22.x (via NodeSource) |
| Claude Code | Latest (@anthropic-ai/claude-code) |
| Firefox | Latest (direct from Mozilla, pre-configured) |
| Fiji (ImageJ) | Latest (with bundled JDK) |
| Blender | 5.0.1 |

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

## Building on Windows (Known Issues)

When building this Docker image on Windows (Docker Desktop), several issues can occur due to differences in how Windows handles files and network operations:

### Common Problems

| Issue | Symptom | Cause |
|-------|---------|-------|
| **CRLF line endings** | Scripts fail with `\r` errors | Windows Git converts LF to CRLF |
| **Binary corruption** | `Trace/breakpoint trap` errors | Downloads corrupted during build |
| **Curl pipe failures** | `curl \| bash` installs fail | Windows networking quirks |

### How We Mitigate These

1. **`.gitattributes`** - Forces LF line endings for all scripts
2. **Retry logic** - All binary downloads retry 3 times with cleanup
3. **Direct downloads** - Avoid `curl \| bash` patterns (unreliable on Windows)
4. **Final verification** - Build verifies all binaries work before completing
5. **CRLF cleanup** - `sed` removes any remaining Windows line endings
6. **Runtime self-healing** - `start-file-watcher` and `github-launcher` detect corrupted binaries and auto-download fresh copies

### If Binaries Are Corrupted at Runtime

If you see `Trace/breakpoint trap (core dumped)` errors when running tools, the binary was corrupted during build.

**File Browser:** Has automatic self-healing. The hybrid `start-file-watcher` script detects corrupted binaries and downloads fresh copies automatically.

**lazygit:** Has automatic self-healing. Just click the GitHub desktop shortcut (runs `github-launcher`) - it detects the corrupted binary and downloads a fresh copy automatically before proceeding.

### Recommended: Build on Linux

For the most reliable builds, use a Linux machine or CI/CD pipeline (GitHub Actions, etc.) instead of Docker Desktop on Windows.

## Sources & Credits

- [SlicerNNInteractive](https://github.com/coendevente/SlicerNNInteractive) - Extension by Coen de Vente
- [3D Slicer](https://www.slicer.org/) - Medical imaging platform
- [nnInteractive](https://github.com/MIC-DKFZ/nnInteractive) - AI segmentation framework
- [TurboVNC](https://turbovnc.org/) - High-performance VNC for 3D visualization
- [VirtualGL](https://virtualgl.org/) - GPU acceleration for remote 3D apps
- [File Browser](https://filebrowser.org/) - Web-based file manager
- [Claude Code](https://github.com/anthropics/claude-code) - AI coding assistant by Anthropic
- [Fiji (ImageJ)](https://fiji.sc/) - Scientific image analysis platform
- [Blender](https://www.blender.org/) - 3D creation suite
- [watchdog](https://python-watchdog.readthedocs.io/) - File system events monitoring

## Version History

- **v18** - January 2026
  - **Simplified DICOM loading** - removed T2-specific detection, now loads ALL series
    - Works with any modality: MRI (any sequence), CT, ultrasound, PET, etc.
    - User selects which volume to segment in nnInteractive module
    - Leverages 3D Slicer's robust DICOM module instead of custom parsing
  - **Improved DICOM file detection** - finds `.dcm`, `.DCM`, `.dicom`, and extensionless files
  - **Removed pydicom dependency** - no longer needed for metadata parsing
  - **Desktop cleanup** - moved all shortcuts to Tools folder (cleaner desktop)
  - **STL/OBJ Export feature** - new desktop shortcut to export all segments
    - Click "Export STL" to export from any running Slicer instance
    - Creates timestamped folder in `/FILE TRANSFERS/`
    - Exports individual STL files per segment
    - Exports combined OBJ file with all segments (preserves spatial relationships)
    - Automatically skips nnInteractive internal segments (`<bg>`, `<fg>`)
    - Includes summary file with export details
  - **Data Probe auto-collapse** - the lower-left Data Probe widget now auto-collapses on Slicer startup for a cleaner interface

- **v17** - January 2026
  - **Split terminal logging** - Verbose service logs now in separate minimized terminal
    - Service Logs terminal (minimized): filebrowser + nnInteractive output
    - User UI terminal (visible): Clean status display with connection info
  - **Improved user interface**
    - Box-styled connection info banner
    - Spinner animation during file upload progress
    - Tree-formatted status output (`┌─`, `│`, `└─`)
  - **3D Slicer improvements**
    - Launches maximized automatically
    - Opens to nnInteractive module after DICOM loading (instead of Data module)
    - Output redirected to /dev/null to keep user terminal clean
  - **Auto-minimize** - User terminal minimizes when Slicer launches
  - **Bug fix** - Fixed `$TRANSFER_DIR` variable not expanding in Python heredoc
    - Changed quoted heredoc to use hardcoded path `/FILE TRANSFERS`

- **v16** - January 2026
  - **Reorganized DicomWatcher subfolder** - Watcher-related files now in `DicomWatcher/` directory
  - **nnInteractive auto-start** - Server now launches automatically with the DICOM watcher on port 8000
    - No need to manually start before using 3D Slicer
    - Manual restart still available via desktop icon if needed
  - **Fixed race condition** - Multiple Slicer instances no longer launch for single upload
    - Added folder to processed set immediately before waiting for upload completion
  - **Windows Docker build improvements**
    - Quoted heredoc delimiter to prevent CRLF parsing issues
    - Added `*.json` to `.gitattributes` for LF line endings
    - Updated deprecated `xfce4-terminal -e` to `-x` flags
  - **Cleanup** - Removed legacy files `start-filebrowser` and `watch_for_t2.sh`

- **v15** - January 2026
  - **Hybrid File Transfer + DICOM Watcher** - Combined file browser and DICOM auto-loader into single service
    - Auto-starts when VNC connects (not at container boot)
    - Opens terminal window with log showing URL, credentials, and watcher status
    - Closing terminal stops both file browser and DICOM watcher
    - Manual restart available from Tools folder
  - **Smart upload detection** - Waits for upload to complete before scanning
    - Monitors file count and total size every second
    - Only scans when no changes detected for 5 seconds
    - Handles slow uploads where files arrive one-by-one
  - **XFCE autostart integration** - Uses `~/.config/autostart/` for VNC session startup
  - **Removed separate scripts** - `start-filebrowser` and `watch_for_t2.sh` replaced by `start-file-watcher`
  - **Updated desktop shortcut** - "File Transfer + DICOM Watcher" now launches hybrid script

- **v14** - January 2026
  - **Added T2 DICOM Folder Watcher** (`watch_for_t2.sh`) for streamlined MRI workflow
    - Monitors folder for new DICOM studies
    - Auto-detects and loads T2 sequences into 3D Slicer
  - **New Python dependencies** added to Docker image:
    - `pydicom` - Read DICOM metadata (SeriesDescription, ProtocolName) without loading pixel data
    - `watchdog` - File system event monitoring for folder watcher functionality
  - Script automatically:
    - Recursively scans for `.dcm` files
    - Identifies T2 sequences by matching "T2", "T2W", "T2_", "_T2" patterns
    - Launches 3D Slicer with GPU acceleration (VirtualGL)
    - Loads identified series using Slicer's DICOM utilities
  - Works with any vendor's DICOM files (Siemens, GE, Philips, etc.)

- **v13** - January 2026
  - **Major Windows build reliability improvements**
    - Added retry logic (3 attempts) to ALL binary downloads: VirtualGL, TurboVNC, Fiji, Blender, 3D Slicer
    - Replaced File Browser's unreliable `curl | bash` install with direct GitHub download
    - Added final verification stage that tests all binaries before build completes
    - Fixed sed CRLF cleanup running BEFORE start.sh was copied (critical bug)
  - **Fixed Firefox as default browser** - Was documented but not actually implemented
    - Added `MimeType` entries to firefox.desktop for URL handling
    - Created `/root/.config/mimeapps.list` with Firefox as default for http/https
    - Added `BROWSER` environment variable for CLI tools
    - Firefox now works with `xdg-open`, `gh auth login --web`, Claude Code auth
  - **Added comprehensive Windows build documentation** in README

- **v12** - January 2026
  - **Replaced Chrome with Firefox** - Chrome had persistent issues with sandbox flags and default browser detection in Docker
    - Firefox installed directly from Mozilla (Ubuntu 24.04 only has snap version which doesn't work in Docker)
    - Added `firefox-policies.json` to skip all first-run setup screens (welcome page, telemetry, etc.)
    - Firefox automatically set as system default browser via xdg-settings
  - **Fixed Node.js for Claude Code** - Ubuntu's default Node.js 18.19.1 had ES module issues
    - Now installs Node.js 22.x via NodeSource for proper ES module support
    - Fixes `SyntaxError: Cannot use import statement outside a module` error
  - **Fixed lazygit and filebrowser crashes** - Binaries were corrupted during Windows Docker build
    - Both now download fresh from official sources during build
  - **Added installation verification with retry logic** - Automatically retries up to 3 times if install fails
    - File Browser: 3 retries + fallback to direct GitHub download
    - lazygit: 3 retries with cleanup between attempts
    - Firefox: 3 retries with cleanup between attempts
    - All tools verify with version check after install
  - **Desktop reorganization** for cleaner workflow:
    - Hidden default icons: home, filesystem, trash, removable devices
    - Created "Tools" folder on desktop containing:
      - Firefox, GitHub, Fiji, Blender, FileTransfer, nvtop, Claude Code
    - Main desktop now shows only: 3D Slicer, nnInteractive, Tools folder
  - **Added nvtop desktop shortcut** - GPU monitoring accessible from Tools folder
  - **Added Claude Code desktop shortcut** - Launch AI coding assistant from Tools folder
  - **Improved File Transfer workflow**:
    - Auto-creates `/FILE TRANSFERS` folder on first run
    - Opens Thunar file manager in transfer folder
    - Positions windows on right half of screen (Thunar top, terminal bottom)
    - Browser URL points directly to FILE TRANSFERS folder

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
  - **Added GPU acceleration for Blender and Fiji** via VirtualGL wrapper scripts
  - All 3D applications (Slicer, Blender, Fiji) now use consistent VirtualGL configuration
  - Wrapper scripts at `/usr/local/bin/{Slicer,Blender,Fiji}` with EGL mode

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
  - Added Fiji (ImageJ) - Scientific image analysis platform with bundled JDK
  - Added Blender 5.0.1 - 3D modeling, animation, and rendering
  - Desktop shortcuts for both applications

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

## License

This component is part of the Segmentation Machine project, licensed under [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/).

See the root [LICENSE](../LICENSE) file for full terms.

---

## Instructions for Claude Code

When adding new scripts, files, or functionality to this project:

1. **Add copyright headers** to all new source files:
   - Shell scripts: `# Copyright (c) 2025-2026 Mik Gangal` + `# Licensed under CC BY-NC-SA 4.0 - https://creativecommons.org/licenses/by-nc-sa/4.0/`
   - Python: Same format with `#` comments
   - Go: Same format with `//` comments

2. **Maintain non-commercial licensing** - This project uses CC BY-NC-SA 4.0 due to upstream nnInteractive model weight restrictions

3. **Update LICENSE file** if adding new third-party components - list them in the NOTICES section

4. **Attribution required** for any derivative work or research use
