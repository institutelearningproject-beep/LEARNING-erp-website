@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo Carpeta que se va a publicar:
echo %CD%
echo.
node "%~dp0deploy_vercel.js"
if errorlevel 1 (
  echo.
  echo ERROR: el despliegue no se completo.
)
pause
