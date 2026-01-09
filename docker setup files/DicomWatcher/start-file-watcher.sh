#!/bin/bash
# Hybrid script: File Transfer + DICOM Watcher
# Starts filebrowser and watches /FILE TRANSFERS for new DICOM folders
# Auto-loads ALL DICOM series into 3D Slicer, user selects in nnInteractive

TRANSFER_DIR="/FILE TRANSFERS"
PORT=8080
LOG_FILE="/tmp/dicom-services.log"
PID_FILE="/tmp/dicom-services.pid"

# ============================================
# Mode: Services (runs minimized with verbose logs)
# ============================================
if [ "$1" = "--services" ]; then
    DB="/tmp/filebrowser-$$.db"

    # Self-healing: Fix corrupted filebrowser binary
    if ! filebrowser version > /dev/null 2>&1; then
        echo "Filebrowser binary corrupted, downloading fresh copy..."
        FB_VERSION=$(curl -s https://api.github.com/repos/filebrowser/filebrowser/releases/latest | grep -Po '"tag_name": "v\K[^"]*')
        curl -fsSL "https://github.com/filebrowser/filebrowser/releases/download/v${FB_VERSION}/linux-amd64-filebrowser.tar.gz" -o /tmp/fb.tar.gz
        tar -xzf /tmp/fb.tar.gz -C /usr/local/bin filebrowser
        chmod +x /usr/local/bin/filebrowser
        rm -f /tmp/fb.tar.gz
    fi

    mkdir -p "$TRANSFER_DIR"

    # Setup filebrowser
    filebrowser config init -d "$DB" > /dev/null 2>&1
    filebrowser config set -d "$DB" -a 0.0.0.0 -p "$PORT" -r "/" --minimumPasswordLength 4 > /dev/null 2>&1
    filebrowser users add admin runpod -d "$DB" --perm.admin > /dev/null 2>&1

    echo "========================================"
    echo "  SERVICE LOGS (verbose)"
    echo "========================================"
    echo ""
    echo "Starting File Browser on port $PORT..."
    filebrowser -d "$DB" &
    FB_PID=$!

    echo "Starting nnInteractive server on port 8000..."
    echo ""
    nninteractive-slicer-server --host 0.0.0.0 --port 8000 &
    NN_PID=$!

    # Save PIDs for cleanup
    echo "$FB_PID $NN_PID" > "$PID_FILE"

    # Cleanup on exit
    trap "kill $FB_PID $NN_PID 2>/dev/null; rm -f $DB $PID_FILE" EXIT

    # Keep running
    wait
    exit 0
fi

# ============================================
# Mode: Main UI (user-facing terminal)
# ============================================

# If not running in a terminal, relaunch in one
if [ -z "$IN_TERMINAL" ]; then
    export IN_TERMINAL=1
    xfce4-terminal --hold -x bash -c "IN_TERMINAL=1 bash '$0'"
    exit 0
fi

# Start services in a minimized terminal
xfce4-terminal --minimize --title "Service Logs" -x bash -c "bash '$0' --services; read -p 'Press Enter to close...'" &
sleep 1

# Wait for services to be ready
echo "Starting services..."
sleep 3

# Get URL
if [ -n "$RUNPOD_POD_ID" ]; then
    URL="https://${RUNPOD_POD_ID}-${PORT}.proxy.runpod.net/files/FILE%20TRANSFERS/"
else
    IP=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}')
    URL="http://${IP}:${PORT}/files/FILE%20TRANSFERS/"
fi

# Cleanup services on exit
trap 'if [ -f "$PID_FILE" ]; then kill $(cat "$PID_FILE") 2>/dev/null; rm -f "$PID_FILE"; fi' EXIT

# Ensure transfer directory exists (may not exist on first run)
mkdir -p "$TRANSFER_DIR"

# ============================================
# Display clean user info
# ============================================
clear
echo ""
echo "  ╔════════════════════════════════════════════════════════╗"
echo "  ║           DICOM WATCHER + AI SEGMENTATION              ║"
echo "  ╠════════════════════════════════════════════════════════╣"
echo "  ║                                                        ║"
echo "  ║  File Transfer:  $URL"
echo "  ║  Login:          admin / runpod                        ║"
echo "  ║                                                        ║"
echo "  ║  Upload a DICOM folder via browser.                    ║"
echo "  ║  All series auto-load into 3D Slicer.                  ║"
echo "  ║                                                        ║"
echo "  ╚════════════════════════════════════════════════════════╝"
echo ""
echo "  Watching: $TRANSFER_DIR"
echo "  Press Ctrl+C to stop."
echo ""
echo "  ─────────────────────────────────────────────────────────"
echo ""

# ============================================
# DICOM Watcher (Python) - Load all series
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

SLICER_PATH = "/usr/local/bin/Slicer"
WATCH_DIR = "/FILE TRANSFERS"
processed_folders = set()

def find_dicom_files(data_folder):
    """Find all DICOM files in folder (any extension)"""
    # Try common DICOM extensions
    dcm_files = glob.glob(os.path.join(data_folder, "**", "*.dcm"), recursive=True)
    dcm_files += glob.glob(os.path.join(data_folder, "**", "*.DCM"), recursive=True)
    dcm_files += glob.glob(os.path.join(data_folder, "**", "*.dicom"), recursive=True)

    # Also check for extensionless DICOM files (common in medical imaging)
    # by looking for files without extensions in the folder
    for root, dirs, files in os.walk(data_folder):
        for f in files:
            if '.' not in f:  # No extension
                dcm_files.append(os.path.join(root, f))

    return list(set(dcm_files))  # Remove duplicates

def get_slicer_load_script(dicom_folder):
    script = f'''
import slicer
import os
import qt

dicom_folder = r"{dicom_folder}"

def loadDICOMData():
    """Import and load ALL DICOM data from folder"""
    from DICOMLib import DICOMUtils

    # Initialize DICOM database
    dbPath = os.path.join(os.path.expanduser("~"), "Documents", "SlicerDICOMDatabase")
    if not os.path.exists(dbPath):
        os.makedirs(dbPath)

    try:
        DICOMUtils.openDatabase(dbPath)
    except Exception:
        DICOMUtils.openTemporaryDatabase()

    db = slicer.dicomDatabase
    if not db or not db.isOpen:
        print("Failed to open DICOM database")
        return

    # Import all DICOM files from the folder
    indexer = ctk.ctkDICOMIndexer()
    indexer.addDirectory(db, dicom_folder)
    indexer.waitForImportFinished()

    # Get all patients/studies/series that were just imported
    # and load everything
    loadedNodes = []
    for patient in db.patients():
        for study in db.studiesForPatient(patient):
            for series in db.seriesForStudy(study):
                try:
                    nodes = DICOMUtils.loadSeriesByUID([series])
                    if nodes:
                        loadedNodes.extend(nodes)
                except Exception as e:
                    print(f"Could not load series: {{e}}")

    print(f"Loaded {{len(loadedNodes)}} volume(s)")

    # Switch to nnInteractive - user selects which volume to segment
    slicer.util.selectModule('SlicerNNInteractive')

def maximizeWindow():
    """Maximize the main window"""
    mainWindow = slicer.util.mainWindow()
    if mainWindow:
        mainWindow.showMaximized()

# Maximize window immediately
qt.QTimer.singleShot(500, maximizeWindow)
# Delay DICOM loading to allow Slicer to fully initialize
qt.QTimer.singleShot(3000, loadDICOMData)
'''
    return script

def minimize_terminal():
    """Minimize the current terminal window"""
    try:
        subprocess.run(['xdotool', 'getactivewindow', 'windowminimize'],
                      capture_output=True, timeout=2)
    except Exception:
        pass

def launch_slicer_with_dicom(dicom_folder):
    script_content = get_slicer_load_script(dicom_folder)
    with tempfile.NamedTemporaryFile(mode='w', suffix='.py', delete=False) as f:
        f.write(script_content)
        temp_script = f.name
    try:
        devnull = open(os.devnull, 'w')
        subprocess.Popen([SLICER_PATH, '--python-script', temp_script],
                        stdout=devnull, stderr=devnull)
        time.sleep(2)
        minimize_terminal()
        return True
    except Exception as e:
        print(f"  Error launching Slicer: {e}")
        return False

def wait_for_upload_complete(folder_path, stable_seconds=5):
    """Wait until no new files appear for stable_seconds"""
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
    spinner = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏']
    i = 0

    while stable_time < stable_seconds:
        time.sleep(0.5)
        current_count, current_size = count_files()

        if current_count == last_count and current_size == last_size:
            stable_time += 0.5
        else:
            stable_time = 0
            last_count, last_size = current_count, current_size

        print(f"\r  {spinner[i % len(spinner)]} Receiving files... ({last_count} files)", end='', flush=True)
        i += 1

    print(f"\r  ✓ Upload complete ({last_count} files)       ")

def process_folder(folder_path):
    global processed_folders
    if folder_path in processed_folders:
        return

    # Add IMMEDIATELY to prevent race condition
    processed_folders.add(folder_path)

    folder_name = os.path.basename(folder_path)
    print(f"  ┌─ New folder: {folder_name}")

    # Wait for upload to finish
    wait_for_upload_complete(folder_path, stable_seconds=5)

    print("  │ Scanning for DICOM files...")

    dcm_files = find_dicom_files(folder_path)

    if dcm_files:
        print(f"  │ Found {len(dcm_files)} DICOM files")
        print("  │ Launching 3D Slicer...")
        launch_slicer_with_dicom(folder_path)
        print("  └─ Loading all series into Slicer")
        print("")
    else:
        print("  └─ No DICOM files found")
        print("")

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

    print("  Waiting for uploads...")
    print("")

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
        print("\n  Stopped.")

    observer.join()
PYTHON_SCRIPT
