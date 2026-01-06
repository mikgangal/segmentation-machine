# UMD Dataset - Selected Cases for Usability Study

## Study Context

These cases were selected from the Uterine Myoma MRI Dataset (UMD) for use in a pilot usability study evaluating a cloud-based 3D segmentation platform for fibroid surgical planning. The study aims to assess whether clinicians with varying technical backgrounds can successfully deploy and use the platform to segment uterine structures.

**Primary Research Question:** Can non-programmer clinicians (gynecologists, radiologists) use a cloud-based segmentation platform to create clinically useful 3D models of fibroid-cavity relationships?

---

## Source Dataset

**Dataset Name:** Large-scale uterine myoma MRI dataset covering all FIGO types with pixel-level annotations (UMD)

**Publication:** Pan, H., Chen, M., Bai, W. et al. Large-scale uterine myoma MRI dataset covering all FIGO types with pixel-level annotations. *Sci Data* 11, 410 (2024).

**DOI:** https://doi.org/10.1038/s41597-024-03170-x

**Data Repository:** https://doi.org/10.6084/m9.figshare.23541312.v3

**License:** CC BY 4.0

---

## Selection Criteria

Cases were reviewed and selected based on the following criteria to identify optimal examples for the usability study:

1. **Submucosal component** - Preference for FIGO Types 0-2 or hybrid types (e.g., 2-5) where fibroids distort or contact the endometrial cavity
2. **Cavity visibility** - Clear visualization of the endometrial cavity to allow assessment of fibroid-cavity relationships
3. **Multiple fibroids** - Cases with 3-6 visible fibroids to provide a meaningful counting/segmentation task
4. **Image quality** - Adequate signal-to-noise ratio and minimal motion artifacts
5. **Segmentation availability** - Presence of expert ground-truth segmentation for validation

---

## Selected Cases

| # | Study ID | Files | Selection Notes |
|---|----------|-------|-----------------|
| 1 | UMD_221129_050 | t2, seg | |
| 2 | UMD_221129_059 | t2, seg | |
| 3 | UMD_221129_085 | t2, seg | |
| 4 | UMD_221129_091 | t2, seg | |
| 5 | UMD_221129_093 | t2, seg | |
| 6 | UMD_221129_104 | t2, seg | |
| 7 | UMD_221129_135 | t2, seg | |
| 8 | UMD_221129_160 | t2, seg | |
| 9 | UMD_221129_161 | t2, seg | |
| 10 | UMD_221129_162 | t2, seg | |
| 11 | UMD_221129_201 | t2, seg | |
| 12 | UMD_221129_253 | t2, seg | |
| 13 | UMD_221129_268 | t2, seg | |

**Total selected:** 13 cases from 300 available in the full dataset

---

## File Structure

Each case folder contains:

```
UMD_221129_XXX/
├── UMD_221129_XXX_t2.nii.gz      # T2-weighted MRI (sagittal)
└── UMD_221129_XXX_seg.nii.gz     # Expert segmentation mask
```

### Segmentation Labels

The `_seg.nii.gz` files contain pixel-level annotations with the following label values:

| Label Value | Structure |
|-------------|-----------|
| 1 | Uterine wall (myometrium) |
| 2 | Uterine cavity (endometrium + junctional zone) |
| 3 | Myoma (fibroid) |
| 4 | Nabothian cyst |

---

## Technical Specifications

**MRI Acquisition Parameters** (from source publication):
- Scanner: Philips Ingenia 3.0T
- Sequence: T2-weighted imaging (T2WI)
- Plane: Sagittal
- TR: 4200 ms
- TE: 130 ms
- Flip angle: 90°
- Voxel size: 0.8 × 0.8 × 4.0 mm³
- Slice gap: 0.4 mm

**Known Limitations:**
- Sagittal acquisition only (limited coronal/axial resolution)
- 4mm slice thickness with gaps limits 3D reconstruction fidelity
- Suitable for 2D review and basic 3D visualization, but not high-resolution volumetric analysis

---

## Loading in 3D Slicer

### Load MRI Volume
```
File → Add Data → Select UMD_221129_XXX_t2.nii.gz → OK
```

### Load Segmentation (Important)
```
File → Add Data → Select UMD_221129_XXX_seg.nii.gz
→ Change "Description" dropdown from "Volume" to "Segmentation"
→ OK
```

### Python Console (batch loading)
```python
import slicer

case_id = "050"  # Change as needed
base_path = "/path/to/UMD_221129_" + case_id

# Load volume
volumeNode = slicer.util.loadVolume(f"{base_path}/UMD_221129_{case_id}_t2.nii.gz")

# Load segmentation
segNode = slicer.util.loadSegmentation(f"{base_path}/UMD_221129_{case_id}_seg.nii.gz")
```

---

## Intended Use

These cases are intended for:

1. **Usability study standardized test cases** - Participants segment structures using the cloud platform, results compared to ground truth
2. **Platform demonstration** - YouTube tutorial videos showing segmentation workflow
3. **Pilot validation** - Preliminary accuracy metrics before larger clinical validation

**Not intended for:** Direct clinical decision-making or diagnostic purposes.

---

## Citation Requirements

When using these data, please cite:

> Pan, H., Chen, M., Bai, W. et al. Large-scale uterine myoma MRI dataset covering all FIGO types with pixel-level annotations. Sci Data 11, 410 (2024). https://doi.org/10.1038/s41597-024-03170-x

---

## Contact

*[Add study contact information here]*

---

*Last updated: January 2026*
*Case selection performed by: [Add name]*
