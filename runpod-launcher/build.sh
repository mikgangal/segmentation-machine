#!/bin/bash
# Build for Windows from Linux/Mac
echo "Building SlicerLauncher.exe for Windows..."
GOOS=windows GOARCH=amd64 go build -ldflags="-s -w" -o SlicerLauncher.exe main.go

if [ $? -eq 0 ]; then
    echo "Build successful: SlicerLauncher.exe"
    ls -la SlicerLauncher.exe
else
    echo "Build failed!"
    exit 1
fi
