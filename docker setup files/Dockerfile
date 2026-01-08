# Base image with CUDA 12.8 runtime (matches PyTorch nightly cu128)
FROM nvidia/cuda:12.8.0-runtime-ubuntu24.04

LABEL maintainer="your-email@example.com"
LABEL description="3D Slicer + nnInteractive for medical image segmentation"

# Prevent interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Set up locale
RUN apt-get update && apt-get install -y locales && \
    locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# ============================================
# STAGE 1: System packages
# ============================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Basic utilities
    wget curl ca-certificates gnupg2 git unzip \
    # Python
    python3.12 python3.12-venv python3-pip \
    # Desktop environment
    xfce4 xfce4-goodies xfce4-terminal dbus-x11 \
    # X11 and display
    x11-xserver-utils xauth mesa-utils \
    # 3D Slicer dependencies
    libgl1 libglu1-mesa libxrender1 libxcursor1 libxft2 libxinerama1 \
    libxi6 libxrandr2 libxss1 libxtst6 libpulse0 libnss3 libxcomposite1 \
    libxdamage1 libxkbcommon0 libxkbcommon-x11-0 libasound2t64 libfontconfig1 \
    libdbus-1-3 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 libxcb-render-util0 \
    libxcb-xinerama0 libxcb-xkb1 libxcb-shape0 libopengl0 libegl1 libglx0 \
    libgomp1 libpcre2-16-0 \
    # GPU monitoring
    nvtop \
    # Window management for scripts
    wmctrl xdotool \
    # SSH server (optional but useful)
    openssh-server \
    # noVNC for browser-based VNC access
    novnc websockify \
    && rm -rf /var/lib/apt/lists/*

# ============================================
# STAGE 2: Install VirtualGL (with retry)
# ============================================
RUN for i in 1 2 3; do \
        echo "Attempt $i: Installing VirtualGL..." && \
        rm -f /tmp/virtualgl.deb && \
        wget -q https://github.com/VirtualGL/virtualgl/releases/download/3.1.4/virtualgl_3.1.4_amd64.deb \
            -O /tmp/virtualgl.deb && \
        apt-get update && \
        dpkg -i /tmp/virtualgl.deb || apt-get install -f -y && \
        rm /tmp/virtualgl.deb && \
        rm -rf /var/lib/apt/lists/* && \
        /opt/VirtualGL/bin/vglrun --help > /dev/null 2>&1 && \
        echo "VirtualGL installation verified" && \
        break || \
        { echo "Attempt $i failed, retrying..."; rm -f /tmp/virtualgl.deb; sleep 2; }; \
    done && test -x /opt/VirtualGL/bin/vglrun

# ============================================
# STAGE 2b: Install TurboVNC (with retry)
# ============================================
# TurboVNC is optimized for VirtualGL workflows and provides the best performance
# for remote 3D visualization. It's specifically designed for high-performance
# remote display of 3D applications.
#
# Why TurboVNC over alternatives:
# - TigerVNC: Basic VNC, no optimizations for 3D/VirtualGL workflows
# - KasmVNC: Good browser experience but CPU-only encoding, no GPU acceleration
# - Selkies-GStreamer: GPU encoding via NVENC but requires WebRTC/UDP which
#   doesn't work through RunPod's HTTP proxy
#
# TurboVNC + noVNC provides:
# - Best native client performance (TurboVNC client on port 5901)
# - Browser fallback via noVNC (same desktop session on port 6080)
RUN for i in 1 2 3; do \
        echo "Attempt $i: Installing TurboVNC..." && \
        rm -f /tmp/turbovnc.deb && \
        wget -q https://github.com/TurboVNC/turbovnc/releases/download/3.1.4/turbovnc_3.1.4_amd64.deb \
            -O /tmp/turbovnc.deb && \
        dpkg -i /tmp/turbovnc.deb && \
        rm /tmp/turbovnc.deb && \
        /opt/TurboVNC/bin/vncserver -help 2>&1 | head -1 && \
        echo "TurboVNC installation verified" && \
        break || \
        { echo "Attempt $i failed, retrying..."; rm -f /tmp/turbovnc.deb; sleep 2; }; \
    done && test -x /opt/TurboVNC/bin/vncserver

# ============================================
# STAGE 3: Install uv (Python package manager)
# ============================================
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

# ============================================
# STAGE 4: Install nnInteractive with PyTorch nightly
# ============================================
ENV UV_TOOL_DIR=/opt/uv-tools
ENV UV_TOOL_BIN_DIR=/opt/uv-tools/bin

# Install nninteractive-slicer-server (may pull stable PyTorch initially)
RUN uv tool install nninteractive-slicer-server \
    --extra-index-url https://download.pytorch.org/whl/nightly/cu128 \
    --index-strategy unsafe-best-match \
    --prerelease allow

# CRITICAL: Explicitly upgrade PyTorch to nightly cu128 for Blackwell (sm_120) support
# The uv tool install above may resolve to stable PyTorch which only supports up to sm_90.
# This explicit upgrade ensures we get nightly builds with sm_100/sm_120 support.
RUN uv pip install \
    --python /opt/uv-tools/nninteractive-slicer-server/bin/python \
    --upgrade --pre \
    torch torchvision \
    --index-url https://download.pytorch.org/whl/nightly/cu128

# Add to PATH
ENV PATH="/opt/uv-tools/bin:$PATH"

# ============================================
# STAGE 4a2: Install DICOM utilities for T2 auto-loader script
# ============================================
# pydicom: Read DICOM metadata (SeriesDescription, ProtocolName) to identify T2 sequences
# watchdog: Monitor folders for new DICOM studies and auto-load into Slicer
RUN pip install --break-system-packages pydicom watchdog

# ============================================
# STAGE 4b: Install Node.js 22 and Claude Code CLI
# ============================================
# Ubuntu's default nodejs (v18) has ES module issues with Claude Code
# Install Node.js 22 from NodeSource for proper ES module support
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/* && \
    node --version && \
    echo "Node.js installation verified"

RUN npm install -g @anthropic-ai/claude-code && \
    claude --version && \
    echo "Claude Code installation verified"

# ============================================
# STAGE 4c: Install File Browser (direct download - more reliable on Windows Docker)
# ============================================
# NOTE: Avoid "curl | bash" patterns - they're unreliable when building on Windows
RUN for i in 1 2 3; do \
        echo "Attempt $i: Installing File Browser..." && \
        rm -f /usr/local/bin/filebrowser /tmp/fb.tar.gz && \
        FB_VERSION=$(curl -s https://api.github.com/repos/filebrowser/filebrowser/releases/latest | grep -Po '"tag_name": "v\K[^"]*') && \
        echo "Downloading File Browser v${FB_VERSION}..." && \
        curl -fsSL "https://github.com/filebrowser/filebrowser/releases/download/v${FB_VERSION}/linux-amd64-filebrowser.tar.gz" -o /tmp/fb.tar.gz && \
        tar -xzf /tmp/fb.tar.gz -C /usr/local/bin filebrowser && \
        rm -f /tmp/fb.tar.gz && \
        chmod +x /usr/local/bin/filebrowser && \
        filebrowser version && \
        echo "File Browser installation verified" && \
        break || \
        { echo "Attempt $i failed, cleaning up and retrying..."; rm -f /usr/local/bin/filebrowser /tmp/fb.tar.gz; sleep 3; }; \
    done && filebrowser version

# ============================================
# STAGE 4c2: Install GitHub CLI
# ============================================
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    -o /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    > /etc/apt/sources.list.d/github-cli.list && \
    apt-get update && apt-get install -y gh && \
    rm -rf /var/lib/apt/lists/*

# ============================================
# STAGE 4c3: Install lazygit (with retry)
# ============================================
RUN for i in 1 2 3; do \
        echo "Attempt $i: Installing lazygit..." && \
        LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*') && \
        curl -Lo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz" && \
        tar xf /tmp/lazygit.tar.gz -C /tmp lazygit && \
        install /tmp/lazygit /usr/local/bin && \
        rm -f /tmp/lazygit.tar.gz /tmp/lazygit && \
        lazygit --version && \
        echo "lazygit installation verified" && \
        break || \
        { echo "Attempt $i failed, cleaning up and retrying..."; rm -f /tmp/lazygit.tar.gz /tmp/lazygit /usr/local/bin/lazygit; sleep 2; }; \
    done && lazygit --version

# ============================================
# STAGE 4d: Install Firefox (direct from Mozilla, not snap, with retry)
# ============================================
# Ubuntu 24.04 only has Firefox as a snap which doesn't work in Docker
# Download directly from Mozilla instead
RUN apt-get update && apt-get install -y bzip2 xz-utils && rm -rf /var/lib/apt/lists/*
RUN for i in 1 2 3; do \
        echo "Attempt $i: Installing Firefox..." && \
        curl -fsSL "https://download.mozilla.org/?product=firefox-latest-ssl&os=linux64&lang=en-US" -o /tmp/firefox.tar.xz && \
        tar -xJf /tmp/firefox.tar.xz -C /opt && \
        rm -f /tmp/firefox.tar.xz && \
        ln -sf /opt/firefox/firefox /usr/local/bin/firefox && \
        mkdir -p /opt/firefox/distribution && \
        firefox --version && \
        echo "Firefox installation verified" && \
        break || \
        { echo "Attempt $i failed, cleaning up and retrying..."; rm -rf /tmp/firefox.tar.xz /opt/firefox; sleep 2; }; \
    done && firefox --version

# Skip Firefox first-run setup screens
COPY firefox-policies.json /opt/firefox/distribution/policies.json

# Set Firefox as default browser for xdg-open, gh auth, claude auth, etc.
COPY firefox.desktop /usr/share/applications/firefox.desktop
RUN update-desktop-database /usr/share/applications 2>/dev/null || true && \
    mkdir -p /root/.config && \
    cat > /root/.config/mimeapps.list << 'EOF'
[Default Applications]
text/html=firefox.desktop
x-scheme-handler/http=firefox.desktop
x-scheme-handler/https=firefox.desktop
x-scheme-handler/about=firefox.desktop
x-scheme-handler/unknown=firefox.desktop
application/xhtml+xml=firefox.desktop

[Added Associations]
text/html=firefox.desktop
x-scheme-handler/http=firefox.desktop
x-scheme-handler/https=firefox.desktop
EOF

# ============================================
# STAGE 4e: Install Fiji (ImageJ) (with retry)
# ============================================
# Fiji is a "batteries-included" distribution of ImageJ for scientific image analysis
RUN for i in 1 2 3; do \
        echo "Attempt $i: Installing Fiji..." && \
        rm -rf /tmp/fiji.zip /opt/fiji /opt/Fiji && \
        wget -q "https://downloads.imagej.net/fiji/latest/fiji-latest-linux64-jdk.zip" \
            -O /tmp/fiji.zip && \
        unzip -q /tmp/fiji.zip -d /opt && \
        mv /opt/Fiji /opt/fiji && \
        chmod +x /opt/fiji/fiji-linux-x64 && \
        rm /tmp/fiji.zip && \
        /opt/fiji/fiji-linux-x64 --headless --help 2>&1 | head -1 && \
        echo "Fiji installation verified" && \
        break || \
        { echo "Attempt $i failed, cleaning up and retrying..."; rm -rf /tmp/fiji.zip /opt/fiji /opt/Fiji; sleep 3; }; \
    done && test -x /opt/fiji/fiji-linux-x64

# ============================================
# STAGE 4f: Install Blender (with retry)
# ============================================
# Blender is a free and open-source 3D creation suite
RUN apt-get update && apt-get install -y --no-install-recommends librsvg2-bin xz-utils && \
    rm -rf /var/lib/apt/lists/*
RUN for i in 1 2 3; do \
        echo "Attempt $i: Installing Blender..." && \
        rm -rf /tmp/blender.tar.xz /opt/blender && \
        mkdir -p /opt/blender && \
        wget -q "https://download.blender.org/release/Blender5.0/blender-5.0.1-linux-x64.tar.xz" \
            -O /tmp/blender.tar.xz && \
        tar -xf /tmp/blender.tar.xz -C /opt/blender --strip-components=1 && \
        rsvg-convert -w 128 -h 128 /opt/blender/blender.svg -o /opt/blender/blender.png && \
        rm /tmp/blender.tar.xz && \
        /opt/blender/blender --version && \
        echo "Blender installation verified" && \
        break || \
        { echo "Attempt $i failed, cleaning up and retrying..."; rm -rf /tmp/blender.tar.xz /opt/blender; sleep 3; }; \
    done && test -x /opt/blender/blender

# ============================================
# STAGE 5: Download model weights
# ============================================
# The server looks for weights at .nninteractive_weights/nnInteractive_v1.0 relative to cwd
# We download to /root/.nninteractive_weights so it works when running from /root
RUN mkdir -p /root/.nninteractive_weights && \
    /opt/uv-tools/nninteractive-slicer-server/bin/python -c "\
from huggingface_hub import snapshot_download; \
snapshot_download('nnInteractive/nnInteractive', \
    local_dir='/root/.nninteractive_weights/nnInteractive_v1.0', \
    local_dir_use_symlinks=False)"

# ============================================
# STAGE 6: Install 3D Slicer 5.10.0 (with retry)
# ============================================
# Download from official Slicer website (stable release for Linux)
# Note: This URL redirects to the latest stable release
RUN for i in 1 2 3; do \
        echo "Attempt $i: Installing 3D Slicer..." && \
        rm -rf /tmp/slicer.tar.gz /opt/slicer && \
        mkdir -p /opt/slicer && \
        wget -q "https://download.slicer.org/download?os=linux&stability=release" \
            -O /tmp/slicer.tar.gz && \
        tar -xzf /tmp/slicer.tar.gz -C /opt/slicer --strip-components=1 && \
        rm /tmp/slicer.tar.gz && \
        test -x /opt/slicer/Slicer && \
        echo "3D Slicer installation verified" && \
        break || \
        { echo "Attempt $i failed, cleaning up and retrying..."; rm -rf /tmp/slicer.tar.gz /opt/slicer; sleep 3; }; \
    done && test -x /opt/slicer/Slicer

# ============================================
# STAGE 7: Install NNInteractive Slicer Extension
# ============================================
# Download from official GitHub repository: https://github.com/coendevente/SlicerNNInteractive
RUN mkdir -p /opt/slicer-extensions && \
    wget -q https://github.com/coendevente/SlicerNNInteractive/archive/refs/heads/main.zip \
    -O /tmp/nninteractive-ext.zip && \
    unzip -q /tmp/nninteractive-ext.zip -d /opt/slicer-extensions && \
    rm /tmp/nninteractive-ext.zip

# ============================================
# STAGE 8: Install nnInteractive module into Slicer
# ============================================
# Copy the module .py file to the scripted modules directory (must be at top level)
# Also copy the module's Resources (Icons and UI) to Slicer's Resources folder
RUN cp /opt/slicer-extensions/SlicerNNInteractive-main/slicer_plugin/SlicerNNInteractive/SlicerNNInteractive.py \
    /opt/slicer/lib/Slicer-5.10/qt-scripted-modules/ && \
    cp -r /opt/slicer-extensions/SlicerNNInteractive-main/slicer_plugin/SlicerNNInteractive/Resources/Icons/* \
    /opt/slicer/lib/Slicer-5.10/qt-scripted-modules/Resources/Icons/ && \
    cp /opt/slicer-extensions/SlicerNNInteractive-main/slicer_plugin/SlicerNNInteractive/Resources/UI/SlicerNNInteractive.ui \
    /opt/slicer/lib/Slicer-5.10/qt-scripted-modules/Resources/UI/

# ============================================
# STAGE 9: Create wrapper scripts
# ============================================

# Slicer launcher with GPU acceleration (falls back to software rendering if VirtualGL unavailable)
RUN cat > /usr/local/bin/Slicer << 'EOF' && chmod +x /usr/local/bin/Slicer
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

# nnInteractive server launcher
RUN echo '#!/bin/bash\nexec nninteractive-slicer-server "$@"' \
    > /usr/local/bin/start-nninteractive && chmod +x /usr/local/bin/start-nninteractive

# Blender launcher with GPU acceleration (falls back to software rendering if VirtualGL unavailable)
RUN cat > /usr/local/bin/Blender << 'EOF' && chmod +x /usr/local/bin/Blender
#!/bin/bash
if [ -x /opt/VirtualGL/bin/vglrun ]; then
    # Use VirtualGL for GPU acceleration
    export __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/10_nvidia.json
    export __GLX_VENDOR_LIBRARY_NAME=nvidia
    export VGL_DISPLAY=egl
    exec /opt/VirtualGL/bin/vglrun -d egl /opt/blender/blender "$@"
else
    # Fallback: run without VirtualGL
    exec /opt/blender/blender "$@"
fi
EOF

# Fiji launcher with GPU acceleration (for 3D Viewer plugin)
RUN cat > /usr/local/bin/Fiji << 'EOF' && chmod +x /usr/local/bin/Fiji
#!/bin/bash
if [ -x /opt/VirtualGL/bin/vglrun ]; then
    # Use VirtualGL for GPU acceleration
    export __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/10_nvidia.json
    export __GLX_VENDOR_LIBRARY_NAME=nvidia
    export VGL_DISPLAY=egl
    exec /opt/VirtualGL/bin/vglrun -d egl /opt/fiji/fiji-linux-x64 "$@"
else
    # Fallback: run without VirtualGL
    exec /opt/fiji/fiji-linux-x64 "$@"
fi
EOF

# ============================================
# STAGE 10: VNC and desktop configuration
# ============================================

# Create VNC password file for TurboVNC (password: vncpass)
RUN mkdir -p /root/.vnc && \
    printf 'vncpass\nvncpass\nn\n' | /opt/TurboVNC/bin/vncpasswd /root/.vnc/passwd && \
    chmod 600 /root/.vnc/passwd

# noVNC auto-redirect with password (for RunPod HTTP proxy)
# This allows browser access via the RunPod proxy URL with auto-login
# noVNC settings:
#   resize=remote    - VNC server adjusts resolution to match browser window
#   reconnect=true   - Auto-reconnect on connection drop
#   reconnect_delay  - Wait 1s before reconnect attempt
#   quality=6        - JPEG quality 0-9 (6 = good balance)
#   compression=2    - Compression 0-9 (2 = light, preserves quality)
#   show_dot=true    - Show local cursor dot (helps with latency)
#   bell=false       - Disable audible bell
RUN cat > /usr/share/novnc/index.html << 'NOVNC_EOF'
<!DOCTYPE html>
<html>
<head>
<script>
localStorage.setItem('noVNC_setting_language', 'en');
window.location.href = 'vnc.html?password=vncpass&autoconnect=true&resize=remote&reconnect=true&reconnect_delay=1000&quality=6&compression=2&show_dot=true&bell=false';
</script>
</head>
<body>Redirecting...</body>
</html>
NOVNC_EOF

# VNC xstartup
COPY xstartup /root/.vnc/xstartup
RUN chmod +x /root/.vnc/xstartup

# Desktop shortcuts - Main apps on desktop, tools in Tools folder
RUN mkdir -p /root/Desktop/Tools

# Main workflow apps on desktop
COPY slicer.desktop /root/Desktop/Slicer.desktop
COPY nninteractive.desktop /root/Desktop/nnInteractive.desktop

# Tools folder
COPY firefox.desktop /root/Desktop/Tools/Firefox.desktop
COPY github.desktop /root/Desktop/Tools/GitHub.desktop
COPY fiji.desktop /root/Desktop/Tools/Fiji.desktop
COPY blender.desktop /root/Desktop/Tools/Blender.desktop
COPY DicomWatcher/filebrowser.desktop /root/Desktop/Tools/FileTransfer.desktop
COPY nvtop.desktop /root/Desktop/Tools/nvtop.desktop
COPY claude.desktop /root/Desktop/Tools/Claude.desktop

# Hybrid File Transfer + T2 Watcher script (combines filebrowser + T2 auto-loader)
COPY DicomWatcher/start-file-watcher.sh /root/Desktop/Tools/start-file-watcher
RUN chmod +x /root/Desktop/Tools/start-file-watcher

# XFCE autostart: Launch file watcher when VNC desktop session starts
# (not at container boot - only when user connects to VNC)
RUN mkdir -p /root/.config/autostart
COPY DicomWatcher/file-watcher.desktop /root/.config/autostart/file-watcher.desktop

RUN chmod +x /root/Desktop/*.desktop /root/Desktop/Tools/*.desktop

# Hide default desktop icons (home, filesystem, trash)
RUN mkdir -p /root/.config/xfce4/xfconf/xfce-perchannel-xml && \
    cat > /root/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="desktop-icons" type="empty">
    <property name="file-icons" type="empty">
      <property name="show-home" type="bool" value="false"/>
      <property name="show-filesystem" type="bool" value="false"/>
      <property name="show-trash" type="bool" value="false"/>
      <property name="show-removable" type="bool" value="false"/>
    </property>
  </property>
</channel>
EOF

# NOTE: start-filebrowser is replaced by start-file-watcher (hybrid script)
# which combines file browser + T2 DICOM auto-loader

# GitHub launcher script (handles auth, repo selection, and lazygit)
COPY github-launcher /usr/local/bin/github-launcher
RUN chmod +x /usr/local/bin/github-launcher

# Create /GITHUB directory for repositories
RUN mkdir -p /GITHUB

# Configure git with noreply email by default
RUN git config --global user.email "user@users.noreply.github.com" && \
    git config --global user.name "user" && \
    git config --global init.defaultBranch main

# ============================================
# STAGE 11: Startup script
# ============================================
COPY start.sh /start.sh
RUN chmod +x /start.sh

# ============================================
# STAGE 12: Fix Windows line endings and verify binaries
# ============================================
# CRITICAL: This must run AFTER all files are copied
# Fixes CRLF -> LF for all scripts (Windows Docker build issue)
RUN sed -i 's/\r$//' /usr/local/bin/* /start.sh /root/.vnc/xstartup \
    /root/Desktop/*.desktop /root/Desktop/Tools/*.desktop /root/Desktop/Tools/start-file-watcher \
    /root/.config/autostart/*.desktop 2>/dev/null || true

# Verify all critical binaries are working (not just existing)
# This catches corruption that can occur when building on Windows
RUN echo "Verifying critical binaries..." && \
    filebrowser version && \
    lazygit --version && \
    firefox --version && \
    /opt/slicer/Slicer --version 2>/dev/null || true && \
    /opt/fiji/fiji-linux-x64 --help 2>/dev/null | head -1 || true && \
    /opt/blender/blender --version && \
    /opt/VirtualGL/bin/vglrun -d egl /bin/true && \
    /opt/TurboVNC/bin/vncserver -help 2>&1 | head -1 && \
    echo "All binary verifications passed"

# ============================================
# Environment variables
# ============================================
ENV DISPLAY=:1
ENV HOME=/root
ENV BROWSER=/opt/firefox/firefox
WORKDIR /root

# ============================================
# Expose ports
# ============================================
EXPOSE 5901
EXPOSE 6080
EXPOSE 8000
EXPOSE 8080
EXPOSE 22

# ============================================
# Entrypoint
# ============================================
CMD ["/start.sh"]
