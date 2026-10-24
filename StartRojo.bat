@echo off
setlocal
set "ROJO_PROJECT_DIR=%~dp0"
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference = 'Stop'; $root = $env:ROJO_PROJECT_DIR; $rojo = Join-Path $env:USERPROFILE '.rokit\bin\rojo.exe'; if (-not (Test-Path -LiteralPath $rojo)) { $rojo = (Get-Command rojo.exe -ErrorAction Stop).Source }; $logs = Join-Path $root '.tools'; New-Item -ItemType Directory -Path $logs -Force | Out-Null; Start-Process -FilePath $rojo -ArgumentList 'serve default.project.json --address 127.0.0.1' -WorkingDirectory $root -WindowStyle Hidden -RedirectStandardOutput (Join-Path $logs 'rojo.stdout.log') -RedirectStandardError (Join-Path $logs 'rojo.stderr.log')"
exit /b %errorlevel%
