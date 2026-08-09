@echo off
chcp 65001 >nul
setlocal
echo.
echo ========================================
echo   LPI - Subiendo archivos a GitHub
echo ========================================
echo.

cd /d "%~dp0"

if not exist ".git\" (
    echo ERROR: esta carpeta no tiene el repositorio Git.
    echo No se borro ni se reinicializo nada.
    goto :error
)

if not exist "erp-nuevo.html" (
    echo ERROR: falta erp-nuevo.html en:
    echo %CD%
    goto :error
)

echo [1/5] Verificando repositorio...
git remote get-url origin
if errorlevel 1 goto :error

echo.
echo [2/5] Agregando todo el proyecto permitido por .gitignore...
git add -A
if errorlevel 1 goto :error

echo.
echo [3/5] Archivos preparados:
git status --short

git diff --cached --quiet
if not errorlevel 1 (
    echo.
    echo No hay cambios nuevos para subir.
    goto :success
)

echo.
echo [4/5] Creando commit...
git commit -m "Actualizar sitio y ERP LPI"
if errorlevel 1 goto :error

echo.
echo [5/5] Subiendo a GitHub sin borrar historial...
git branch -M main
git push -u origin main
if errorlevel 1 goto :error

:success
echo.
echo ========================================
echo  LISTO! GitHub contiene erp-nuevo.html
echo  https://github.com/institutelearningproject-beep/LEARNING-erp-website
echo ========================================
goto :end

:error
echo.
echo ERROR: no se completo la subida. No se forzo ni se borro el historial.

:end
echo.
pause
endlocal
