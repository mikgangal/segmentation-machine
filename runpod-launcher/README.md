# RunPod Launcher for 3D Slicer

A simple Go CLI tool that launches a 3D Slicer pod on RunPod with one click.

## What It Does

1. Prompts for RunPod API key (saves to `~/.slicer-launcher-config` for future use)
2. Creates a pod using the RunPod REST API with:
   - Template: `3ikte0az1e` (mikgangal/3dslicer-nninteractive:v16)
   - Network Volume: `5oxn5a36e6` (vhp, 100GB in CA-MTL-3)
   - GPU: NVIDIA RTX PRO 6000 Blackwell Server Edition
   - Ports: inherited from template
3. Polls pod status until public IP is assigned
4. Polls VNC URL until port is accessible
5. Displays connection info:
   - **noVNC** (web browser)
   - **TurboVNC** (IP:port for native VNC client)
   - **SSH** (command with port)
   - **File Browser** (if 8080 exposed in template)
6. Opens browser to noVNC interface
7. Shows **account balance** (green) and **cost/hr** (red), refreshes every 5 minutes
8. **Auto-terminates pod** when window is closed or Enter is pressed (prevents overcharges)

## Auto-Termination

The launcher automatically terminates the pod to prevent unexpected charges:

- **Press Enter** → Pod is terminated, window closes
- **Ctrl+C** → Pod is terminated gracefully
- **Close window** → Signal handler terminates pod (best effort)

⚠️ **Warning**: This means any unsaved work in the pod will be lost. Save your data to the network volume before closing!

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

### Get Pod Status
```
GET https://rest.runpod.io/v1/pods/{podId}
```

Pod is ready when `publicIp` field is non-empty.

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
