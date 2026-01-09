#!/bin/bash
# Export STL Trigger Script
# Creates a trigger file that running Slicer instances will detect

TRIGGER_DIR="/tmp"
TRIGGER_PREFIX="slicer-export-trigger-"
EXPORT_BASE="/FILE TRANSFERS"

# Create trigger file with timestamp
TIMESTAMP=$(date +%s%N)
TRIGGER_FILE="${TRIGGER_DIR}/${TRIGGER_PREFIX}${TIMESTAMP}"

# Check if any Slicer is running
if ! pgrep -f "Slicer" > /dev/null; then
    # Show notification if possible, otherwise use xmessage or zenity
    if command -v notify-send &> /dev/null; then
        notify-send "Export STL" "No 3D Slicer instance is running" --icon=dialog-warning
    elif command -v zenity &> /dev/null; then
        zenity --warning --text="No 3D Slicer instance is running" --title="Export STL"
    else
        xmessage -center "No 3D Slicer instance is running"
    fi
    exit 1
fi

# Create trigger file
touch "$TRIGGER_FILE"

# Brief notification
if command -v notify-send &> /dev/null; then
    notify-send "Export STL" "Exporting segments to $EXPORT_BASE" --icon=document-save
fi

echo "Export triggered. STL files will appear in $EXPORT_BASE"
