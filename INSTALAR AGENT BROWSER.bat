@echo off
chcp 65001 >nul
cd /d "%~dp0"
title Instalar agent-browser - Learning Project Institute

echo ================================================================
echo   INSTALACION DE AGENT-BROWSER
echo   Le da a Claude Code / Codex el control de un Chrome real
echo ================================================================
echo.
echo Carpeta del proyecto:
echo   %CD%
echo.

echo [1/4] Comprobando Node.js...
where node >nul 2>nul
if errorlevel 1 (
  echo.
  echo   ERROR: No se encontro Node.js en este equipo.
  echo   Descargalo desde https://nodejs.org  ^(version LTS^)
  echo   Instalalo, CIERRA esta ventana y vuelve a ejecutar este archivo.
  echo.
  pause
  exit /b 1
)
for /f "tokens=*" %%v in ('node --version') do echo   Node.js %%v encontrado.
echo.

echo [2/4] Instalando la habilidad para el agente...
echo.
echo   ATENCION: te va a preguntar "Which agents do you want to install to?"
echo   Escribe  claude  en el buscador, parate sobre "Claude Code (.claude/skills)"
echo   y presiona ESPACIO hasta que el circulo se ponga relleno. Luego ENTER.
echo   Si no lo marcas, la habilidad NO llega a Claude Code.
echo.
pause
call npx --yes skills add vercel-labs/agent-browser
if errorlevel 1 (
  echo.
  echo   AVISO: la habilidad no se instalo. Revisa tu conexion a internet.
  echo.
)
echo.

echo [3/4] Instalando el comando agent-browser...
call npm install -g agent-browser
if errorlevel 1 (
  echo.
  echo   ERROR: no se pudo instalar el paquete.
  echo   Prueba abriendo esta ventana como Administrador.
  echo.
  pause
  exit /b 1
)
echo.

echo [4/4] Descargando el navegador de automatizacion...
call agent-browser install
if errorlevel 1 (
  echo.
  echo   AVISO: no se pudo descargar Chrome for Testing.
  echo   Igual puedes usar tu Chrome normal con la opcion --auto-connect.
  echo.
)
echo.

echo ================================================================
echo   LISTO
echo ================================================================
echo.
echo   Comprobacion rapida:
call agent-browser --version
echo.
echo   Para usar TU Chrome de siempre ^(con tus sesiones ya iniciadas^):
echo     1^) Cierra Chrome por completo.
echo     2^) Abrelo con depuracion remota:
echo        "C:\Program Files\Google\Chrome\Application\chrome.exe" --remote-debugging-port=9222
echo     3^) Luego usa:  agent-browser --auto-connect open https://learningproject.mx/erp
echo.
echo   Prueba suelta ^(navegador propio, sin tocar el tuyo^):
echo     agent-browser open https://learningproject.mx/erp
echo     agent-browser screenshot erp.png
echo.
echo   Ver la guia completa de comandos:
echo     agent-browser skills get core --full
echo.
pause
