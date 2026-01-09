# Instructions for Claude Code

Please add proper licensing to my project repository. This is a medical imaging platform that packages open-source tools (3D Slicer, nnInteractive, Blender) into a cloud-deployable Docker environment.

## Task 1: Create LICENSE file

Create a file called `LICENSE` in the repository root with this content:

```
Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International

Copyright (c) 2025-2026 Mik Gangal

This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

You are free to:
- Share — copy and redistribute the material in any medium or format
- Adapt — remix, transform, and build upon the material

Under the following terms:
- Attribution — You must give appropriate credit, provide a link to the license, and indicate if changes were made.
- NonCommercial — You may not use the material for commercial purposes.
- ShareAlike — If you remix, transform, or build upon the material, you must distribute your contributions under the same license as the original.

No additional restrictions — You may not apply legal terms or technological measures that legally restrict others from doing anything the license permits.

Full license text: https://creativecommons.org/licenses/by-nc-sa/4.0/legalcode

---

NOTICES:

This repository contains original work including:
- Docker build configuration and scripts
- RunPod launcher application
- DICOM watcher and file transfer automation
- Desktop environment configuration
- Documentation

This project integrates the following third-party components, each under their own licenses:
- 3D Slicer: BSD-style license (https://www.slicer.org/wiki/License)
- nnInteractive: Code under Apache-2.0, Model weights under CC BY-NC-SA 4.0 (https://github.com/MIC-DKFZ/nnInteractive)
- Blender: GPL (https://www.blender.org/about/license/)
- Fiji/ImageJ: GPL (https://imagej.net/licensing/)
- TurboVNC: GPL (https://turbovnc.org)
- VirtualGL: wxWindows Library License (https://virtualgl.org)
- File Browser: Apache-2.0 (https://filebrowser.org)

The nnInteractive model weights are licensed under CC BY-NC-SA 4.0 by the German Cancer Research Center (DKFZ). Commercial use of this platform is restricted by this upstream license.
```

## Task 2: Add License section to README.md

Add the following section to the main README.md file (near the end, before any "Version History" or "Changelog" section if one exists):

```markdown
## License

This project is licensed under [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/) (Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International).

### What this means

✅ **You CAN:**
- Use this for research, education, and non-commercial clinical work
- Modify and adapt the platform for your needs
- Share and redistribute with proper attribution

❌ **You CANNOT:**
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

**Important:** The nnInteractive model weights are licensed CC BY-NC-SA 4.0 by DKFZ (German Cancer Research Center). This upstream license restricts commercial use of the entire platform.

### Attribution

If you use this platform in research, please cite:
- This repository
- [nnInteractive](https://github.com/MIC-DKFZ/nnInteractive) - Isensee, F., et al. (2025). nnInteractive: Redefining 3D Promptable Segmentation. https://arxiv.org/abs/2503.08373
- [3D Slicer](https://www.slicer.org/) - Fedorov, A., et al. (2012). 3D Slicer as an Image Computing Platform for the Quantitative Imaging Network. Magnetic Resonance Imaging.
```

## Task 3: Add copyright headers to key original files

Add this header to the top of these files (if they don't already have headers):
- `start.sh`
- `github-launcher`
- `start-file-watcher.sh`
- `export-segments.py`
- `main.go` (RunPod launcher)

Header for shell scripts:
```bash
#!/bin/bash
# Copyright (c) 2025-2026 Mik Gangal
# Licensed under CC BY-NC-SA 4.0 - https://creativecommons.org/licenses/by-nc-sa/4.0/
```

Header for Python:
```python
# Copyright (c) 2025-2026 Mik Gangal
# Licensed under CC BY-NC-SA 4.0 - https://creativecommons.org/licenses/by-nc-sa/4.0/
```

Header for Go:
```go
// Copyright (c) 2025-2026 Mik Gangal
// Licensed under CC BY-NC-SA 4.0 - https://creativecommons.org/licenses/by-nc-sa/4.0/
```

---

After making these changes, commit with the message:
```
Add CC BY-NC-SA 4.0 licensing

- Add LICENSE file with full terms and third-party notices
- Add License section to README with usage guidelines
- Add copyright headers to original source files
```
