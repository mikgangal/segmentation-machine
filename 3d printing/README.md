# 3D Printing Integration

This document describes the recommended approach for sending segmented medical models to a 3D printer.

## Recommended Workflow

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│ Export STL  │────▶│ Download    │────▶│ Open in     │────▶│ Send to     │
│ from 3D     │     │ via File    │     │ Print       │     │ Printer     │
│ Slicer      │     │ Browser     │     │ Slicer      │     │ via Cloud   │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
```

1. **Export STL** - Click "Export STL" on desktop to export segments from 3D Slicer
2. **Download** - Use File Browser (port 8080) to download STL files from `/FILE TRANSFERS/Export_*/`
3. **Open in Print Slicer** - Use your preferred slicer (OrcaSlicer, Bambu Studio, PrusaSlicer, Cura)
4. **Send to Printer** - Login to your cloud account, slice, and send to your printer

## Recommended Print Slicers

| Slicer | Cloud Support | Best For |
|--------|---------------|----------|
| **OrcaSlicer** | Bambu Cloud, Prusa Connect | Bambu Lab printers, multi-brand |
| **Bambu Studio** | Bambu Cloud | Bambu Lab printers only |
| **PrusaSlicer** | Prusa Connect | Prusa printers, generic printers |
| **Cura** | Ultimaker Cloud | Ultimaker, generic printers |

### Why OrcaSlicer?

OrcaSlicer is recommended because it:
- Has built-in Bambu Cloud integration (like Bambu Studio)
- Supports many other printer brands (like PrusaSlicer/Cura)
- Is actively maintained with frequent updates
- Available for Windows, Mac, and Linux

Download: https://github.com/SoftFever/OrcaSlicer

## Supported Printers (via Cloud)

| Brand | Cloud Service | Notes |
|-------|---------------|-------|
| **Bambu Lab** | Bambu Cloud | X1C, P1S, P1P, A1 - full integration |
| **Prusa** | Prusa Connect | MK4, XL, Mini |
| **Creality** | Creality Cloud | K1, Ender series (with WiFi) |
| **AnkerMake** | AnkerMake app | M5, M5C |
| **Many others** | Via profiles | Any printer with gcode support |

## Example Workflow (Bambu X1C)

1. In the VM: Click **Export STL** on desktop
2. In the VM: Open File Browser, download your STL files
3. On your computer: Open **OrcaSlicer**
4. Login to **Bambu Cloud** (one-time setup)
5. Import your STL files
6. Select your **Bambu X1C** from the printer dropdown
7. Choose **filament** and **print settings**
8. Click **Slice**, then **Print** → sends directly to your X1C

## Future Enhancement

A future version could include OrcaSlicer pre-installed in the Docker image with:
- GPU-accelerated 3D preview via VirtualGL
- Desktop shortcut to open latest export directly
- Same cloud login workflow, but entirely within the VM

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
