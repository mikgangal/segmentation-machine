@echo off
echo Building SlicerLauncher.exe...
go build -ldflags="-s -w" -o SlicerLauncher.exe main.go
if %ERRORLEVEL% EQU 0 (
    echo Build successful: SlicerLauncher.exe
) else (
    echo Build failed!
)
pause
