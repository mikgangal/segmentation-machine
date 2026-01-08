#!/bin/bash
# Build for Windows from Linux/Mac
OUTPUT="$HOME/Desktop/SlicerLauncher.exe"
echo "Building SlicerLauncher.exe for Windows..."
GOOS=windows GOARCH=amd64 go build -ldflags="-s -w" -o "$OUTPUT" main.go

if [ $? -eq 0 ]; then
    echo "Build successful: $OUTPUT"
    ls -la "$OUTPUT"
else
    echo "Build failed!"
    exit 1
fi
