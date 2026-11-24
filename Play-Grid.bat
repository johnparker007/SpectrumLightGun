@echo off
python "%~dp0tools\mouse_gun.py" --grid %*
if errorlevel 1 pause
