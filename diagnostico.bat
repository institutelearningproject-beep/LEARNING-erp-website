@echo off
chcp 65001 >nul
cd /d "%~dp0"

echo === GIT VERSION === > debug.txt 2>&1
git --version >> debug.txt 2>&1

echo. >> debug.txt
echo === GIT STATUS === >> debug.txt 2>&1
git status >> debug.txt 2>&1

echo. >> debug.txt
echo === GIT LOG === >> debug.txt 2>&1
git log --oneline 2>> debug.txt || echo (sin commits aun) >> debug.txt

echo. >> debug.txt
echo === GIT REMOTE === >> debug.txt 2>&1
git remote -v >> debug.txt 2>&1

echo. >> debug.txt
echo === DIR === >> debug.txt 2>&1
dir >> debug.txt 2>&1

echo Listo. Revisa debug.txt
pause
