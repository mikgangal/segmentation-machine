# Segmentation Machine

A cloud-based medical image segmentation workstation that runs 3D Slicer with AI-assisted segmentation on RunPod GPUs. Upload DICOM files, segment with AI, export STL files for 3D printing.

## Project Structure

```
segmentation-machine/
├── docker setup files/     # Docker image for RunPod
├── runpod-launcher/        # One-click launcher (Go CLI)
├── 3d printing/            # 3D printing integration (planned)
└── image files/            # Supporting images
```

## Components

### 1. Docker Image (`docker setup files/`)

A fully-loaded medical imaging environment that runs on RunPod:

| Component | Description |
|-----------|-------------|
| **3D Slicer 5.10.0** | Medical image visualization platform |
| **nnInteractive** | AI-assisted segmentation extension |
| **PyTorch Nightly (CUDA 12.8)** | Supports Blackwell, Ada, Ampere GPUs |
| **TurboVNC + noVNC** | Remote desktop (native client + browser) |
| **File Browser** | Web-based file upload (port 8080) |
| **DICOM Watcher** | Auto-detects and loads uploaded DICOM folders |
| **STL/OBJ Export** | One-click export for 3D printing |
| **OrcaSlicer** | 3D print slicer (Bambu, Prusa, Creality, etc.) |
| **Claude Code CLI** | AI coding assistant |
| **GitHub CLI + lazygit** | Git workflow tools |
| **Fiji (ImageJ)** | Scientific image analysis |
| **Blender 5.0.1** | 3D modeling (GPU-accelerated) |

See [`docker setup files/README.md`](docker%20setup%20files/README.md) for build instructions and full documentation.

### 2. RunPod Launcher (`runpod-launcher/`)

A Go CLI application that launches a pod on RunPod with one click:

- Prompts for RunPod API key (saves for future use)
- Creates pod with pre-configured template and GPU
- Shows live progress with phases and helpful tips
- Auto-opens browser to VNC desktop and file upload
- Displays balance and cost tracking
- **Auto-terminates pod on exit** to prevent forgotten charges

Pre-built executables included:
- `SlicerLauncher-windows.exe`
- `SlicerLauncher-mac-intel`
- `SlicerLauncher-mac-arm64`

See [`runpod-launcher/README.md`](runpod-launcher/README.md) for details.

### 3. 3D Printing Integration (`3d printing/`)

Send exported STL files directly to cloud-connected 3D printers via OrcaSlicer:

- Click "Send to Printer" desktop shortcut
- OrcaSlicer opens with your latest STL export loaded
- Login to your cloud account (Bambu, Prusa, etc.) - one-time setup
- Slice and send to your printer

See [`3d printing/README.md`](3d%20printing/README.md) for details.

## Workflow

```
┌───────────┐   ┌───────────┐   ┌───────────┐   ┌───────────┐   ┌───────────┐
│  Launch   │──▶│  Upload   │──▶│  Segment  │──▶│  Export   │──▶│   Print   │
│  RunPod   │   │  DICOM    │   │  with AI  │   │  STL/OBJ  │   │   (opt)   │
└───────────┘   └───────────┘   └───────────┘   └───────────┘   └───────────┘
      │               │               │               │               │
      ▼               ▼               ▼               ▼               ▼
 One-click       File Browser    nnInteractive   "Export STL"   "Send to
 launcher        drag & drop     in 3D Slicer    desktop icon    Printer"
```

1. **Run the launcher** - Pod spins up with GPU in ~2-3 minutes
2. **Upload DICOM folder** - Via File Browser at port 8080
3. **Auto-load** - DICOM watcher detects files, launches Slicer, loads all series
4. **Segment** - Use nnInteractive for AI-assisted segmentation
5. **Export** - Click "Export STL" to get 3D-printable models
6. **Print** (optional) - Click "Send to Printer" to open in OrcaSlicer
7. **Close launcher** - Pod terminates automatically (no surprise charges)

## Quick Start

### Option A: Use Pre-built Image (Recommended)

1. Download the launcher for your platform from `runpod-launcher/`
2. Run the executable
3. Enter your RunPod API key when prompted
4. Wait for pod to start, browser opens automatically

### Option B: Build Your Own Image

1. Install Docker Desktop
2. Navigate to `docker setup files/`
3. Build: `docker build -t yourusername/slicer-nninteractive:v18 .`
4. Push: `docker push yourusername/slicer-nninteractive:v18`
5. Create a RunPod template with your image
6. Update `templateID` in launcher source and rebuild

## Connection Details

| Service | Port | Access |
|---------|------|--------|
| **TurboVNC** | 5901 | Native VNC client (best performance) |
| **noVNC** | 6080 | Browser-based desktop |
| **File Browser** | 8080 | Web file upload (`admin` / `runpod`) |
| **nnInteractive API** | 8000 | AI segmentation server |
| **SSH** | 22 | Terminal access (`root` / `runpod`) |

## GPU Support

The PyTorch nightly build supports:
- **sm_86** - RTX 3080 Ti, RTX 3090 (Ampere)
- **sm_89** - RTX 4090, RTX 6000 Ada (Ada Lovelace)
- **sm_100** - Future GPUs
- **sm_120** - RTX PRO 6000 Blackwell

## Technical Highlights

- **Self-healing binaries** - Scripts detect corrupted binaries (Windows Docker build issue) and re-download automatically
- **VirtualGL EGL mode** - GPU-accelerated 3D rendering in containers without X11
- **File trigger system** - STL export works across multiple Slicer instances via polling
- **DICOM auto-loader** - Uses watchdog + 3D Slicer's DICOM module for robust import

## Requirements

- **RunPod account** with API key (All permissions, not read-only)
- **RunPod credits** (~$1-2/hour depending on GPU)
- For building: Docker Desktop

## License

This project is licensed under [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/) (Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International).

### What this means

**You CAN:**
- Use this for research, education, and non-commercial clinical work
- Modify and adapt the platform for your needs
- Share and redistribute with proper attribution

**You CANNOT:**
- Use this for commercial purposes or paid services
- Remove attribution or claim this as entirely your own work
- Apply additional restrictions to derivative works

### Third-party components

This platform integrates several open-source tools, each under their own licenses:

| Component | License | Notes |
|-----------|---------|-------|
| 3D Slicer | BSD-style | Permissive, commercial OK |
| nnInteractive (code) | Apache-2.0 | Permissive |
| nnInteractive (weights) | CC BY-NC-SA 4.0 | **Non-commercial only** |
| Blender | GPL | Usage OK, modifications must be shared |
| Fiji/ImageJ | GPL | Usage OK |
| OrcaSlicer | AGPL-3.0 | Usage OK |

**Important:** The nnInteractive model weights are licensed CC BY-NC-SA 4.0 by DKFZ (German Cancer Research Center). This upstream license restricts commercial use of the entire platform.

### Attribution

If you use this platform in research, please cite:
- This repository
- [nnInteractive](https://github.com/MIC-DKFZ/nnInteractive) - Isensee, F., et al. (2025). nnInteractive: Redefining 3D Promptable Segmentation. https://arxiv.org/abs/2503.08373
- [3D Slicer](https://www.slicer.org/) - Fedorov, A., et al. (2012). 3D Slicer as an Image Computing Platform for the Quantitative Imaging Network. Magnetic Resonance Imaging.

## Version

Current: v18 (January 2026)

See [`docker setup files/README.md`](docker%20setup%20files/README.md) for full changelog.
