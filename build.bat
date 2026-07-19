@echo off
REM Build RobloxEspOverlay.exe on Windows (.NET 8 SDK required).
REM Run from this folder (the one containing OverlayHost.csproj).
setlocal
pushd %~dp0

where dotnet >nul 2>nul || (
  echo ERROR: .NET 8 SDK not found. Install from https://dotnet.microsoft.com/download
  exit /b 1
)

dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true

if %ERRORLEVEL% neq 0 (
  echo BUILD FAILED
  exit /b 1
)

REM Copy the React settings UI next to the published exe
set PUB=bin\Release\net8.0-windows\win-x64\publish
if not exist "%PUB%\ReactUi\dist" mkdir "%PUB%\ReactUi\dist"
copy /Y "ReactUi\dist\index.html" "%PUB%\ReactUi\dist\index.html" >nul

echo.
echo BUILD OK -> %PUB%\RobloxEspOverlay.exe
echo Copy the whole 'publish' folder to the target machine and run the exe.
endlocal
