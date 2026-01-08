#!/bin/bash
# Build for all platforms

echo "Building SlicerLauncher for all platforms..."
echo ""

# Windows
echo "Building Windows (amd64)..."
GOOS=windows GOARCH=amd64 go build -ldflags="-s -w" -o SlicerLauncher-windows.exe main.go
[ $? -eq 0 ] && echo "  ✓ SlicerLauncher-windows.exe" || echo "  ✗ Windows build failed"

# Mac Intel
echo "Building Mac Intel (amd64)..."
GOOS=darwin GOARCH=amd64 go build -ldflags="-s -w" -o SlicerLauncher-mac-intel main.go
[ $? -eq 0 ] && echo "  ✓ SlicerLauncher-mac-intel" || echo "  ✗ Mac Intel build failed"

# Mac Apple Silicon
echo "Building Mac Apple Silicon (arm64)..."
GOOS=darwin GOARCH=arm64 go build -ldflags="-s -w" -o SlicerLauncher-mac-arm64 main.go
[ $? -eq 0 ] && echo "  ✓ SlicerLauncher-mac-arm64" || echo "  ✗ Mac ARM build failed"

echo ""
echo "Build complete:"
ls -la SlicerLauncher-*
