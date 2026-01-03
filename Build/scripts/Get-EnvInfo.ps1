#!/usr/bin/env pwsh
#requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$AsJson,
    [switch]$VerboseLogging
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

Import-Module (Join-Path -Path $scriptRoot -ChildPath 'modules/Logging.psm1') -Force -Verbose
# Import-Module (Join-Path -Path $scriptRoot -ChildPath 'modules/Toolchain.psm1') -Force -Verbose
Import-Module (Join-Path -Path $scriptRoot -ChildPath 'modules/vstools.psm1') -Force -Verbose

# Enable verbose console logging without writing a log file
if ($VerboseLogging) {
    Start-BuildLog -DisableFileLogging -EnableVerbose
}

$envInfo = Get-VisualStudioEnvironment

if (-not $envInfo) {
    Write-Host 'Visual Studio environment not detected.'
    exit 1
}

if ($AsJson) {
    $envInfo | ConvertTo-Json -Depth 5
    exit 0
}

# Present a readable summary to stdout
$formatted = [PSCustomObject]@{
    VSDisplayName   = $envInfo.VSDisplayName
    VSVersion       = $envInfo.VSVersion
    VSInstallPath   = $envInfo.VSInstallPath
    PlatformToolset = $envInfo.PlatformToolset
    MSVCVersion     = $envInfo.MSVCVersion
    WindowsSDKs     = ($envInfo.WindowsSDKs -join ', ')
    LatestSDK       = $envInfo.LatestSDK
    MSBuildPath     = $envInfo.MSBuildPath
    DotNetSDKs      = ($envInfo.DotNetSDKs -join '; ')
}

$formatted | Format-List
