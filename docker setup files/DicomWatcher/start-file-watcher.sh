#!/bin/bash
# Hybrid script: File Transfer + T2 DICOM Watcher
# Starts filebrowser and watches /FILE TRANSFERS for new DICOM folders
# Auto-loads T2 sequences into 3D Slicer

TRANSFER_DIR="/FILE TRANSFERS"
PORT=8080
DB="/tmp/filebrowser-$$.db"

# If not running in a terminal, relaunch in one
if [ -z "$IN_TERMINAL" ]; then
    export IN_TERMINAL=1
    xfce4-terminal --hold -x bash -c "IN_TERMINAL=1 bash '$0'"
    exit 0
fi

# ============================================
# Self-healing: Fix corrupted filebrowser binary
# ============================================
check_and_fix_filebrowser() {
    if filebrowser version > /dev/null 2>&1; then
        return 0
    fi

    echo "Filebrowser binary corrupted, downloading fresh copy..."
    FB_VERSION=$(curl -s https://api.github.com/repos/filebrowser/filebrowser/releases/latest | grep -Po '"tag_name": "v\K[^"]*')
    curl -fsSL "https://github.com/filebrowser/filebrowser/releases/download/v${FB_VERSION}/linux-amd64-filebrowser.tar.gz" -o /tmp/fb.tar.gz
    tar -xzf /tmp/fb.tar.gz -C /usr/local/bin filebrowser
    chmod +x /usr/local/bin/filebrowser
    rm -f /tmp/fb.tar.gz
    filebrowser version > /dev/null 2>&1
}

# Run self-healing check
check_and_fix_filebrowser || exit 1

# ============================================
# Create FILE TRANSFERS folder
# ============================================
mkdir -p "$TRANSFER_DIR"

# Fixed credentials
USER="admin"
PASS="runpod"

# Setup filebrowser database
filebrowser config init -d "$DB" > /dev/null 2>&1
filebrowser config set -d "$DB" -a 0.0.0.0 -p "$PORT" -r "/" --minimumPasswordLength 4 > /dev/null 2>&1
filebrowser users add "$USER" "$PASS" -d "$DB" --perm.admin > /dev/null 2>&1

# Start filebrowser in background
filebrowser -d "$DB" &
FB_PID=$!

# Start nnInteractive server in background (needed by 3D Slicer for AI segmentation)
echo "Starting nnInteractive server..."
nninteractive-slicer-server --host 0.0.0.0 --port 8000 &
NN_PID=$!

# Cleanup on exit
trap "kill $FB_PID $NN_PID 2>/dev/null; rm -f $DB" EXIT

# Wait for services to start
sleep 2

# Get URL
if [ -n "$RUNPOD_POD_ID" ]; then
    URL="https://${RUNPOD_POD_ID}-${PORT}.proxy.runpod.net/files/FILE%20TRANSFERS/"
else
    IP=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}')
    URL="http://${IP}:${PORT}/files/FILE%20TRANSFERS/"
fi

# ============================================
# Display info and start watcher
# ============================================
echo "============================================================"
echo "  DICOM WATCHER + AI SEGMENTATION"
echo "============================================================"
echo ""
echo "  File Transfer:   $URL"
echo "  Login:           $USER / $PASS"
echo ""
echo "  nnInteractive:   Running on port 8000"
echo "  Watching:        $TRANSFER_DIR"
echo "  Action:          Auto-load T2 DICOM into 3D Slicer"
echo ""
echo "============================================================"
echo ""
echo "Upload DICOM folders via browser - T2 series will auto-load!"
echo "Press Ctrl+C to stop."
echo ""

# ============================================
# T2 Watcher (Python)
# ============================================
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
    print("ERROR: pydicom not installed")
    sys.exit(1)

SLICER_PATH = "/usr/local/bin/Slicer"
WATCH_DIR = "$TRANSFER_DIR"
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
import os
import qt

dicom_folder = r"{dicom_folder}"
series_uids = {series_list}

def loadDICOMData():
    """Load DICOM data after Slicer is fully initialized"""
    from DICOMLib import DICOMUtils

    print(f"Loading DICOM from: {{dicom_folder}}")

    # Ensure DICOM module is loaded first
    try:
        slicer.util.selectModule('DICOM')
    except:
        pass

    # Initialize DICOM database
    print("Initializing DICOM database...")
    dbPath = os.path.join(os.path.expanduser("~"), "Documents", "SlicerDICOMDatabase")
    if not os.path.exists(dbPath):
        os.makedirs(dbPath)

    # Open database (this creates it if needed)
    try:
        DICOMUtils.openDatabase(dbPath)
    except Exception as e:
        print(f"openDatabase failed: {{e}}, trying openTemporaryDatabase...")
        DICOMUtils.openTemporaryDatabase()

    db = slicer.dicomDatabase
    if not db or not db.isOpen:
        print("ERROR: Failed to open DICOM database")
        return

    print(f"DICOM database opened: {{db.databaseFilename}}")

    # Import DICOM files
    print("Importing DICOM files...")
    indexer = ctk.ctkDICOMIndexer()
    indexer.addDirectory(db, dicom_folder)
    indexer.waitForImportFinished()
    print("Import complete")

    # Load the T2 series
    loadedNodes = []
    if series_uids:
        for uid in series_uids:
            try:
                nodes = DICOMUtils.loadSeriesByUID([uid])
                if nodes:
                    loadedNodes.extend(nodes)
                    print(f"Loaded series: {{uid}}")
            except Exception as e:
                print(f"Error loading {{uid}}: {{e}}")

    if loadedNodes:
        print(f"Successfully loaded {{len(loadedNodes)}} volume(s)")
        # Switch to a useful view
        slicer.util.selectModule('Data')
    else:
        print("No volumes loaded - check DICOM data")

# Delay execution to allow Slicer to fully initialize
# 3000ms should be enough for DICOM module to load
qt.QTimer.singleShot(3000, loadDICOMData)
print("DICOM loading scheduled (waiting for Slicer to initialize...)")
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

def wait_for_upload_complete(folder_path, stable_seconds=5):
    """Wait until no new files appear for stable_seconds"""
    print(f"Waiting for upload to complete...")

    def count_files():
        count = 0
        total_size = 0
        for root, dirs, files in os.walk(folder_path):
            for f in files:
                count += 1
                try:
                    total_size += os.path.getsize(os.path.join(root, f))
                except:
                    pass
        return count, total_size

    last_count, last_size = 0, 0
    stable_time = 0

    while stable_time < stable_seconds:
        time.sleep(1)
        current_count, current_size = count_files()

        if current_count == last_count and current_size == last_size:
            stable_time += 1
        else:
            stable_time = 0
            last_count, last_size = current_count, current_size

    print(f"Upload complete ({last_count} files)")

def process_folder(folder_path):
    global processed_folders
    if folder_path in processed_folders:
        return

    # Add IMMEDIATELY to prevent race condition from multiple file system events
    processed_folders.add(folder_path)

    print(f"\n[NEW FOLDER] {os.path.basename(folder_path)}")

    # Wait for upload to finish (no new files for 5 seconds)
    wait_for_upload_complete(folder_path, stable_seconds=5)

    print("Scanning for T2 series...")

    t2_files, series_info, series_uids = find_t2_series(folder_path)

    if t2_files:
        print(f"Found {len(t2_files)} T2 files in {len(series_uids)} series:")
        for uid, info in series_info.items():
            print(f"  - {info['description']} ({len(info['files'])} files)")

        dicom_folder = os.path.dirname(t2_files[0])
        print("Launching 3D Slicer...")
        launch_slicer_with_dicom(dicom_folder, series_uids)
        print("Done!\n")
    else:
        print("No T2 series found in this folder.\n")

class FolderHandler(FileSystemEventHandler):
    def on_created(self, event):
        if event.is_directory:
            if os.path.dirname(event.src_path) == WATCH_DIR:
                process_folder(event.src_path)

    def on_moved(self, event):
        if event.is_directory:
            if os.path.dirname(event.dest_path) == WATCH_DIR:
                process_folder(event.dest_path)

if __name__ == "__main__":
    event_handler = FolderHandler()
    observer = Observer()
    observer.schedule(event_handler, WATCH_DIR, recursive=False)
    observer.start()

    print(f"Watching for new folders in {WATCH_DIR}...")
    print("")

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
        print("\nStopped watching.")

    observer.join()
PYTHON_SCRIPT
