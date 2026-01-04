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
    # SSH server (optional but useful)
    openssh-server \
    # Node.js and npm for Claude Code
    nodejs npm \
    # noVNC for browser-based VNC access
    novnc websockify \
    && rm -rf /var/lib/apt/lists/*

# ============================================
# STAGE 2: Install VirtualGL
# ============================================
RUN wget -q https://github.com/VirtualGL/virtualgl/releases/download/3.1.4/virtualgl_3.1.4_amd64.deb \
    -O /tmp/virtualgl.deb && \
    apt-get update && \
    dpkg -i /tmp/virtualgl.deb || apt-get install -f -y && \
    rm /tmp/virtualgl.deb && \
    rm -rf /var/lib/apt/lists/* && \
    test -x /opt/VirtualGL/bin/vglrun

# ============================================
# STAGE 2b: Install TurboVNC
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
RUN wget -q https://github.com/TurboVNC/turbovnc/releases/download/3.1.4/turbovnc_3.1.4_amd64.deb \
    -O /tmp/turbovnc.deb && \
    dpkg -i /tmp/turbovnc.deb && \
    rm /tmp/turbovnc.deb && \
    test -x /opt/TurboVNC/bin/vncserver

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
# STAGE 4b: Install Claude Code CLI
# ============================================
RUN npm install -g @anthropic-ai/claude-code

# ============================================
# STAGE 4c: Install File Browser
# ============================================
RUN curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash

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
# STAGE 4c3: Install lazygit
# ============================================
RUN LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*') && \
    curl -Lo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz" && \
    tar xf /tmp/lazygit.tar.gz -C /tmp lazygit && \
    install /tmp/lazygit /usr/local/bin && \
    rm /tmp/lazygit.tar.gz /tmp/lazygit

# ============================================
# STAGE 4d: Install Google Chrome and set as default browser
# ============================================
RUN wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    -O /tmp/chrome.deb && \
    apt-get update && \
    apt-get install -y /tmp/chrome.deb && \
    rm /tmp/chrome.deb && \
    rm -rf /var/lib/apt/lists/*

# Set Chrome as default browser (with Docker-compatible flags)
# Flags: --no-sandbox (required for root), --test-type (hides sandbox warning),
#        --no-default-browser-check, --disable-infobars (hide other warnings)
RUN echo '#!/bin/bash\nexec /usr/bin/google-chrome-stable --no-sandbox --no-default-browser-check --disable-infobars --test-type "$@"' \
    > /usr/local/bin/chrome-browser && chmod +x /usr/local/bin/chrome-browser

# Set as system default
RUN update-alternatives --install /usr/bin/x-www-browser x-www-browser /usr/local/bin/chrome-browser 300 && \
    update-alternatives --set x-www-browser /usr/local/bin/chrome-browser

# Configure XFCE to use Chrome with Docker-compatible flags
RUN mkdir -p /root/.config/xfce4 /root/.local/share/xfce4/helpers && \
    echo 'WebBrowser=custom-WebBrowser' > /root/.config/xfce4/helpers.rc && \
    cat > /root/.local/share/xfce4/helpers/custom-WebBrowser.desktop << 'EOF'
[Desktop Entry]
NoDisplay=true
Version=1.0
Encoding=UTF-8
Type=X-XFCE-Helper
X-XFCE-Category=WebBrowser
X-XFCE-CommandsWithParameter=/usr/bin/google-chrome-stable --no-sandbox --no-default-browser-check --disable-infobars --test-type "%s"
X-XFCE-Commands=/usr/bin/google-chrome-stable --no-sandbox --no-default-browser-check --disable-infobars --test-type
Name=Chrome
Icon=google-chrome
EOF

# Create desktop entry for xdg-settings default browser (used by gh auth and other CLI tools)
RUN cat > /usr/share/applications/chrome-root.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Name=Google Chrome (Root)
GenericName=Web Browser
Exec=/usr/local/bin/chrome-browser %U
Terminal=false
Icon=google-chrome
Type=Application
Categories=Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;
EOF

# Set Chrome as default for xdg-open (used by gh auth login --web)
RUN mkdir -p /root/.local/share/applications && \
    xdg-settings set default-web-browser chrome-root.desktop && \
    xdg-mime default chrome-root.desktop x-scheme-handler/http x-scheme-handler/https text/html

# ============================================
# STAGE 4e: Install Fiji (ImageJ)
# ============================================
# Fiji is a "batteries-included" distribution of ImageJ for scientific image analysis
RUN wget -q "https://downloads.imagej.net/fiji/latest/fiji-latest-linux64-jdk.zip" \
    -O /tmp/fiji.zip && \
    unzip -q /tmp/fiji.zip -d /opt && \
    mv /opt/Fiji /opt/fiji && \
    chmod +x /opt/fiji/fiji-linux-x64 && \
    rm /tmp/fiji.zip

# ============================================
# STAGE 4f: Install Blender
# ============================================
# Blender is a free and open-source 3D creation suite
RUN apt-get update && apt-get install -y --no-install-recommends librsvg2-bin xz-utils && \
    mkdir -p /opt/blender && \
    wget -q "https://download.blender.org/release/Blender5.0/blender-5.0.1-linux-x64.tar.xz" \
    -O /tmp/blender.tar.xz && \
    tar -xf /tmp/blender.tar.xz -C /opt/blender --strip-components=1 && \
    rsvg-convert -w 128 -h 128 /opt/blender/blender.svg -o /opt/blender/blender.png && \
    rm /tmp/blender.tar.xz && \
    rm -rf /var/lib/apt/lists/*

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
# STAGE 6: Install 3D Slicer 5.10.0
# ============================================
# Download from official Slicer website (stable release for Linux)
# Note: This URL redirects to the latest stable release
RUN mkdir -p /opt/slicer && \
    wget -q "https://download.slicer.org/download?os=linux&stability=release" \
    -O /tmp/slicer.tar.gz && \
    tar -xzf /tmp/slicer.tar.gz -C /opt/slicer --strip-components=1 && \
    rm /tmp/slicer.tar.gz

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
RUN echo '<!DOCTYPE html><html><head><meta http-equiv="refresh" content="0;url=vnc.html?password=vncpass&autoconnect=true"></head><body>Redirecting...</body></html>' > /usr/share/novnc/index.html

# VNC xstartup
COPY xstartup /root/.vnc/xstartup
RUN chmod +x /root/.vnc/xstartup

# Desktop shortcuts
RUN mkdir -p /root/Desktop

COPY slicer.desktop /root/Desktop/Slicer.desktop
COPY nninteractive.desktop /root/Desktop/nnInteractive.desktop
COPY filebrowser.desktop /root/Desktop/FileTransfer.desktop
COPY chrome.desktop /root/Desktop/Chrome.desktop
COPY fiji.desktop /root/Desktop/Fiji.desktop
COPY blender.desktop /root/Desktop/Blender.desktop
COPY github.desktop /root/Desktop/GitHub.desktop
RUN chmod +x /root/Desktop/*.desktop

# File Browser launcher script
COPY start-filebrowser /usr/local/bin/start-filebrowser
RUN chmod +x /usr/local/bin/start-filebrowser

# GitHub launcher script (handles auth, repo selection, and lazygit)
COPY github-launcher /usr/local/bin/github-launcher
RUN chmod +x /usr/local/bin/github-launcher

# Create /GITHUB directory for repositories
RUN mkdir -p /GITHUB

# Fix any Windows line endings (CRLF -> LF) in scripts
# This ensures scripts work even if edited on Windows
RUN sed -i 's/\r$//' /usr/local/bin/* /start.sh /root/.vnc/xstartup 2>/dev/null || true

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
# Environment variables
# ============================================
ENV DISPLAY=:1
ENV HOME=/root
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
