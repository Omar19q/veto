@echo off
setlocal
cd /d "%~dp0"
set "FLUTTER_BIN=D:\flutter\bin\flutter.bat"
call "%FLUTTER_BIN%" pub get
if errorlevel 1 exit /b %ERRORLEVEL%
call "%FLUTTER_BIN%" run -d chrome --target lib/main.dart --dart-define-from-file=env.json
pause
