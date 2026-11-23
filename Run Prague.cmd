@echo off
setlocal
set "ENGINE=%LOCALAPPDATA%\TramAtlas\tools\Godot_v4.6.1-stable_win64.exe"
if defined GODOT_BIN set "ENGINE=%GODOT_BIN%"
if exist "%ENGINE%" goto run
for %%G in (godot.exe godot4.exe) do if not "%%~$PATH:G"=="" set "ENGINE=%%~$PATH:G"
if exist "%ENGINE%" goto run
echo Open project.godot in Godot 4.6.1 and press F6 on demo/prague.tscn or F5.
pause
exit /b 1
:run
for %%F in (Barlow-SemiBold DMSerifText-Regular IBMPlexMono-Medium) do if not exist "%~dp0.godot\imported\%%F.ttf-*.fontdata" goto import
goto play
:import
set "IMPORTER=%ENGINE%"
for %%G in ("%ENGINE%") do if exist "%%~dpnG_console.exe" set "IMPORTER=%%~dpnG_console.exe"
start "" /b /wait "%IMPORTER%" --headless --path "%~dp0." --import
if not "%errorlevel%"=="0" goto failed
for %%F in (Barlow-SemiBold DMSerifText-Regular IBMPlexMono-Medium) do if not exist "%~dp0.godot\imported\%%F.ttf-*.fontdata" goto failed
:play
start "" "%ENGINE%" --path "%~dp0." >nul 2>&1
exit /b 0
:failed
echo Godot could not complete the first asset import. Open project.godot to inspect its import log.
exit /b 1
