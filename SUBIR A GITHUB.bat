@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"
echo.
echo ===============================================
echo   Subir el proyecto LPI a GitHub
echo ===============================================
echo.

if exist ".git\index.lock" del /f /q ".git\index.lock"
if exist "_to_delete" rmdir /s /q "_to_delete"

echo [1/5] Sacando los contratos del control de versiones...
git rm --cached -q --ignore-unmatch "Contrato_ERP_LearningProject.docx" "Contrato_ERP_LearningProject_v2.pdf"

echo [2/5] Revisando que no se suba ningun secreto...
git add -A
git diff --cached --name-only > "%TEMP%\lpi_files.txt"
findstr /i /c:"CLAVES_ERP" /c:"vercel_token" /c:".jks" /c:".keystore" "%TEMP%\lpi_files.txt" >nul
if not errorlevel 1 (
  echo.
  echo   *** ALTO: se detecto un archivo con credenciales. No se subio nada. ***
  echo   Revisa el .gitignore antes de continuar.
  pause
  exit /b 1
)
echo       OK, no hay secretos.

echo [3/5] Creando el commit...
git -c core.autocrlf=false commit -F "mensaje_commit.txt"
if errorlevel 1 echo       (No habia cambios nuevos que commitear, seguimos.)

echo [4/5] Subiendo a GitHub...
git push origin main
if errorlevel 1 (
  echo.
  echo   *** El push fallo. Lo mas probable: el token de GitHub ya no sirve. ***
  echo   Genera uno nuevo en github.com  ^>  Settings  ^>  Developer settings
  echo   ^>  Personal access tokens  ^>  Tokens (classic)  ^>  permiso "repo".
  echo   Luego corre:  git remote set-url origin https://TU_USUARIO:TU_TOKEN@github.com/institutelearningproject-beep/LEARNING-erp-website.git
  echo.
  pause
  exit /b 1
)

echo [5/5] Quitando el token guardado en .git\config...
git remote set-url origin https://github.com/institutelearningproject-beep/LEARNING-erp-website.git
echo       Listo. La proxima vez Windows te pedira iniciar sesion en GitHub una sola vez.

echo.
echo ===============================================
echo   LISTO. Revisa el repo en:
echo   https://github.com/institutelearningproject-beep/LEARNING-erp-website
echo ===============================================
echo.
echo IMPORTANTE: entra a GitHub y REVOCA el token viejo
echo (Settings ^> Developer settings ^> Personal access tokens).
echo.
pause
