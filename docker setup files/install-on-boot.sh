#!/bin/bash
#
# install-on-boot.sh - Downloads and installs 3D Slicer and nnInteractive model weights on first boot
#
# This script runs in the background when the container starts. It:
# 1. Downloads 3D Slicer if not already installed
# 2. Installs the nnInteractive Slicer extension
# 3. Downloads nnInteractive model weights if not present
# 4. Creates the GPU-accelerated wrapper script
#
# Progress is logged to /var/log/slicer-install.log
# When complete, creates /var/run/slicer-install.done marker file
#
# The xstartup script checks for these to show progress on VNC connect.
#

LOG_FILE="/var/log/slicer-install.log"
DONE_MARKER="/var/run/slicer-install.done"
LOCK_FILE="/var/run/slicer-install.lock"

SLICER_DIR="/opt/slicer"
SLICER_BIN="$SLICER_DIR/Slicer"
WEIGHTS_DIR="/root/.nninteractive_weights/nnInteractive_v1.0"
EXTENSION_DIR="/opt/slicer-extensions"

# Redirect all output to log file
exec > >(tee -a "$LOG_FILE") 2>&1

# Check if already running (prevent duplicate runs)
if [ -f "$LOCK_FILE" ]; then
    echo "[$(date)] Another install process is already running. Exiting."
    exit 0
fi

# Check if already complete
if [ -f "$DONE_MARKER" ]; then
    echo "[$(date)] Installation already complete. Exiting."
    exit 0
fi

# Create lock file
touch "$LOCK_FILE"
trap "rm -f $LOCK_FILE" EXIT

echo ""
echo "========================================================"
echo "  3D Slicer + nnInteractive Background Installation"
echo "  Started: $(date)"
echo "========================================================"
echo ""

# Track if we need to do anything
INSTALL_NEEDED=false

# -----------------------------------------------------
# STEP 1: Install 3D Slicer
# -----------------------------------------------------
if [ ! -x "$SLICER_BIN" ]; then
    INSTALL_NEEDED=true
    echo "[$(date)] STEP 1/4: Downloading 3D Slicer..."
    echo ""

    mkdir -p "$SLICER_DIR"

    wget -q --show-progress "https://download.slicer.org/download?os=linux&stability=release" \
        -O /tmp/slicer.tar.gz

    if [ $? -ne 0 ]; then
        echo "[$(date)] ERROR: Failed to download 3D Slicer"
        rm -f "$LOCK_FILE"
        exit 1
    fi

    echo "[$(date)] Extracting 3D Slicer..."
    tar -xzf /tmp/slicer.tar.gz -C "$SLICER_DIR" --strip-components=1
    rm /tmp/slicer.tar.gz

    echo "[$(date)] 3D Slicer installed successfully"
    echo ""
else
    echo "[$(date)] STEP 1/4: 3D Slicer already installed, skipping"
    echo ""
fi

# -----------------------------------------------------
# STEP 2: Install nnInteractive Slicer Extension
# -----------------------------------------------------
EXTENSION_PY="$SLICER_DIR/lib/Slicer-5.10/qt-scripted-modules/SlicerNNInteractive.py"

if [ ! -f "$EXTENSION_PY" ]; then
    INSTALL_NEEDED=true
    echo "[$(date)] STEP 2/4: Installing nnInteractive Slicer extension..."
    echo ""

    mkdir -p "$EXTENSION_DIR"

    wget -q --show-progress "https://github.com/coendevente/SlicerNNInteractive/archive/refs/heads/main.zip" \
        -O /tmp/nninteractive-ext.zip

    if [ $? -ne 0 ]; then
        echo "[$(date)] ERROR: Failed to download nnInteractive extension"
        rm -f "$LOCK_FILE"
        exit 1
    fi

    unzip -q /tmp/nninteractive-ext.zip -d "$EXTENSION_DIR"
    rm /tmp/nninteractive-ext.zip

    # Copy module files to Slicer
    cp "$EXTENSION_DIR/SlicerNNInteractive-main/slicer_plugin/SlicerNNInteractive/SlicerNNInteractive.py" \
        "$SLICER_DIR/lib/Slicer-5.10/qt-scripted-modules/"

    cp -r "$EXTENSION_DIR/SlicerNNInteractive-main/slicer_plugin/SlicerNNInteractive/Resources/Icons/"* \
        "$SLICER_DIR/lib/Slicer-5.10/qt-scripted-modules/Resources/Icons/"

    cp "$EXTENSION_DIR/SlicerNNInteractive-main/slicer_plugin/SlicerNNInteractive/Resources/UI/SlicerNNInteractive.ui" \
        "$SLICER_DIR/lib/Slicer-5.10/qt-scripted-modules/Resources/UI/"

    echo "[$(date)] nnInteractive extension installed successfully"
    echo ""
else
    echo "[$(date)] STEP 2/4: nnInteractive extension already installed, skipping"
    echo ""
fi

# -----------------------------------------------------
# STEP 3: Download nnInteractive Model Weights
# -----------------------------------------------------
if [ ! -d "$WEIGHTS_DIR" ] || [ -z "$(ls -A $WEIGHTS_DIR 2>/dev/null)" ]; then
    INSTALL_NEEDED=true
    echo "[$(date)] STEP 3/4: Downloading nnInteractive model weights..."
    echo "           This may take several minutes (~1GB download)"
    echo ""

    mkdir -p /root/.nninteractive_weights

    # Use the nninteractive Python environment to download weights
    /opt/uv-tools/nninteractive-slicer-server/bin/python -c "
from huggingface_hub import snapshot_download
print('Downloading from Hugging Face...')
snapshot_download('nnInteractive/nnInteractive',
    local_dir='/root/.nninteractive_weights/nnInteractive_v1.0',
    local_dir_use_symlinks=False)
print('Download complete!')
"

    if [ $? -ne 0 ]; then
        echo "[$(date)] ERROR: Failed to download model weights"
        rm -f "$LOCK_FILE"
        exit 1
    fi

    echo "[$(date)] Model weights downloaded successfully"
    echo ""
else
    echo "[$(date)] STEP 3/4: Model weights already present, skipping"
    echo ""
fi

# -----------------------------------------------------
# STEP 4: Create GPU-accelerated Slicer wrapper
# -----------------------------------------------------
SLICER_WRAPPER="/usr/local/bin/Slicer"

if [ ! -x "$SLICER_WRAPPER" ]; then
    INSTALL_NEEDED=true
    echo "[$(date)] STEP 4/4: Creating GPU-accelerated Slicer launcher..."

    cat > "$SLICER_WRAPPER" << 'EOF'
#!/bin/bash
if [ -x /opt/VirtualGL/bin/vglrun ]; then
    # Use VirtualGL for GPU acceleration
    export __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/10_nvidia.json
    export __GLX_VENDOR_LIBRARY_NAME=nvidia
    export VGL_DISPLAY=egl
    exec /opt/VirtualGL/bin/vglrun -d egl /opt/slicer/Slicer "$@"
else
    # Fallback: run without VirtualGL
    exec /opt/slicer/Slicer "$@"
fi
EOF
    chmod +x "$SLICER_WRAPPER"

    echo "[$(date)] Slicer launcher created successfully"
    echo ""
else
    echo "[$(date)] STEP 4/4: Slicer launcher already exists, skipping"
    echo ""
fi

# -----------------------------------------------------
# Complete
# -----------------------------------------------------
echo "========================================================"
echo "  Installation Complete!"
echo "  Finished: $(date)"
echo "========================================================"
echo ""
echo "  You can now use:"
echo "  - 3D Slicer (desktop shortcut or /usr/local/bin/Slicer)"
echo "  - nnInteractive Server (desktop shortcut)"
echo ""
echo "  Optional installs available via desktop shortcuts:"
echo "  - Fiji (ImageJ)"
echo "  - Blender"
echo ""
echo "========================================================"

# Create done marker
touch "$DONE_MARKER"

# Remove lock file (trap will also do this)
rm -f "$LOCK_FILE"

exit 0
