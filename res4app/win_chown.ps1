#requires -version 5.1
param()

$ErrorActionPreference = 'Stop'

function Exit-WithCode([int]$code)
{
  exit $code
}

# Admin check
function Test-IsElevated
{
  try
  {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = [Security.Principal.WindowsPrincipal]$id
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  }
  catch
  {
    return $false
  }
}

# Args: mode id log_dir files...
if ($args.Count -lt 3)
{
  Write-Error '1: Nie podano katalogu dla pliku dziennika'
  Exit-WithCode 1
}

$mode = $args[0]
if ( [string]::IsNullOrWhiteSpace($mode))
{
  Write-Error '3: Nie podano trybu [mode]'
  Exit-WithCode 3
}

$baseMode = $mode
$skipElevate = $false
if ( $mode.StartsWith('elevated_', [StringComparison]::OrdinalIgnoreCase))
{
  $skipElevate = $true
  $baseMode = $mode.Substring(9)
}

$validModes = @('default', 'private', 'root_private', 'root_public')
if ($validModes -notcontains $baseMode.ToLowerInvariant())
{
  Write-Error ("3: Nieprawidłowy tryb [mode]: {0}" -f $mode)
  Exit-WithCode 3
}

$idStr = $args[1]
if ( [string]::IsNullOrWhiteSpace($idStr))
{
  Write-Error '2: Nie podano identyfikatora [id]'
  Exit-WithCode 2
}
if ($idStr -notmatch '^[0-9]+$')
{
  Write-Error ("2: Nieprawidłowy identyfikator [id]: {0}" -f $idStr)
  Exit-WithCode 2
}
[int]$id = [int]$idStr

$logDir = $args[2]
if ( [string]::IsNullOrWhiteSpace($logDir))
{
  Write-Error '1: Nie podano katalogu dla pliku dziennika'
  Exit-WithCode 1
}
try
{
  if (-not (Test-Path -LiteralPath $logDir))
  {
    New-Item -ItemType Directory -LiteralPath $logDir -Force | Out-Null
  }
}
catch
{
  Write-Error ("1: Nie można utworzyć katalogu dziennika: ""{0}""" -f $logDir)
  Exit-WithCode 1
}

$logFile = Join-Path $logDir ("win_chown.{0}.lab.log" -f $id)

$files =
if ($args.Count -gt 3)
{
  $args[3..($args.Count - 1)]
}
else
{
  "4: Nie podano ścieżek do plików" | Tee-Object -FilePath $logFile -Append | Out-Host
  Exit-WithCode 4
}

# Elevation
$elevated = Test-IsElevated
if (-not $elevated -and -not $skipElevate)
{
  "UWAGA: Ten skrypt wymaga uprawnień administratora." | Out-Host
  "Próba uruchomienia z podwyższonymi uprawnieniami..." | Out-Host
  $psi = @{
    FilePath = 'powershell.exe'
    ArgumentList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath) + $args
    Verb = 'RunAs'
    PassThru = $true
    WindowStyle = 'Hidden'
    WorkingDirectory = (Get-Location).Path
  }
  try
  {
    $p = Start-Process @psi
    $p.WaitForExit()
    Exit-WithCode $p.ExitCode
  }
  catch
  {
    "10: Błąd podczas próby uruchomienia z uprawnieniami administratora" | Tee-Object -FilePath $logFile -Append | Out-Host
    Exit-WithCode 10
  }
}

# Logging helper
function Log([string]$msg, [switch]$ToError)
{
  try
  {
    Add-Content -LiteralPath $logFile -Value $msg -Encoding UTF8
  }
  catch
  {
  }
  if ($ToError)
  {
    Write-Error $msg
  }
  else
  {
    Write-Host $msg
  }
}

Log ("Zapisywanie dziennika do pliku: {0}" -f $logFile)

# Mode-specific state
$currentUserSid = $null
if ( $baseMode.Equals('private', 'InvariantCultureIgnoreCase'))
{
  try
  {
    $currentUserSid = ([Security.Principal.WindowsIdentity]::GetCurrent()).User.Value
  }
  catch
  {
    Log '9: Nie udało się uzyskać SID bieżącego użytkownika' -ToError
    Exit-WithCode 9
  }
  if (-not $currentUserSid)
  {
    Log '9: Nie udało się uzyskać SID bieżącego użytkownika' -ToError
    Exit-WithCode 9
  }
}

# Constants
$SID_Admins = 'S-1-5-32-544'
$SID_System = 'S-1-5-18'
$SID_Users = 'S-1-5-32-545'
$SID_Auth = 'S-1-5-11'

# Process each file
foreach ($path in $files)
{
  if ( [string]::IsNullOrWhiteSpace($path))
  {
    Log '6: Błąd przed przetwarzaniem pliku' -ToError
    Exit-WithCode 6
  }

  Log ("[win_chown] Przetwarzanie pliku: {0}" -f $path)
  if (-not (Test-Path -LiteralPath $path))
  {
    Log ("7: Nie znaleziono pliku: {0}" -f $path) -ToError
    Exit-WithCode 7
  }

  Log ("Tryb: {0}" -f $baseMode)
  Log ("Wykonywanie: icacls ""{0}""" -f $path)
  & icacls $path | Tee-Object -FilePath $logFile -Append | Out-Null
  if ($LASTEXITCODE -ne 0)
  {
    Log ("9: Błąd wykonania polecenia icacls dla {0}" -f $path) -ToError
    Exit-WithCode 9
  }

  Log 'Resetowanie uprawnień...'
  Log ("Wykonywanie: icacls ""{0}"" /reset" -f $path)
  & icacls $path /reset | Tee-Object -FilePath $logFile -Append | Out-Null
  if ($LASTEXITCODE -ne 0)
  {
    Log ("8: Nie udało się przetworzyć pliku: {0}" -f $path) -ToError
    Exit-WithCode 8
  }

  switch -Regex ( $baseMode.ToLowerInvariant())
  {
    '^default$' {
      Log 'Ustawiono domyślne uprawnienia.'
    }
    '^private$' {
      Log 'Ustawianie prywatnych uprawnień dla bieżącego użytkownika...'
      Log ("Wykonywanie: icacls ""{0}"" /grant *{1}:F" -f $path, $currentUserSid)
      & icacls $path /grant ("*{0}:F" -f $currentUserSid) | Tee-Object -FilePath $logFile -Append | Out-Null
      if ($LASTEXITCODE -ne 0)
      {
        Log ("8: Nie udało się przetworzyć pliku: {0}" -f $path) -ToError; Exit-WithCode 8
      }

      Log ("Wykonywanie: icacls ""{0}"" /setowner *{1}" -f $path, $currentUserSid)
      & icacls $path /setowner ("*{0}" -f $currentUserSid) | Tee-Object -FilePath $logFile -Append | Out-Null
      if ($LASTEXITCODE -ne 0)
      {
        Log ("8: Nie udało się przetworzyć pliku: {0}" -f $path) -ToError; Exit-WithCode 8
      }

      Log ("Wykonywanie: icacls ""{0}"" /inheritance:r /c /grant:r *{1}:F" -f $path, $currentUserSid)
      & icacls $path /inheritance:r /c /grant:r ("*{0}:F" -f $currentUserSid) | Tee-Object -FilePath $logFile -Append | Out-Null
      if ($LASTEXITCODE -ne 0)
      {
        Log ("8: Nie udało się przetworzyć pliku: {0}" -f $path) -ToError; Exit-WithCode 8
      }
    }
    '^(root_private|root_public)$' {
      Log 'Ustawianie uprawnień administratora...'
      Log ("Wykonywanie: icacls ""{0}"" /grant *{1}:F" -f $path, $SID_Admins)
      & icacls $path /grant ("*{0}:F" -f $SID_Admins) | Tee-Object -FilePath $logFile -Append | Out-Null
      if ($LASTEXITCODE -ne 0)
      {
        Log ("8: Nie udało się przetworzyć pliku: {0}" -f $path) -ToError; Exit-WithCode 8
      }

      Log ("Wykonywanie: icacls ""{0}"" /setowner *{1}" -f $path, $SID_Admins)
      & icacls $path /setowner ("*{0}" -f $SID_Admins) | Tee-Object -FilePath $logFile -Append | Out-Null
      if ($LASTEXITCODE -ne 0)
      {
        Log ("8: Nie udało się przetworzyć pliku: {0}" -f $path) -ToError; Exit-WithCode 8
      }

      if ($baseMode -ieq 'root_private')
      {
        Log 'Ustawianie prywatnych uprawnień administratora...'
        Log ("Wykonywanie: icacls ""{0}"" /inheritance:r /c /grant:r *{1}:F *{2}:F" -f $path, $SID_System, $SID_Admins)
        & icacls $path /inheritance:r /c /grant:r ("*{0}:F" -f $SID_System) ("*{0}:F" -f $SID_Admins) | Tee-Object -FilePath $logFile -Append | Out-Null
        if ($LASTEXITCODE -ne 0)
        {
          Log ("8: Nie udało się przetworzyć pliku: {0}" -f $path) -ToError; Exit-WithCode 8
        }
      }
      else
      {
        Log 'Ustawianie publicznych uprawnień administratora...'
        Log ("Wykonywanie: icacls ""{0}"" /inheritance:r /c /grant:r *{1}:F *{2}:F *{3}:RX *{4}:RX" -f $path, $SID_System, $SID_Admins, $SID_Auth, $SID_Users)
        & icacls $path /inheritance:r /c /grant:r ("*{0}:F" -f $SID_System) ("*{0}:F" -f $SID_Admins) ("*{0}:RX" -f $SID_Auth) ("*{0}:RX" -f $SID_Users) | Tee-Object -FilePath $logFile -Append | Out-Null
        if ($LASTEXITCODE -ne 0)
        {
          Log ("8: Nie udało się przetworzyć pliku: {0}" -f $path) -ToError; Exit-WithCode 8
        }
      }
    }
  }

  Log 'Koncowe uprawnienia:'
  Log ("Wykonywanie: icacls ""{0}""" -f $path)
  & icacls $path | Tee-Object -FilePath $logFile -Append | Out-Null
  if ($LASTEXITCODE -ne 0)
  {
    Log ("8: Nie udało się przetworzyć pliku: {0}" -f $path) -ToError; Exit-WithCode 8
  }

  Log 'Weryfikacja dostępu do pliku...'
  if (Test-Path -LiteralPath $path)
  {
    try
    {
      Get-Item -LiteralPath $path | Out-Null
      Log 'Dostep do pliku zweryfikowany pomyslnie.'
    }
    catch
    {
      Log 'OSTRZEZENIE: Plik istnieje, ale moze miec problemy z dostepem.'
    }
  }
  else
  {
    Log ("11: Plik przestal istniec po zmianie uprawnien: {0}" -f $path) -ToError
    Exit-WithCode 11
  }

  Log ("Pomyślnie przetworzono plik: {0}" -f $path)
}

Log '===================================================================='
Log 'Zakończono przetwarzanie wszystkich plików pomyślnie.'
Log '===================================================================='
Log 'Podsumowanie operacji:'
Log ("  - Identyfikator: {0}" -f $id)
Log ("  - Tryb uprawnień: {0}" -f $mode)
Log ("  - Plik dziennika: {0}" -f $logFile)
Add-Content -LiteralPath $logFile -Value 'OKFIN' -Encoding UTF8
Exit-WithCode 0