@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo Ejecutando deploy con Node.js...
node "%~dp0deploy_vercel.js"
echo.
echo Presiona cualquier tecla para cerrar...
pause >nul
