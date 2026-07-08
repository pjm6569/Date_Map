@echo off
REM 윈도우용 배포 스크립트 (release.sh 를 Git Bash 로 실행).
REM 사용법:
REM   release.bat          -> patch 올림 (0.2.0 -> 0.2.1)
REM   release.bat minor    -> minor 올림
REM   release.bat major    -> major 올림
REM   release.bat 0.5.2    -> 특정 버전 지정
REM 더블클릭해도 되고, 터미널에서 실행해도 됩니다.

setlocal

REM Git Bash(bash.exe) 위치 탐색
set "BASH="
if exist "%ProgramFiles%\Git\bin\bash.exe" set "BASH=%ProgramFiles%\Git\bin\bash.exe"
if exist "%ProgramFiles(x86)%\Git\bin\bash.exe" set "BASH=%ProgramFiles(x86)%\Git\bin\bash.exe"
if exist "%LocalAppData%\Programs\Git\bin\bash.exe" set "BASH=%LocalAppData%\Programs\Git\bin\bash.exe"

if "%BASH%"=="" (
  echo [오류] Git Bash를 찾을 수 없습니다. Git for Windows가 설치되어 있어야 합니다.
  pause
  exit /b 1
)

cd /d "%~dp0"
"%BASH%" ./release.sh %*

echo.
pause
