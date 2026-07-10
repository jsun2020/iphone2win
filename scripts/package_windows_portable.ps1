param(
  [string]$Root = (Resolve-Path "$PSScriptRoot\..").Path
)

$ErrorActionPreference = 'Stop'

$App = Join-Path $Root 'app'
$Release = Join-Path $App 'build\windows\x64\runner\Release'
$Dist = Join-Path $Root 'dist'
$Payload = Join-Path $env:TEMP ("iphone2win_payload_{0}" -f ([guid]::NewGuid().ToString('N')))
$LibimobiledeviceTools = Join-Path $Root 'tools\libimobiledevice'
$Zip = Join-Path $Dist 'iphone2win-portable-files.zip'
$RunnerPath = Join-Path $Dist 'run_iphone2win.cmd'
$PortableExe = Join-Path $Dist 'iphone2win-portable.exe'

if (-not (Test-Path -LiteralPath $Release)) {
  throw "Windows release directory not found: $Release"
}

New-Item -ItemType Directory -Path $Dist -Force | Out-Null
New-Item -ItemType Directory -Path $Payload -Force | Out-Null

try {
  Copy-Item -Path (Join-Path $Release '*') -Destination $Payload -Recurse -Force

  if (Test-Path -LiteralPath $LibimobiledeviceTools) {
    $TargetTools = Join-Path $Payload 'tools\libimobiledevice'
    New-Item -ItemType Directory -Path $TargetTools -Force | Out-Null
    Copy-Item -Path (Join-Path $LibimobiledeviceTools '*') -Destination $TargetTools -Recurse -Force
  } else {
    Write-Host 'Automatic USB tools not found at tools\libimobiledevice; packaging manual USB/LAN features only.'
  }

  if (Test-Path -LiteralPath $Zip) {
    Remove-Item -LiteralPath $Zip -Force
  }
  Compress-Archive -Path (Join-Path $Payload '*') -DestinationPath $Zip -Force
} finally {
  if (Test-Path -LiteralPath $Payload) {
    Remove-Item -LiteralPath $Payload -Recurse -Force
  }
}

$Runner = @'
@echo off
setlocal
set "ZIPFILE=%~dp0iphone2win-portable-files.zip"
set "WORKDIR=%TEMP%\iphone2win-portable-run"
if not exist "%ZIPFILE%" (
  echo Missing portable payload: %ZIPFILE%
  pause
  exit /b 1
)
if exist "%WORKDIR%" rmdir /s /q "%WORKDIR%"
mkdir "%WORKDIR%"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -LiteralPath $env:ZIPFILE -DestinationPath $env:WORKDIR -Force"
if errorlevel 1 (
  echo Failed to extract iphone2win portable payload.
  pause
  exit /b 1
)
start "" "%WORKDIR%\iphone2win.exe"
exit /b 0
'@

Set-Content -LiteralPath $RunnerPath -Value $Runner -Encoding ASCII

$IExpress = Join-Path $env:SystemRoot 'System32\iexpress.exe'
if (Test-Path -LiteralPath $IExpress) {
  $SedPath = Join-Path $env:TEMP ("iphone2win_{0}.sed" -f ([guid]::NewGuid().ToString('N')))
  $Sed = @"
[Version]
Class=IEXPRESS
SEDVersion=3
[Options]
PackagePurpose=InstallApp
ShowInstallProgramWindow=0
HideExtractAnimation=1
UseLongFileName=1
InsideCompressed=0
CAB_FixedSize=0
CAB_ResvCodeSigning=0
RebootMode=N
InstallPrompt=
DisplayLicense=
FinishMessage=
TargetName=$PortableExe
FriendlyName=iphone2win portable
AppLaunched=cmd.exe /c run_iphone2win.cmd
PostInstallCmd=<None>
AdminQuietInstCmd=cmd.exe /c run_iphone2win.cmd
UserQuietInstCmd=cmd.exe /c run_iphone2win.cmd
SourceFiles=SourceFiles
[SourceFiles]
SourceFiles0=$Dist\
[SourceFiles0]
%FILE0%=
%FILE1%=
[Strings]
FILE0="iphone2win-portable-files.zip"
FILE1="run_iphone2win.cmd"
"@

  try {
    Set-Content -LiteralPath $SedPath -Value $Sed -Encoding ASCII
    if (Test-Path -LiteralPath $PortableExe) {
      Remove-Item -LiteralPath $PortableExe -Force
    }
    & $IExpress /N /Q $SedPath
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $PortableExe)) {
      throw "IExpress failed to create $PortableExe"
    }
  } finally {
    if (Test-Path -LiteralPath $SedPath) {
      Remove-Item -LiteralPath $SedPath -Force
    }
  }
} else {
  Write-Warning "IExpress not found at $IExpress; ZIP and launcher were created without the single-file EXE wrapper."
}

Write-Host "Updated $Zip"
if (Test-Path -LiteralPath $PortableExe) {
  Write-Host "Updated $PortableExe"
}
