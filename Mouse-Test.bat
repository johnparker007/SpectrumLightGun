@echo off
python "%~dp0tools\mouse_gun.py" %*
if errorlevel 1 pause
