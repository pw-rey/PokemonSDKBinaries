param()
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path "$PSScriptRoot/../..").Path
$work = Join-Path $root 'generated/windows-x86'
New-Item -ItemType Directory -Force "$work/downloads" | Out-Null
function Fetch($Url, $Hash, $Destination) {
    Write-Host "[$(Get-Date -Format o)] Fetching $Url"
    if (!(Test-Path -LiteralPath $Destination)) {
        & "$env:SystemRoot/System32/curl.exe" -fL --retry 2 --connect-timeout 30 --max-time 300 --speed-time 60 --speed-limit 1024 $Url -o "$Destination.tmp"
        if ($LASTEXITCODE) { throw "Download failed: $Url" }
        Move-Item -LiteralPath "$Destination.tmp" -Destination $Destination
    }
    Write-Host "[$(Get-Date -Format o)] Verifying $Destination"
    if ((Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash -ne $Hash) {
        throw "Checksum mismatch: $Destination"
    }
}
Fetch 'https://repo.msys2.org/distrib/x86_64/msys2-base-x86_64-20250830.tar.xz' `
    '780d7546aa86b781e0ded37c7b8f71f1b8572219494fe88259d8d4b78752b2e2' "$work/downloads/msys2.tar.xz"
if (!(Test-Path "$work/msys64/usr/bin/bash.exe")) {
    Write-Host "[$(Get-Date -Format o)] Extracting MSYS2"
    & "$env:SystemRoot/System32/tar.exe" -xf "$work/downloads/msys2.tar.xz" -C $work
    if ($LASTEXITCODE) { throw 'MSYS2 extraction failed' }
}
Fetch 'https://github.com/oneclick/rubyinstaller2/releases/download/RubyInstaller-3.4.10-1/rubyinstaller-3.4.10-1-x86.7z' `
    'be323ac7b8342de16edcceb1ee04a90023c39aa7e7a544e628c6360fffb602da' "$work/downloads/rubyinstaller.7z"
$env:MSYSTEM = 'MINGW32'
$env:CHERE_INVOKING = '1'
$env:MSYS2_PATH_TYPE = 'strict'
Push-Location $root
try {
    Write-Host "[$(Get-Date -Format o)] Starting isolated MSYS2 package installation"
    # Merge native diagnostics inside bash: Windows PowerShell 5 otherwise
    # promotes pacman warnings to terminating errors when logs are redirected.
    & "$work/msys64/usr/bin/bash.exe" -lc 'bash windows/x86/install-packages.sh 2>&1'
    if ($LASTEXITCODE) { throw 'CI package installation failed' }
} finally { Pop-Location }
