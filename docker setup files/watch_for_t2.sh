#!/bin/bash
# Watch for new folders and automatically load T2 series into 3D Slicer
# Double-click to start watching

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# If not running in a terminal, relaunch in one
if [ -z "$IN_TERMINAL" ]; then
    export IN_TERMINAL=1
    xfce4-terminal --working-directory="$SCRIPT_DIR" --hold -x bash -c "cd \"$SCRIPT_DIR\" && IN_TERMINAL=1 bash \"$SCRIPT_DIR/watch_for_t2.sh\""
    exit 0
fi

cd "$SCRIPT_DIR"

echo "=========================================="
echo "  T2 DICOM Folder Watcher"
echo "=========================================="
echo ""
echo "Watching: $SCRIPT_DIR"
echo "Drop a folder here to auto-load T2 into Slicer"
echo ""
echo "Press Ctrl+C to stop watching"
echo "=========================================="
echo ""

python3 << 'PYTHON_SCRIPT'
import os
import sys
import glob
import subprocess
import tempfile
import time
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

try:
    import pydicom
except ImportError:
    print("Install pydicom: pip install --break-system-packages pydicom")
    sys.exit(1)

SLICER_PATH = "/usr/local/bin/Slicer"
WATCH_DIR = os.getcwd()
processed_folders = set()

def find_t2_series(data_folder):
    dcm_files = glob.glob(os.path.join(data_folder, "**", "*.dcm"), recursive=True)

    if not dcm_files:
        return [], {}, []

    t2_files = []
    series_info = {}
    series_uids = []

    for dcm_path in dcm_files:
        try:
            ds = pydicom.dcmread(dcm_path, stop_before_pixels=True)
            series_desc = getattr(ds, 'SeriesDescription', '') or ''
            protocol = getattr(ds, 'ProtocolName', '') or ''
            series_uid = getattr(ds, 'SeriesInstanceUID', '')
            desc = (series_desc + ' ' + protocol).upper()

            t2_patterns = ['T2', 'T2W', 'T2_', '_T2']
            is_t2 = any(p in desc for p in t2_patterns)

            if is_t2:
                t2_files.append(dcm_path)
                if series_uid not in series_info:
                    series_info[series_uid] = {
                        'description': series_desc or protocol,
                        'files': []
                    }
                    series_uids.append(series_uid)
                series_info[series_uid]['files'].append(dcm_path)
        except Exception:
            continue

    return t2_files, series_info, series_uids

def get_slicer_load_script(dicom_folder, series_uids):
    series_list = str(series_uids)
    script = f'''
import slicer
from DICOMLib import DICOMUtils

dicom_folder = r"{dicom_folder}"
series_uids = {series_list}

print(f"Loading DICOM from: {{dicom_folder}}")

indexer = ctk.ctkDICOMIndexer()
indexer.addDirectory(slicer.dicomDatabase, dicom_folder)
indexer.waitForImportFinished()

if series_uids:
    for uid in series_uids:
        try:
            DICOMUtils.loadSeriesByUID([uid])
            print(f"Loaded series: {{uid}}")
        except Exception as e:
            print(f"Error loading {{uid}}: {{e}}")
else:
    DICOMUtils.loadPatientByFolder(dicom_folder)

print("T2 series loaded successfully!")
'''
    return script

def launch_slicer_with_dicom(dicom_folder, series_uids):
    script_content = get_slicer_load_script(dicom_folder, series_uids)

    with tempfile.NamedTemporaryFile(mode='w', suffix='.py', delete=False) as f:
        f.write(script_content)
        temp_script = f.name

    try:
        subprocess.Popen([SLICER_PATH, '--python-script', temp_script])
        return True
    except Exception as e:
        print(f"Error launching Slicer: {e}")
        return False

def process_folder(folder_path):
    global processed_folders

    if folder_path in processed_folders:
        return

    # Wait a moment for files to finish copying
    time.sleep(2)

    print(f"\n[NEW FOLDER] {os.path.basename(folder_path)}")
    print("Scanning for T2 series...")

    t2_files, series_info, series_uids = find_t2_series(folder_path)

    if t2_files:
        print(f"Found {len(t2_files)} T2 files in {len(series_uids)} series:")
        for uid, info in series_info.items():
            print(f"  - {info['description']} ({len(info['files'])} files)")

        dicom_folder = os.path.dirname(t2_files[0])
        print("Launching 3D Slicer...")
        launch_slicer_with_dicom(dicom_folder, series_uids)
        processed_folders.add(folder_path)
        print("Done!\n")
    else:
        print("No T2 series found in this folder.\n")

class FolderHandler(FileSystemEventHandler):
    def on_created(self, event):
        if event.is_directory:
            # New folder created directly in watch dir
            if os.path.dirname(event.src_path) == WATCH_DIR:
                process_folder(event.src_path)

    def on_moved(self, event):
        if event.is_directory:
            # Folder moved/dropped into watch dir
            if os.path.dirname(event.dest_path) == WATCH_DIR:
                process_folder(event.dest_path)

if __name__ == "__main__":
    event_handler = FolderHandler()
    observer = Observer()
    observer.schedule(event_handler, WATCH_DIR, recursive=False)
    observer.start()

    print(f"Watching for new folders...")
    print("")

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
        print("\nStopped watching.")

    observer.join()
PYTHON_SCRIPT
