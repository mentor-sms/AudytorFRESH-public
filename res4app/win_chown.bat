
@echo off

REM win_chown.bat FILE MODE LOG_FILE SID

ver >nul 2>nul

set "RUNDIR=%cd%"
set "CCL=%cmdcmdline%"

set "FILE=~1"
set "MODE=~2"
set "LOG_FILE=~3"
set "SID=~4"

echo(CHOWN BAT REV3 >>"%LOG_FILE%" || exit /b 11
echo(%time% >>"%LOG_FILE%"
echo(%RUNDIR%$ %CCL:"=% >>"%LOG_FILE%"
echo( >>"%LOG_FILE%"
echo( >>"%LOG_FILE%"
echo( >>"%LOG_FILE%"

if "%FILE%"=="" (
  echo(missing FILE arg >>"%LOG_FILE%"
  exit /b 1
)
if not exist "%FILE%" (
  echo(file not found on disk: %FILE% >>"%LOG_FILE%"
  exit /b 2
)
if exist "%FILE%\NUL" (
  echo(path is a directory, not a file: %FILE% >>"%LOG_FILE%"
  exit /b 3
)

if /I not "%MODE%"=="PRIVATE" if /I not "%MODE%"=="PROTECTED" if /I not "%MODE%"=="ROOT" if /I not "%MODE%"=="DEFAULT" exit /b 4

if /I "%MODE%"=="PRIVATE" set "PRIVATE=1"
if /I "%MODE%"=="PROTECTED" set "PROTECTED=1"
if /I "%MODE%"=="ROOT" set "ROOT=1"
if /I "%MODE%"=="DEFAULT" set "DEFAULT=1"

echo(RESET:>>"%LOG_FILE%"
icacls "%FILE%" /reset
if errorlevel 1 exit /b 20
if defined DEFAULT ((echo(OKFIN DEFAULT>>"%LOG_FILE%" || exit /b 12) & exit /b 0)

if not defined PRIVATE echo(PREPARE: >>"%LOG_FILE%"
if not defined PRIVATE icacls "%FILE%" /grant *S-1-5-32-544:F
if errorlevel 1 exit /b 21

if not defined PRIVATE echo(ADMINS (OWN): >>"%LOG_FILE%"
if not defined PRIVATE icacls "%FILE%" /setowner *S-1-5-32-544
if errorlevel 1 exit /b 22

if defined PROTECTED echo(LOCALS AND AUTHS (RO):>>"%LOG_FILE%"
if defined PROTECTED icacls "%FILE%" /inheritance:r /c /grant:r *S-1-5-18:F *S-1-5-32-544:F *S-1-5-11:RX *S-1-5-32-545:RX
if errorlevel 1 exit /b 23

if defined ROOT echo(ADMINS AND SYSTEM (RW):>>"%LOG_FILE%"
if defined ROOT icacls "%FILE%" /inheritance:r /c /grant:r *S-1-5-18:F *S-1-5-32-544:F
if errorlevel 1 exit /b 24

if not defined PRIVATE ((echo(OKFIN ADMINS>>"%LOG_FILE%" || exit /b 13) & exit /b 0)

echo(PREPARE: >>"%LOG_FILE%"
icacls "%FILE%" /grant *%SID%:F
if errorlevel 1 exit /b 25

echo(YOU (OWN): >>"%LOG_FILE%"
icacls "%FILE%" /setowner *%SID%
if errorlevel 1 exit /b 26

echo(YOU (RW): >>"%LOG_FILE%"
icacls "%FILE%" /inheritance:r /c /grant:r *%SID%:F
if errorlevel 1 exit /b 27

((echo(OKFIN PRIVATE>>"%LOG_FILE%" || exit /b 14) & exit /b 0)