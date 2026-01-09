#!/bin/bash
# Copyright (c) 2025-2026 Mik Gangal
# Licensed under CC BY-NC-SA 4.0 - https://creativecommons.org/licenses/by-nc-sa/4.0/
set -e

echo "=== Starting 3D Slicer + nnInteractive Environment ==="

# Model weights are pre-downloaded to /root/.nninteractive_weights
# The server will find them when running from /root (default home directory)

# Configure SSH (optional)
echo "root:runpod" | chpasswd
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
service ssh start || true

# Configure VirtualGL
/opt/VirtualGL/bin/vglserver_config -config +s +f -t 2>/dev/null || true

# Configure Slicer settings (nnInteractive server URL and startup module)
SLICER_INI="/root/.config/slicer.org/Slicer.ini"
mkdir -p "$(dirname "$SLICER_INI")"
if [ ! -f "$SLICER_INI" ]; then
    cat > "$SLICER_INI" << 'SLICEREOF'
[Modules]
HomeModule=SlicerNNInteractive

[SlicerNNInteractive]
server=http://0.0.0.0:8000
SLICEREOF
else
    # Update existing settings
    if ! grep -q "^\[SlicerNNInteractive\]" "$SLICER_INI"; then
        echo -e "\n[SlicerNNInteractive]\nserver=http://0.0.0.0:8000" >> "$SLICER_INI"
    fi
    sed -i 's/^HomeModule=.*/HomeModule=SlicerNNInteractive/' "$SLICER_INI"
fi

# Clean up any stale VNC sessions
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null || true

# Start TurboVNC with software rendering for desktop
# (GPU apps use vglrun for hardware acceleration)
# TurboVNC is optimized for VirtualGL and provides best performance for 3D apps
export LIBGL_ALWAYS_SOFTWARE=1
export MESA_LOADER_DRIVER_OVERRIDE=swrast
export __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json
export GALLIUM_DRIVER=llvmpipe

RESOLUTION=${VNC_RESOLUTION:-1920x1080}
/opt/TurboVNC/bin/vncserver :1 -geometry $RESOLUTION -depth 24 -xstartup /root/.vnc/xstartup

# Start noVNC (browser-based VNC access via websockify)
# This proxies the TurboVNC session to port 6080 for browser access
websockify -D --web=/usr/share/novnc 6080 localhost:5901

echo ""
echo "=== Environment Ready ==="
echo ""
echo "TurboVNC:       port 5901 (password: vncpass)"
echo "                Direct TCP: Use RunPod's exposed TCP port"
echo "noVNC:          port 6080 (browser: auto-login via HTTP proxy)"
echo "SSH:            port 22 (root / runpod)"
echo "File Transfer:  port 8080 (start from desktop icon)"
echo "nnInteractive:  port 8000 (start from desktop icon)"
echo ""
echo "GPU: $(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || echo 'Not detected')"
echo ""
echo "For best performance, use TurboVNC client with direct TCP connection."
echo ""

# Keep container running
tail -f /dev/null
