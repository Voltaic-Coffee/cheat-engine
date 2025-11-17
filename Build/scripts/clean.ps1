#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Cleans build artifacts from the Cheat Engine project.

.DESCRIPTION
    This script removes build artifacts matching specific patterns while preserving
    essential pre-built binaries and libraries that are part of the source distribution.

.PARAMETER Force
    Skip confirmation prompts and proceed with deletion.

.EXAMPLE
    .\clean.ps1
    Removes build artifacts with confirmation.

.EXAMPLE
    .\clean.ps1 -Force
    Removes build artifacts without confirmation.
#>

param(
    [switch]$Force
)

# Display all found files
$DisplayAllFoundFiles = $true

# Set error action preference
$ErrorActionPreference = "Stop"

# Get the root directory of the project (parent of build folder)
$RootDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

Write-Host "Cheat Engine Build Cleanup" -ForegroundColor Cyan
Write-Host "Root directory: $RootDir" -ForegroundColor Gray
Write-Host ""

# Define file patterns to remove
$PatternsToRemove = @(
    "*.bak",
    "*.ppu",
    "*.ppl",
    "*.o",
    "*.or",
    "*.a",
    "*.so",
    "*.dll",
    "*.recipe",
    "*.lock",
    "*.obj",
    "*.tlog",
    "*.iobj",
    "*.ipdb",
    "*.rsp"
)

# Define files that should NEVER be removed (relative to root)
$ProtectedFiles = @(
    "Cheat Engine/bin/lua_extra/lua.exe",
    "Cheat Engine/bin/lua_extra/luac32.exe",
    "Cheat Engine/bin/lua_extra/luac64.exe",
    "Cheat Engine/bin/CED3D10Hook.dll",
    "Cheat Engine/bin/CED3D10Hook64.dll",
    "Cheat Engine/bin/CED3D11Hook.dll",
    "Cheat Engine/bin/CED3D11Hook64.dll",
    "Cheat Engine/bin/autorun/dlls/32/CEJVMTI.dll",
    "Cheat Engine/bin/autorun/dlls/64/CEJVMTI.dll",
    "Cheat Engine/bin/ced3d9hook.dll",
    "Cheat Engine/bin/ced3d9hook64.dll",
    "Cheat Engine/bin/clibs32/lfs.dll",
    "Cheat Engine/bin/clibs64/lfs.dll",
    "Cheat Engine/bin/d3dhook.dll",
    "Cheat Engine/bin/d3dhook64.dll",
    "Cheat Engine/bin/libipt-32.dll",
    "Cheat Engine/bin/libipt-64.dll",
    "Cheat Engine/bin/libmikmod32.dll",
    "Cheat Engine/bin/libmikmod64.dll",
    "Cheat Engine/bin/lua53-32.dll",
    "Cheat Engine/bin/lua53-64.dll",
    "Cheat Engine/bin/win32/dbghelp.dll",
    "Cheat Engine/bin/win32/sqlite3.dll",
    "Cheat Engine/bin/win32/symsrv.dll",
    "Cheat Engine/bin/win64/dbghelp.dll",
    "Cheat Engine/bin/win64/old/dbghelp.dll",
    "Cheat Engine/bin/win64/old/symsrv.dll",
    "Cheat Engine/bin/win64/sqlite3.dll",
    "Cheat Engine/bin/win64/symsrv.dll",
    "Cheat Engine/bin/lua_extra/lua53-32.lib",
    "Cheat Engine/bin/lua_extra/lua53-64.lib",
    "Cheat Engine/plugin/lua53-32.lib",
    "Cheat Engine/plugin/lua53-64.lib"
)

# Convert protected files to absolute paths and normalize
$ProtectedFileSet = @{}
foreach ($file in $ProtectedFiles) {
    $absolutePath = Join-Path $RootDir $file
    $normalizedPath = [System.IO.Path]::GetFullPath($absolutePath).ToLowerInvariant()
    $ProtectedFileSet[$normalizedPath] = $true
}

# Function to check if a file is protected
function Test-Protected {
    param([string]$FilePath)
    
    $normalizedPath = [System.IO.Path]::GetFullPath($FilePath).ToLowerInvariant()
    return $ProtectedFileSet.ContainsKey($normalizedPath)
}

# Collect files to remove
Write-Host "Scanning for build artifacts..." -ForegroundColor Yellow

$FilesToRemove = @()

foreach ($pattern in $PatternsToRemove) {
    Write-Host "  Searching for: $pattern" -ForegroundColor Gray
    
    $foundFiles = Get-ChildItem -Path $RootDir -Filter $pattern -Recurse -File -ErrorAction SilentlyContinue
    
    foreach ($file in $foundFiles) {
        if (-not (Test-Protected $file.FullName)) {
            $FilesToRemove += $file
        }
        else {
            Write-Host "    [PROTECTED] Skipping: $($file.FullName.Substring($RootDir.Length + 1))" -ForegroundColor DarkGray
        }
    }
}

# Remove duplicates (in case a file matches multiple patterns)
$FilesToRemove = $FilesToRemove | Sort-Object -Property FullName -Unique

# Display summary
Write-Host ""
Write-Host "Found $($FilesToRemove.Count) file(s) to remove" -ForegroundColor Cyan
Write-Host ""

if ($FilesToRemove.Count -eq 0) {
    Write-Host "No build artifacts found. Project is already clean!" -ForegroundColor Green
    exit 0
}

# Show files that will be removed (limit to first 50 for readability)
if ($FilesToRemove.Count -le 50 -or $DisplayAllFoundFiles) {
    foreach ($file in $FilesToRemove) {
        $relativePath = $file.FullName.Substring($RootDir.Length + 1)
        Write-Host "  - $relativePath" -ForegroundColor DarkYellow
    }
}
else {
    # Show first 25 and last 25
    for ($i = 0; $i -lt 25; $i++) {
        $relativePath = $FilesToRemove[$i].FullName.Substring($RootDir.Length + 1)
        Write-Host "  - $relativePath" -ForegroundColor DarkYellow
    }
    Write-Host "  ... ($($FilesToRemove.Count - 50) more files) ..." -ForegroundColor DarkGray
    for ($i = $FilesToRemove.Count - 25; $i -lt $FilesToRemove.Count; $i++) {
        $relativePath = $FilesToRemove[$i].FullName.Substring($RootDir.Length + 1)
        Write-Host "  - $relativePath" -ForegroundColor DarkYellow
    }
}

Write-Host ""

# Calculate total size
$totalSize = ($FilesToRemove | Measure-Object -Property Length -Sum).Sum
$totalSizeMB = [math]::Round($totalSize / 1MB, 2)
Write-Host "Total size to be freed: $totalSizeMB MB" -ForegroundColor Cyan
Write-Host ""

# Confirm deletion unless -Force is specified
if (-not $Force) {
    $response = Read-Host "Do you want to proceed with deletion? (y/N)"
    if ($response -notmatch "^[Yy]") {
        Write-Host "Cleanup cancelled." -ForegroundColor Yellow
        exit 0
    }
}

# Perform deletion
Write-Host "Removing files..." -ForegroundColor Yellow

$successCount = 0
$failCount = 0
$errors = @()

foreach ($file in $FilesToRemove) {
    try {
        Remove-Item -Path $file.FullName -Force -ErrorAction Stop
        $successCount++
        
        # Show progress every 100 files
        if ($successCount % 100 -eq 0) {
            Write-Host "  Removed $successCount files..." -ForegroundColor Gray
        }
    }
    catch {
        $failCount++
        $relativePath = $file.FullName.Substring($RootDir.Length + 1)
        $errors += "Failed to remove: $relativePath - $($_.Exception.Message)"
    }
}

# Display results
Write-Host ""
Write-Host "Cleanup complete!" -ForegroundColor Green
Write-Host "  Successfully removed: $successCount file(s)" -ForegroundColor Green
Write-Host "  Failed to remove: $failCount file(s)" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Gray" })
Write-Host "  Space freed: $totalSizeMB MB" -ForegroundColor Cyan

# Show errors if any
if ($errors.Count -gt 0) {
    Write-Host ""
    Write-Host "Errors encountered:" -ForegroundColor Red
    foreach ($error in $errors) {
        Write-Host "  $error" -ForegroundColor DarkRed
    }
}

Write-Host ""
