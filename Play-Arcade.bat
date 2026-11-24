@echo off
python "%~dp0tools\mouse_gun.py" --arcade %*
if errorlevel 1 pause
