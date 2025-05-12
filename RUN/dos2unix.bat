@echo off
setlocal

rem Check if correct number of arguments is provided
if "%~2"=="" (
    echo Usage: %~nx0 path_to_bash path_to_file
    exit /b 1
)

rem Assign command line arguments to variables
set "BASH_PATH=%~1"
set "FILE_PATH=%~2"

rem Run dos2unix using bash
"%BASH_PATH%" -c "dos2unix '%FILE_PATH%'"

endlocal