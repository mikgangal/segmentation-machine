@echo off
set OUTPUT=%USERPROFILE%\Desktop\SlicerLauncher.exe
echo Building SlicerLauncher.exe...
go build -ldflags="-s -w" -o "%OUTPUT%" main.go
if %ERRORLEVEL% EQU 0 (
    echo Build successful: %OUTPUT%
) else (
    echo Build failed!
)
pause
