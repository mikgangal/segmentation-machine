#!/bin/bash
# Copyright (c) 2025-2026 Mik Gangal
# Licensed under CC BY-NC-SA 4.0 - https://creativecommons.org/licenses/by-nc-sa/4.0/
#
# Print 3D Models - Slicer launcher with on-demand download
# Downloads slicer software as needed and loads exported OBJ files

EXPORT_BASE="/FILE TRANSFERS"
SLICER_CACHE="/workspace/.slicers"

# ============================================
# Slicer definitions
# ============================================

declare -A SLICER_NAMES=(
    [1]="OrcaSlicer"
    [2]="PrusaSlicer"
    [3]="Cura"
)

declare -A SLICER_DIRS=(
    [1]="orcaslicer"
    [2]="prusaslicer"
    [3]="cura"
)

# Cloud printing service names
declare -A CLOUD_NAMES=(
    [1]="Bambu Lab"
    [2]="PrusaConnect"
    [3]="UltiMaker Digital Factory"
)

# Cloud login instructions
declare -A CLOUD_LOGIN=(
    [1]="Log in to your Bambu account (top-right menu)"
    [2]="Log in to PrusaConnect (Configuration → Prusa Account)"
    [3]="Sign in to UltiMaker account (top-right)"
)

# Cloud send instructions
declare -A CLOUD_SEND=(
    [1]="Click \"Print\" to send directly to your printer"
    [2]="Click \"Send to printer\" after slicing"
    [3]="Select your cloud printer and click \"Print over cloud\""
)

# ============================================
# Helper functions
# ============================================

get_latest_version_orcaslicer() {
    curl -sL "https://api.github.com/repos/SoftFever/OrcaSlicer/releases/latest" | grep -Po '"tag_name": "v?\K[^"]*'
}

get_latest_version_prusaslicer() {
    # Using community-maintained AppImage repo (official stopped at 2.8.1)
    curl -sL "https://api.github.com/repos/probonopd/PrusaSlicer.AppImage/releases/latest" | grep -Po '"tag_name": "\K[^"]*'
}

get_latest_version_cura() {
    curl -sL "https://api.github.com/repos/Ultimaker/Cura/releases/latest" | grep -Po '"tag_name": "\K[^"]*'
}


download_slicer() {
    local choice=$1
    local cache_dir="${SLICER_CACHE}/${SLICER_DIRS[$choice]}"
    mkdir -p "$cache_dir"

    case $choice in
        1) # OrcaSlicer
            local version=$(get_latest_version_orcaslicer)
            if [ -z "$version" ]; then
                echo "  ✗ Failed to fetch OrcaSlicer version"
                return 1
            fi
            # Get actual download URL from API (filename varies by release)
            local asset_url=$(curl -sL "https://api.github.com/repos/SoftFever/OrcaSlicer/releases/latest" | grep -o '"browser_download_url": "[^"]*AppImage[^"]*"' | grep -i ubuntu | head -1 | cut -d'"' -f4)
            if [ -z "$asset_url" ]; then
                echo "  ✗ Failed to find OrcaSlicer download URL"
                return 1
            fi
            local appimage="${cache_dir}/OrcaSlicer.AppImage"
            echo "  ⠋ Downloading OrcaSlicer v${version}..."
            if curl -L --progress-bar "$asset_url" -o "$appimage" && [ -s "$appimage" ] && [ $(stat -c%s "$appimage") -gt 1000000 ]; then
                chmod +x "$appimage"
                echo "  ⠋ Extracting AppImage (this may take 30-60 seconds)..."
                cd "$cache_dir" && "$appimage" --appimage-extract > /dev/null 2>&1
                if [ -x "${cache_dir}/squashfs-root/AppRun" ]; then
                    rm -f "$appimage"  # Remove AppImage to save space
                    echo "$version" > "${cache_dir}/version.txt"
                    echo "  ✓ Downloaded and extracted OrcaSlicer v${version}"
                    return 0
                fi
            fi
            ;;
        2) # PrusaSlicer
            local version=$(get_latest_version_prusaslicer)
            if [ -z "$version" ]; then
                echo "  ✗ Failed to fetch PrusaSlicer version"
                return 1
            fi
            # Using community-maintained AppImage repo (official stopped at 2.8.1)
            local asset_url=$(curl -sL "https://api.github.com/repos/probonopd/PrusaSlicer.AppImage/releases/latest" | grep -o '"browser_download_url": "[^"]*\.AppImage"' | grep -v zsync | head -1 | cut -d'"' -f4)
            if [ -z "$asset_url" ]; then
                echo "  ✗ Failed to find PrusaSlicer download URL"
                return 1
            fi
            local appimage="${cache_dir}/PrusaSlicer.AppImage"
            echo "  ⠋ Downloading PrusaSlicer v${version}..."
            if curl -L --progress-bar "$asset_url" -o "$appimage" && [ -s "$appimage" ] && [ $(stat -c%s "$appimage") -gt 1000000 ]; then
                chmod +x "$appimage"
                echo "  ⠋ Extracting AppImage (this may take 30-60 seconds)..."
                cd "$cache_dir" && "$appimage" --appimage-extract > /dev/null 2>&1
                if [ -x "${cache_dir}/squashfs-root/AppRun" ]; then
                    rm -f "$appimage"
                    echo "$version" > "${cache_dir}/version.txt"
                    echo "  ✓ Downloaded and extracted PrusaSlicer v${version}"
                    return 0
                fi
            fi
            ;;
        3) # Cura
            local version=$(get_latest_version_cura)
            if [ -z "$version" ]; then
                echo "  ✗ Failed to fetch Cura version"
                return 1
            fi
            local asset_url=$(curl -sL "https://api.github.com/repos/Ultimaker/Cura/releases/latest" | grep -o '"browser_download_url": "[^"]*linux-X64\.AppImage"' | head -1 | cut -d'"' -f4)
            if [ -z "$asset_url" ]; then
                echo "  ✗ Failed to find Cura download URL"
                return 1
            fi
            local appimage="${cache_dir}/Cura.AppImage"
            echo "  ⠋ Downloading Cura v${version}..."
            if curl -L --progress-bar "$asset_url" -o "$appimage" && [ -s "$appimage" ] && [ $(stat -c%s "$appimage") -gt 1000000 ]; then
                chmod +x "$appimage"
                echo "  ⠋ Extracting AppImage (this may take 30-60 seconds)..."
                cd "$cache_dir" && "$appimage" --appimage-extract > /dev/null 2>&1
                if [ -x "${cache_dir}/squashfs-root/AppRun" ]; then
                    rm -f "$appimage"
                    echo "$version" > "${cache_dir}/version.txt"
                    echo "  ✓ Downloaded and extracted Cura v${version}"
                    return 0
                fi
            fi
            ;;
    esac

    echo "  ✗ Download failed"
    return 1
}

get_executable_path() {
    local choice=$1
    local cache_dir="${SLICER_CACHE}/${SLICER_DIRS[$choice]}"

    # Return path to the extracted executable
    case $choice in
        1) echo "${cache_dir}/squashfs-root/AppRun" ;;
        2) echo "${cache_dir}/squashfs-root/AppRun" ;;
        3) echo "${cache_dir}/squashfs-root/AppRun" ;;
    esac
}

check_slicer_cached() {
    local choice=$1
    local executable=$(get_executable_path "$choice")
    # Check extracted executable exists and is executable
    [ -f "$executable" ] && [ -x "$executable" ]
}

get_cached_version() {
    local choice=$1
    local cache_dir="${SLICER_CACHE}/${SLICER_DIRS[$choice]}"
    if [ -f "${cache_dir}/version.txt" ]; then
        cat "${cache_dir}/version.txt"
    else
        echo "unknown"
    fi
}

find_exports() {
    # Find all export directories, sorted newest first
    find "$EXPORT_BASE" -maxdepth 1 -type d -name "Export_*" 2>/dev/null | sort -r
}

get_export_info() {
    local export_dir=$1
    local obj_file="${export_dir}/combined_all_segments.obj"
    local stl_count=$(find "$export_dir" -name "*.stl" 2>/dev/null | wc -l)
    local size="0 KB"

    if [ -f "$obj_file" ]; then
        local bytes=$(stat -c%s "$obj_file" 2>/dev/null || echo 0)
        if [ "$bytes" -gt 1048576 ]; then
            size="$((bytes / 1048576)) MB"
        else
            size="$((bytes / 1024)) KB"
        fi
    fi

    echo "${stl_count} segments, ${size}"
}

launch_slicer() {
    local choice=$1
    local obj_file=$2
    local executable=$(get_executable_path "$choice")

    # Ensure DISPLAY is set
    export DISPLAY=:1
    export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt

    # Launch slicer in a new session so it survives after script exits
    setsid "$executable" "$obj_file" </dev/null >/dev/null 2>&1 &
    sleep 1
}

# ============================================
# Main script
# ============================================

# If not running in a terminal, relaunch in one
if [ -z "$IN_TERMINAL" ]; then
    export IN_TERMINAL=1
    xfce4-terminal --hold -x bash -c "export DISPLAY=:1; export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt; export IN_TERMINAL=1; bash '/usr/local/bin/print-3d-models'"
    exit 0
fi

# Set SSL certificate path for slicers
export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt

clear
echo ""
echo "  ╔════════════════════════════════════════════════════════════════╗"
echo "  ║                      PRINT 3D MODELS                           ║"
echo "  ╠════════════════════════════════════════════════════════════════╣"
echo "  ║                                                                ║"
echo "  ║  Select your slicer software:                                  ║"
echo "  ║                                                                ║"
echo "  ║  1) OrcaSlicer                                                 ║"
echo "  ║     └─ Bambu Lab (X1, P1, A1) .............. Cloud supported   ║"
echo "  ║     └─ Snapmaker U1, Prusa, Voron, Creality, others            ║"
echo "  ║                                                                ║"
echo "  ║  2) PrusaSlicer                                                ║"
echo "  ║     └─ Prusa (MK3, MK4, Mini, XL) .......... Cloud supported   ║"
echo "  ║     └─ Generic FDM printers                                    ║"
echo "  ║                                                                ║"
echo "  ║  3) Cura                                                       ║"
echo "  ║     └─ UltiMaker ........................... Cloud supported   ║"
echo "  ║     └─ Creality, Anker, Elegoo, many others                    ║"
echo "  ║                                                                ║"
echo "  ║  q) Quit                                                       ║"
echo "  ║                                                                ║"
echo "  ╚════════════════════════════════════════════════════════════════╝"
echo ""
read -p "  Enter choice [1-3]: " choice

if [ "$choice" = "q" ] || [ "$choice" = "Q" ]; then
    exit 0
fi

if ! [[ "$choice" =~ ^[1-3]$ ]]; then
    echo ""
    echo "  ✗ Invalid selection"
    read -p "  Press Enter to exit..."
    exit 1
fi

slicer_name="${SLICER_NAMES[$choice]}"

echo ""
echo "  ┌─ ${slicer_name}"
echo "  │"

# Check if cached or need to download
if check_slicer_cached "$choice"; then
    version=$(get_cached_version "$choice")
    echo "  │  ✓ Using cached version (v${version})"
else
    echo "  │  Checking for latest version..."
    mkdir -p "$SLICER_CACHE"
    if ! download_slicer "$choice"; then
        echo "  │"
        echo "  └─ ✗ Failed to download ${slicer_name}"
        read -p "  Press Enter to exit..."
        exit 1
    fi
fi

echo "  │"

# Find exports (using mapfile to handle paths with spaces)
mapfile -t exports < <(find_exports)

if [ ${#exports[@]} -eq 0 ]; then
    echo "  │  ✗ No 3D model exports found"
    echo "  │"
    echo "  │  Run \"Create 3D Models\" first to export segments from 3D Slicer"
    echo "  │"
    echo "  └─"
    read -p "  Press Enter to exit..."
    exit 1
fi

if [ ${#exports[@]} -eq 1 ]; then
    selected_export="${exports[0]}"
    export_name=$(basename "$selected_export")
    export_info=$(get_export_info "$selected_export")
    echo "  │  ✓ Found: ${export_name} (${export_info})"
else
    echo "  │  Multiple exports found:"
    for i in "${!exports[@]}"; do
        export_name=$(basename "${exports[$i]}")
        export_info=$(get_export_info "${exports[$i]}")
        echo "  │  $((i+1))) ${export_name} (${export_info})"
    done
    echo "  │"
    read -p "  │  Load which export? [1]: " export_choice
    export_choice=${export_choice:-1}

    if ! [[ "$export_choice" =~ ^[0-9]+$ ]] || [ "$export_choice" -lt 1 ] || [ "$export_choice" -gt ${#exports[@]} ]; then
        echo "  │"
        echo "  └─ ✗ Invalid selection"
        read -p "  Press Enter to exit..."
        exit 1
    fi

    selected_export="${exports[$((export_choice-1))]}"
fi

obj_file="${selected_export}/combined_all_segments.obj"

if [ ! -f "$obj_file" ]; then
    echo "  │"
    echo "  │  ✗ OBJ file not found in export folder"
    echo "  └─"
    read -p "  Press Enter to exit..."
    exit 1
fi

echo "  │"
echo "  │  ✓ Loading: combined_all_segments.obj"
echo "  │"

# Show next steps
cloud_name="${CLOUD_NAMES[$choice]}"
cloud_login="${CLOUD_LOGIN[$choice]}"
cloud_send="${CLOUD_SEND[$choice]}"

echo "  ╔════════════════════════════════════════════════════════════════╗"
echo "  ║  NEXT STEPS                                                    ║"
echo "  ╠════════════════════════════════════════════════════════════════╣"
echo "  ║                                                                ║"
echo "  ║  After slicing your model:                                     ║"
echo "  ║                                                                ║"
echo "  ║  • CLOUD PRINTING (${cloud_name})"
echo "  ║    1. ${cloud_login}"
echo "  ║    2. ${cloud_send}"
echo "  ║                                                                ║"
echo "  ║  • MANUAL TRANSFER (USB/SD card)                               ║"
echo "  ║    1. File → Export → Export G-code                            ║"
echo "  ║    2. Save to: /FILE TRANSFERS/                                ║"
echo "  ║    3. Download via web browser (port 8080)                     ║"
echo "  ║    4. Copy to USB/SD and insert into printer                   ║"
echo "  ║                                                                ║"
echo "  ╚════════════════════════════════════════════════════════════════╝"
echo ""
read -p "  Press Enter to launch ${slicer_name}..."

echo ""
echo "  └─ Launching ${slicer_name}..."

launch_slicer "$choice" "$obj_file"

echo ""
echo "  ${slicer_name} is starting. You can close this terminal."
echo ""
