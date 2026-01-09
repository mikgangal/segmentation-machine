# 3D Printing Integration

Send your segmented medical models directly to a 3D printer via OrcaSlicer.

## How It Works

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│ Export STL  │────▶│ Click "Send │────▶│ OrcaSlicer  │────▶│ User sends  │
│ from 3D     │     │ to Printer" │     │ opens with  │     │ to printer  │
│ Slicer      │     │             │     │ STL loaded  │     │ via cloud   │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
```

1. **Export STL** - Click "Export STL" on desktop (already working)
2. **Send to Printer** - Click "Send to Printer" desktop shortcut
3. **OrcaSlicer opens** - Loads all STL files from your latest export
4. **You handle the rest** - Login to your cloud account, select printer, slice, print

## Desktop Shortcuts

| Shortcut | Location | Function |
|----------|----------|----------|
| **Export STL** | Desktop | Export segments from 3D Slicer to `/FILE TRANSFERS/Export_*/` |
| **Send to Printer** | Desktop | Open latest export in OrcaSlicer |
| **OrcaSlicer** | Tools folder | Launch OrcaSlicer directly |

## First-Time Setup (One Time)

When you first open OrcaSlicer, you'll need to:

1. **Login to your cloud account** (if using Bambu Lab, Prusa Connect, etc.)
2. **Add your printer** - OrcaSlicer will detect cloud-connected printers
3. **Configure filament profiles** for your materials

After initial setup, your printers and profiles are saved.

## Supported Printers

OrcaSlicer supports many printers with cloud connectivity:

| Brand | Cloud Service | Notes |
|-------|---------------|-------|
| **Bambu Lab** | Bambu Cloud | X1C, P1S, P1P, A1 - full integration |
| **Prusa** | Prusa Connect | MK4, XL, Mini |
| **Creality** | Creality Cloud | K1, Ender series (with WiFi) |
| **AnkerMake** | AnkerMake app | M5, M5C |
| **Many others** | Via profiles | Any printer with gcode support |

## Workflow Example (Bambu X1C)

1. Click **Export STL** on desktop
2. Click **Send to Printer** on desktop
3. OrcaSlicer opens with your STL files loaded
4. Select your **Bambu X1C** from the printer dropdown (already logged in)
5. Choose **filament** and **print settings**
6. Click **Slice**
7. Click **Print** → sends directly to your X1C

## Files Added to Docker Image

```
/usr/local/bin/OrcaSlicer          # Wrapper script with GPU acceleration
/usr/local/bin/open-in-print-slicer # Finds latest export and opens in OrcaSlicer
/opt/orcaslicer/                    # OrcaSlicer installation (extracted AppImage)
/root/Desktop/SendToPrinter.desktop # Desktop shortcut
/root/Desktop/Tools/OrcaSlicer.desktop # Tools folder shortcut
```

## Technical Details

- **OrcaSlicer** is a fork of Bambu Studio with multi-printer support
- Runs with **VirtualGL** for GPU-accelerated 3D preview
- AppImage is extracted (not run via FUSE) for Docker compatibility
- User config stored in `~/.config/OrcaSlicer/` (persists on network volume if mounted at `/root`)

## Why OrcaSlicer?

| Feature | OrcaSlicer | Bambu Studio | PrusaSlicer | Cura |
|---------|------------|--------------|-------------|------|
| Bambu Cloud sync | Yes | Yes | No | No |
| Multi-brand support | Yes | Limited | Yes | Yes |
| Linux GUI | Yes | Yes | Yes | Yes |
| Active development | Very | Moderate | Very | Very |
| Based on | Bambu Studio | PrusaSlicer | - | - |

OrcaSlicer gives you Bambu Cloud integration (like Bambu Studio) plus support for other printers (like PrusaSlicer/Cura).

## Persistent Settings

To keep your OrcaSlicer settings (printers, login, profiles) across sessions:

**Option A:** Mount network volume at `/root`
- Settings in `~/.config/OrcaSlicer/` persist automatically

**Option B:** Export/import profiles
- Use OrcaSlicer's export function to save profiles
- Store in `/workspace` (network volume)
- Import on new sessions

## Troubleshooting

### OrcaSlicer won't start
```bash
# Check if installation is valid
/opt/orcaslicer/AppRun --help
```

### No printers showing
- Make sure you're logged into your cloud account (Bambu, Prusa, etc.)
- Check internet connectivity from the pod

### STL files not loading
- Verify export completed: `ls -la "/FILE TRANSFERS/Export_*"`
- Check for STL files: `find "/FILE TRANSFERS" -name "*.stl"`

## License

This component is part of the Segmentation Machine project, licensed under [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/).

See the root [LICENSE](../LICENSE) file for full terms.

---

## Instructions for Claude Code

When adding new scripts, files, or functionality to this project:

1. **Add copyright headers** to all new source files:
   - Shell scripts: `# Copyright (c) 2025-2026 Mik Gangal` + `# Licensed under CC BY-NC-SA 4.0 - https://creativecommons.org/licenses/by-nc-sa/4.0/`
   - Python: Same format with `#` comments

2. **Maintain non-commercial licensing** - This project uses CC BY-NC-SA 4.0 due to upstream nnInteractive model weight restrictions

3. **Update LICENSE file** if adding new third-party components - list them in the NOTICES section

4. **Attribution required** for any derivative work or research use
