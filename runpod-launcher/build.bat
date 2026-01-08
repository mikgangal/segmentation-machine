@echo off
echo Building SlicerLauncher for all platforms...
echo.

echo Building Windows (amd64)...
set GOOS=windows
set GOARCH=amd64
go build -ldflags="-s -w" -o SlicerLauncher-windows.exe main.go
if %ERRORLEVEL% EQU 0 (echo   OK: SlicerLauncher-windows.exe) else (echo   FAILED: Windows)

echo Building Mac Intel (amd64)...
set GOOS=darwin
set GOARCH=amd64
go build -ldflags="-s -w" -o SlicerLauncher-mac-intel main.go
if %ERRORLEVEL% EQU 0 (echo   OK: SlicerLauncher-mac-intel) else (echo   FAILED: Mac Intel)

echo Building Mac Apple Silicon (arm64)...
set GOOS=darwin
set GOARCH=arm64
go build -ldflags="-s -w" -o SlicerLauncher-mac-arm64 main.go
if %ERRORLEVEL% EQU 0 (echo   OK: SlicerLauncher-mac-arm64) else (echo   FAILED: Mac ARM)

echo.
echo Build complete!
dir SlicerLauncher-*
pause
