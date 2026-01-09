"""
Slicer Export Polling Script
Sets up a timer that watches for export trigger files.
When triggered, exports all segments as STL to /FILE TRANSFERS/
"""

import os
import glob
import qt
import vtk
import slicer
from datetime import datetime

TRIGGER_DIR = "/tmp"
TRIGGER_PREFIX = "slicer-export-trigger-"
EXPORT_BASE = "/FILE TRANSFERS"
POLL_INTERVAL_MS = 1000  # Check every second

# Segments to skip (nnInteractive internal segments)
SKIP_SEGMENTS = {'<bg>', '<fg>', 'background', 'foreground'}


def export_all_segments():
    """Export all segments from all segmentation nodes as STL files + combined OBJ"""

    # Create timestamped export folder
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    export_dir = os.path.join(EXPORT_BASE, f"Export_{timestamp}")
    os.makedirs(export_dir, exist_ok=True)

    exported_count = 0
    skipped_count = 0
    model_nodes_to_export = []  # Keep track for combined OBJ

    # Get all segmentation nodes
    segmentation_nodes = slicer.util.getNodesByClass("vtkMRMLSegmentationNode")

    if not segmentation_nodes:
        print("No segmentation nodes found")
        # Create a marker file to indicate no segments
        with open(os.path.join(export_dir, "NO_SEGMENTS_FOUND.txt"), 'w') as f:
            f.write("No segmentation nodes were found in the scene.\n")
        return 0

    for seg_node in segmentation_nodes:
        segmentation = seg_node.GetSegmentation()
        num_segments = segmentation.GetNumberOfSegments()

        for i in range(num_segments):
            segment_id = segmentation.GetNthSegmentID(i)
            segment = segmentation.GetSegment(segment_id)
            segment_name = segment.GetName()

            # Skip nnInteractive internal segments
            if segment_name.lower() in [s.lower() for s in SKIP_SEGMENTS]:
                print(f"Skipping internal segment: {segment_name}")
                skipped_count += 1
                continue

            # Clean up segment name for filename
            safe_name = "".join(c if c.isalnum() or c in "._- " else "_" for c in segment_name)
            safe_name = safe_name.strip().replace(" ", "_")
            if not safe_name:
                safe_name = f"segment_{i}"

            # Add node name prefix if multiple segmentation nodes
            if len(segmentation_nodes) > 1:
                node_name = seg_node.GetName()
                safe_node_name = "".join(c if c.isalnum() or c in "._- " else "_" for c in node_name)
                safe_name = f"{safe_node_name}_{safe_name}"

            stl_path = os.path.join(export_dir, f"{safe_name}.stl")

            # Export segment as STL
            try:
                # Create a model node for export
                model_node = slicer.mrmlScene.AddNewNodeByClass("vtkMRMLModelNode")
                model_node.SetName(safe_name)

                # Export segment to model
                slicer.modules.segmentations.logic().ExportSegmentToRepresentationNode(
                    segment, model_node
                )

                # Save model as STL
                slicer.util.saveNode(model_node, stl_path)

                print(f"Exported STL: {segment_name} -> {safe_name}.stl")
                exported_count += 1

                # Keep model node for combined OBJ export
                model_nodes_to_export.append(model_node)

            except Exception as e:
                print(f"Failed to export {segment_name}: {e}")

    # Export combined OBJ with all segments
    if model_nodes_to_export:
        try:
            obj_path = os.path.join(export_dir, "combined_all_segments.obj")

            # Use vtkOBJWriter to write all models to one OBJ file
            append_filter = vtk.vtkAppendPolyData()

            for model_node in model_nodes_to_export:
                poly_data = model_node.GetPolyData()
                if poly_data and poly_data.GetNumberOfPoints() > 0:
                    append_filter.AddInputData(poly_data)

            append_filter.Update()

            writer = vtk.vtkOBJWriter()
            writer.SetFileName(obj_path)
            writer.SetInputData(append_filter.GetOutput())
            writer.Write()

            print(f"Exported combined OBJ: combined_all_segments.obj")
        except Exception as e:
            print(f"Failed to create combined OBJ: {e}")

    # Clean up temporary model nodes
    for model_node in model_nodes_to_export:
        slicer.mrmlScene.RemoveNode(model_node)

    # Write summary file
    summary_path = os.path.join(export_dir, "EXPORT_SUMMARY.txt")
    with open(summary_path, 'w') as f:
        f.write(f"Export completed: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"Segments exported: {exported_count}\n")
        f.write(f"Segments skipped: {skipped_count}\n")
        f.write(f"\nIndividual STL files:\n")
        for stl_file in sorted(glob.glob(os.path.join(export_dir, "*.stl"))):
            f.write(f"  - {os.path.basename(stl_file)}\n")
        f.write(f"\nCombined OBJ file:\n")
        f.write(f"  - combined_all_segments.obj\n")

    print(f"\n=== Export Complete ===")
    print(f"Folder: {export_dir}")
    print(f"Exported: {exported_count} segments (STL + combined OBJ)")
    print(f"Skipped: {skipped_count} segments")

    return exported_count


def check_for_trigger():
    """Check for export trigger files and process them"""
    trigger_files = glob.glob(os.path.join(TRIGGER_DIR, f"{TRIGGER_PREFIX}*"))

    for trigger_file in trigger_files:
        try:
            # Claim the trigger by deleting it
            os.remove(trigger_file)
            print(f"Export triggered by: {trigger_file}")

            # Perform export
            export_all_segments()

        except FileNotFoundError:
            # Another Slicer instance already claimed it
            pass
        except Exception as e:
            print(f"Error processing trigger: {e}")


def setup_export_polling():
    """Set up a timer to poll for export triggers"""
    timer = qt.QTimer()
    timer.timeout.connect(check_for_trigger)
    timer.start(POLL_INTERVAL_MS)

    # Store timer reference to prevent garbage collection
    slicer.exportPollingTimer = timer

    print("STL Export polling active - watching for triggers")


# Set up polling when this script is loaded
setup_export_polling()
