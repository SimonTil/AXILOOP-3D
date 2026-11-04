<#
Builds the unsigned MSIX Store package from an existing install tree.
The package is intentionally NOT signed: the Microsoft Store strips and
re-signs uploads with Microsoft's certificate. For local installs use
Developer Mode loose-layout registration instead:
  ./scripts/msix/build_msix.ps1 -StageOnly
  Add-AppxPackage -Register <staging>\AppxManifest.xml
Requires the Windows SDK (makeappx.exe) unless -StageOnly is used.
#>
param(
    # AXILOOP-3D: own package name, identity, publisher and exe name
    [string]$InstallDir = "build/OrcaSlicer",
    [string]$OutputPath = "build/AXILOOP-3D_Windows_MSIX.msix",
    [ValidateSet("x64", "arm64")]
    [string]$Architecture = "x64",
    [string]$StagingDir = "",
    [switch]$StageOnly,
    [string]$IdentityName = "Axiloop.AXILOOP3D",
    # TODO: replace with Axiloop's publisher ID from the Microsoft Partner Center before a Store release
    [string]$Publisher = "CN=Axiloop",
    [string]$PublisherDisplayName = "Axiloop"
)
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

# MSIX version = MAJOR.MINOR.PATCH.0 from the AXILOOP_VERSION semver triplet
# (Store requires the revision field to be 0).
# AXILOOP-3D: use the app's own version
$versionContent = Get-Content (Join-Path $repoRoot 'version.inc') -Raw
if ($versionContent -notmatch 'set\(AXILOOP_VERSION "(\d+)\.(\d+)\.(\d+)') {
    throw "Could not parse AXILOOP_VERSION from version.inc"
}
$msixVersion = "$($Matches[1]).$($Matches[2]).$($Matches[3]).0"

# Optional one-off override (Major.Minor.Build.0), e.g. when a wrong build was already published to the Store.
# AXILOOP-3D: upstream's override for its own Store listing removed
$msixVersionOverride = ''
if ($msixVersionOverride) {
    if ($msixVersionOverride -notmatch '^\d+\.\d+\.\d+\.0$') {
        throw "MSIX version override '$msixVersionOverride' must be Major.Minor.Build.0 - the Store rejects a non-zero revision field."
    }
    $msixVersion = $msixVersionOverride
}
Write-Output "MSIX version: $msixVersion"

if (-not (Test-Path (Join-Path $InstallDir 'axiloop-3d.exe'))) {
    throw "axiloop-3d.exe not found in '$InstallDir' - build the install tree first"
}

if ([string]::IsNullOrEmpty($StagingDir)) {
    $StagingDir = Join-Path ([System.IO.Path]::GetTempPath()) 'orca-msix-staging'
}
if (Test-Path $StagingDir) { Remove-Item $StagingDir -Recurse -Force }
New-Item -ItemType Directory -Force $StagingDir | Out-Null

Copy-Item -Path (Join-Path $InstallDir '*') -Destination $StagingDir -Recurse
Copy-Item -Path (Join-Path $PSScriptRoot 'assets') -Destination (Join-Path $StagingDir 'Assets') -Recurse

$manifest = Get-Content (Join-Path $PSScriptRoot 'AppxManifest.xml') -Raw
$manifest = $manifest.Replace('@MSIX_VERSION@', $msixVersion)
$manifest = $manifest.Replace('@MSIX_IDENTITY_NAME@', $IdentityName)
$manifest = $manifest.Replace('@MSIX_PUBLISHER@', $Publisher)
$manifest = $manifest.Replace('@MSIX_PUBLISHER_DISPLAY_NAME@', $PublisherDisplayName)
$manifest = $manifest.Replace('@MSIX_ARCH@', $Architecture)
Set-Content -Path (Join-Path $StagingDir 'AppxManifest.xml') -Value $manifest -Encoding utf8

if ($StageOnly) {
    Write-Output "Staged loose layout at: $StagingDir"
    return
}

# makeappx is a host tool: x64 runners ship only x64, arm64 runners ship arm64.
# Pick the build host's architecture (not the target $Architecture, which only
# affects the manifest ProcessorArchitecture above).
$hostArch = switch ($env:PROCESSOR_ARCHITECTURE) { 'ARM64' { 'arm64' } 'x86' { 'x86' } default { 'x64' } }
$makeappx = Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\bin\10.*\$hostArch\makeappx.exe" -ErrorAction SilentlyContinue |
    Sort-Object { [version]$_.Directory.Parent.Name } -Descending |
    Select-Object -First 1 -ExpandProperty FullName
if (-not $makeappx) {
    throw "makeappx.exe not found under '${env:ProgramFiles(x86)}\Windows Kits\10\bin\10.*\$hostArch' - install the Windows SDK"
}
Write-Output "Using makeappx: $makeappx"

& $makeappx pack /d $StagingDir /p $OutputPath /o
if ($LASTEXITCODE -ne 0) { throw "makeappx pack failed with exit code $LASTEXITCODE" }
Write-Output "Packed: $OutputPath"
