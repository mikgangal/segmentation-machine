# RunPod Launcher for 3D Slicer

A simple Go CLI tool that launches a 3D Slicer pod on RunPod with one click.

## What It Does

1. Prompts for RunPod API key (saves to `~/.slicer-launcher-config` for future use)
2. Creates a pod using the RunPod REST API with:
   - Template: `3ikte0az1e` (mikgangal/3dslicer-nninteractive:v16)
   - Network Volume: `5oxn5a36e6` (vhp, 100GB in CA-MTL-3)
   - GPU: NVIDIA RTX PRO 6000 Blackwell Server Edition
   - Ports: inherited from template
3. Shows **live progress** with phases and rotating tips:
   - `Waiting for GPU` → `Pulling image` → `Starting services` → `Configuring network` → `Running` → `Desktop ready`
4. Displays **load time** when ready (e.g., "Ready in 2m 35s")
5. Shows user-friendly connection info:
   - **Desktop URL** (noVNC - opens in browser)
   - **File Upload URL** with login credentials (`admin` / `runpod`)
   - **Advanced** (TurboVNC IP:port, SSH port) - dimmed for technical users
6. Opens browser tabs: noVNC first, then **File Browser** (so File Browser is the active tab)
7. Shows **account balance** (green) and **cost/hr** (red), refreshes every 5 minutes
8. **Auto-terminates pod** when window is closed or Enter is pressed (prevents overcharges)

## Sample Output

```
╔════════════════════════════════════════════════════════════╗
║           3D Slicer RunPod Launcher                        ║
╚════════════════════════════════════════════════════════════╝

── Configuration ──────────────────────────────────────────────
Template: 3ikte0az1e │ Volume: 5oxn5a36e6 │ GPU: NVIDIA RTX...
───────────────────────────────────────────────────────────────

Launching pod...
  ✓ Pod created: abc123xyz
  ✓ GPU: NVIDIA RTX PRO 6000 Blackwell Server Edition

  ⠹ Waiting for GPU (in queue) - 45s
    💡 Use File Browser to drag & drop files directly to the pod

  ✓ Waiting for GPU
  ⠸ Pulling image - 1m 15s
    💡 TurboVNC client gives better performance than browser

  ✓ Pulling image
  ✓ Starting services
  ✓ Running
  ✓ Desktop ready

✓ Ready in 2m 35s

╔════════════════════════════════════════════════════════════╗
║  YOUR SESSION IS READY                                     ║
╠════════════════════════════════════════════════════════════╣
║                                                            ║
║  Desktop (opens automatically in browser):                 ║
║    https://abc123xyz-6080.proxy.runpod.net                 ║
║                                                            ║
║  File Upload (drag & drop files):                          ║
║    https://abc123xyz-8080.proxy.runpod.net/FILE%20TRANSFERS/
║    Login: admin / runpod                                   ║
║                                                            ║
║  Advanced: VNC 123.45.67.89:12345 │ SSH -p 23456           ║
╚════════════════════════════════════════════════════════════╝

Opening desktop (noVNC)...
  ✓ File Browser ready
Opening File Browser (for uploads)...

⚠  IMPORTANT: Closing this window terminates the pod!

Balance: $50.00 │ Cost: $1.14/hr │ Runtime: ~43.9 hrs

Press Enter to TERMINATE pod and exit...
```

## Auto-Termination

The launcher automatically terminates the pod to prevent unexpected charges:

- **Press Enter** → Pod is terminated, window closes
- **Ctrl+C** → Pod is terminated gracefully
- **Close window** → Signal handler terminates pod (best effort)

**Warning**: This means any unsaved work in the pod will be lost. Save your data to the network volume before closing!

## Usage

**Pre-built executables included** - just download and run. No secrets are baked in; you'll be prompted for your own RunPod API key on first run.

| Platform | File |
|----------|------|
| Windows | `SlicerLauncher-windows.exe` |
| Mac (Intel) | `SlicerLauncher-mac-intel` |
| Mac (Apple Silicon M1/M2/M3) | `SlicerLauncher-mac-arm64` |

On Mac, you may need to: `chmod +x SlicerLauncher-mac-*` and allow in System Preferences > Security.

## Building (optional)

### Windows
```batch
build.bat
```

### Linux/Mac (cross-compile for Windows)
```bash
./build.sh
```

### Manual Build
```bash
go build -ldflags="-s -w" -o SlicerLauncher.exe main.go
```

## Configuration

Edit constants in `main.go`:

```go
const (
    templateID      = "3ikte0az1e"      // RunPod template ID
    networkVolumeID = "5oxn5a36e6"      // Network volume ID (CA-MTL-3)
)

var gpuTypes = []string{
    "NVIDIA RTX PRO 6000 Blackwell Server Edition",
}
```

Ports are inherited from the template configuration in RunPod.

## API Key

- Get your API key from: https://www.runpod.io/console/user/settings
- Key must have **All** permissions (not read-only)
- Saved to: `~/.slicer-launcher-config`

## Features

### Progress Phases
The launcher detects pod state via GraphQL and shows meaningful progress:
- **Waiting for GPU** - Pod created, waiting for GPU allocation
- **Pulling image** - GPU assigned, downloading Docker image
- **Starting services** - Image ready, services starting
- **Configuring network** - Setting up ports
- **Running** - Pod is running
- **Desktop ready** - VNC accessible

### Rotating Tips
While waiting, helpful tips rotate every 5 seconds:
- File persistence info
- File Browser usage
- TurboVNC performance tips
- Pre-installed tools (Claude Code, lazygit, etc.)
- DICOM auto-loading feature

### Browser Tab Order
Opens noVNC first, then File Browser second - so **File Browser is the active tab** when loading completes. This is optimized for the upload-first workflow.

## RunPod REST API Notes

For debugging or extending this tool:

### Authentication
```
Authorization: Bearer <api_key>
```

### Create Pod
```
POST https://rest.runpod.io/v1/pods
Content-Type: application/json

{
  "name": "slicer-1234567890",
  "templateId": "3ikte0az1e",
  "networkVolumeId": "5oxn5a36e6",
  "gpuTypeIds": ["NVIDIA RTX PRO 6000 Blackwell Server Edition"],
  "gpuCount": 1
}
```

**Important API notes:**
- `gpuTypeIds` must be an **array**, not a string
- Ports are inherited from the template (don't specify unless overriding)
- Don't include `volumeInGb` when using a network volume

### Get Account Balance (GraphQL)
```
POST https://api.runpod.io/graphql?api_key=<api_key>
Content-Type: application/json

{"query": "query { myself { currentSpendPerHr clientBalance } }"}
```

### Get Pod Status (GraphQL)
```
POST https://api.runpod.io/graphql?api_key=<api_key>
Content-Type: application/json

{"query": "query { pod(input: {podId: \"xxx\"}) { id runtime { ports { ip isIpPublic privatePort publicPort type } gpus { id } } } }"}
```

### Terminate Pod
```
DELETE https://rest.runpod.io/v1/pods/{podId}
```

Returns 200 or 204 on success.

### Valid GPU Types (as of Jan 2026)
```
NVIDIA GeForce RTX 4090
NVIDIA GeForce RTX 5090
NVIDIA RTX 6000 Ada Generation
NVIDIA RTX PRO 6000 Blackwell Server Edition
NVIDIA RTX PRO 6000 Blackwell Workstation Edition
NVIDIA A40
NVIDIA L40S
NVIDIA H100 80GB HBM3
NVIDIA A100-SXM4-80GB
... and more
```

## Debugging

To add debug output, insert these lines in `launchPod()`:

```go
// After json.Marshal
fmt.Printf("DEBUG Request body: %s\n", string(jsonBody))

// After setting headers
fmt.Printf("DEBUG Auth header: Bearer %s...%s\n", apiKey[:8], apiKey[len(apiKey)-4:])

// After io.ReadAll
fmt.Printf("DEBUG Response status: %d\n", resp.StatusCode)
fmt.Printf("DEBUG Response body: %s\n", string(body))
```

## File Structure

```
runpod-launcher/
├── SlicerLauncher-windows.exe  # Windows executable
├── SlicerLauncher-mac-intel    # Mac Intel executable
├── SlicerLauncher-mac-arm64    # Mac Apple Silicon executable
├── main.go                     # Main application source
├── ansi_windows.go             # Windows ANSI color support
├── ansi_other.go               # Mac/Linux ANSI (no-op)
├── go.mod                      # Go module file
├── build.bat                   # Windows build script (all platforms)
├── build.sh                    # Linux/Mac build script (all platforms)
├── .gitignore                  # Ignores temp files
└── README.md                   # This file
```

## Changelog

### v2 (Jan 2026)
- **Progress phases** - Shows meaningful status (Waiting for GPU, Pulling image, etc.)
- **Load time tracking** - Displays total time to ready
- **Rotating tips** - 12 helpful tips while waiting
- **File Browser credentials** - Shows `admin / runpod` in connection info
- **Compact technical info** - Configuration details dimmed at top
- **Tab order fix** - File Browser opens last (becomes active tab)
- **Session duration** - Balance updates show elapsed session time

### v1 (Jan 2026)
- Initial release
- One-click pod launch
- Auto-termination on exit
- Account balance display

## License

This component is part of the Segmentation Machine project, licensed under [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/).

See the root [LICENSE](../LICENSE) file for full terms.

---

## Instructions for Claude Code

When adding new scripts, files, or functionality to this project:

1. **Add copyright headers** to all new source files:
   - Go files: `// Copyright (c) 2025-2026 Mik Gangal` + `// Licensed under CC BY-NC-SA 4.0 - https://creativecommons.org/licenses/by-nc-sa/4.0/`
   - Shell scripts: Same format with `#` comments

2. **Maintain non-commercial licensing** - This project uses CC BY-NC-SA 4.0 due to upstream nnInteractive model weight restrictions

3. **Update LICENSE file** if adding new third-party components - list them in the NOTICES section

4. **Attribution required** for any derivative work or research use
