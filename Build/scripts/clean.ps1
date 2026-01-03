#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Cleans build artifacts from the Cheat Engine project.

.DESCRIPTION
    Removes common build artifacts across the workspace while preserving
    essential pre-built binaries and libraries. Supports -WhatIf/-Confirm
    and emits verbose output when requested.

.PARAMETER Force
    Skip interactive confirmation prompts before deletion.

.PARAMETER ProtectBinaries
    When true, protect everything under 'Cheat Engine/bin' (recursively),
    preventing any files in that folder from being deleted by this cleanup.
    Defaults to true.

.PARAMETER DisplayAllFoundFiles
    When true, display the full list of matched files. Defaults to true.

.PARAMETER CleanSessions
    When true, also clean IDE session files (.lps). Defaults to false to preserve
    user settings and sessions.

.EXAMPLE
    .\clean.ps1
    Shows a summary and asks for confirmation before deletion.

.EXAMPLE
    .\clean.ps1 -Force -Verbose
    Deletes without prompting and shows verbose details.

.EXAMPLE
    .\clean.ps1 -WhatIf
    Shows what would be deleted without actually deleting.
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(HelpMessage = 'Skip interactive confirmation prompts before deletion')]
    [switch]$Force,

    [Parameter(HelpMessage = 'Protect everything under "Cheat Engine/bin" from deletion')]
    [bool]$ProtectBinaries = $true,

    [Parameter(HelpMessage = 'Display the full list of matched files')]
    [bool]$DisplayAllFoundFiles = $true,

    [Parameter(HelpMessage = 'Also clean IDE session files (.lps) - preserves sessions by default')]
    [bool]$CleanSessions = $false
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Get the workspace root (3 levels up from this script)
$scriptRoot = $PSScriptRoot
$workspaceRoot = Split-Path -Parent (Split-Path -Parent $scriptRoot)

Write-Verbose "Script location: $scriptRoot"
Write-Verbose "Workspace root: $workspaceRoot"

# Define build artifact patterns to clean
$buildArtifactPatterns = @(
    # Free Pascal / Lazarus build artifacts
    '*.ppu',        # Compiled unit files
    '*.ppl',        # Compiled library files
    '*.o',          # Object files
    '*.or',         # Object resource files
    '*.compiled',   # Compiled project markers
    '*.rsj',        # Resource string files (JSON)
    '*.lrj',        # Lazarus resource files (JSON)
    '*.bak',        # Backup files
    '*.~*',         # Backup files with tilde
    '*.a',          # Static libraries (Unix/GCC)
    '*.so',         # Shared libraries (Unix/Linux)
    '*.dll',        # Dynamic link libraries (generated)

    # Delphi build artifacts
    '*.dcu',        # Delphi compiled units

    # C/C++ build artifacts
    '*.obj',        # MSVC object files
    '*.iobj',       # MSVC incremental object files
    '*.ipdb',       # MSVC incremental PDB files
    '*.ilk',        # MSVC incremental link files
    '*.pch',        # Precompiled headers
    '*.pdb',        # Program database (debug symbols)
    '*.lib',        # Static libraries (intermediate)
    '*.exp',        # Export files
    '*.tlog',       # Build tracking logs
    '*.recipe',     # MSVC build recipe files
    '*.rsp',        # Response files

    # General temporary files
    '*.tmp',        # Temporary files
    '*.log',        # Log files
    '*.lock',       # Lock files
    '*~'            # Editor backup files
)

# Conditional patterns based on parameters
if ($CleanSessions) {
    $buildArtifactPatterns += '*.lps'  # Lazarus project session files
}

# Directories to clean entirely
$directoryPatterns = @(
    'Cheat Engine/lib',          # Lazarus/FPC output directory
    'backup',       # Lazarus backup directory
    '__history',    # Delphi history directory
    '__recovery',   # Delphi recovery directory
    'Debug',        # MSVC debug output
    'Release',      # MSVC release output
    'x64/Debug',    # MSVC x64 debug output
    'x64/Release',  # MSVC x64 release output
    'Win32/Debug',  # MSVC Win32 debug output
    'Win32/Release' # MSVC Win32 release output
)

Write-Host "`nScanning workspace for build artifacts..." -ForegroundColor Cyan

# Collect all files matching the patterns
$filesToDelete = [System.Collections.Generic.List[System.IO.FileInfo]]::new()

foreach ($pattern in $buildArtifactPatterns) {
    Write-Verbose "Searching for pattern: $pattern"
    $files = @(Get-ChildItem -Path $workspaceRoot -Filter $pattern -Recurse -File -ErrorAction SilentlyContinue)
    
    foreach ($file in $files) {
        $filesToDelete.Add($file)
    }
}

# Collect directories matching the patterns
$directoriesToDelete = [System.Collections.Generic.List[System.IO.DirectoryInfo]]::new()

foreach ($dirPattern in $directoryPatterns) {
    Write-Verbose "Searching for directory pattern: $dirPattern"
    
    # Handle nested path patterns (e.g., "x64/Debug")
    if ($dirPattern -match '/') {
        $parts = $dirPattern -split '/'
        $parentPattern = $parts[0]
        $childPattern = $parts[1]
        
        $parentDirs = @(Get-ChildItem -Path $workspaceRoot -Filter $parentPattern -Recurse -Directory -ErrorAction SilentlyContinue)
        foreach ($parentDir in $parentDirs) {
            $childDirs = @(Get-ChildItem -Path $parentDir.FullName -Filter $childPattern -Directory -ErrorAction SilentlyContinue)
            foreach ($childDir in $childDirs) {
                $directoriesToDelete.Add($childDir)
            }
        }
    }
    else {
        $dirs = @(Get-ChildItem -Path $workspaceRoot -Filter $dirPattern -Recurse -Directory -ErrorAction SilentlyContinue)
        foreach ($dir in $dirs) {
            $directoriesToDelete.Add($dir)
        }
    }
}

# Apply binary protection filter if enabled
if ($ProtectBinaries) {
    $binPath = Join-Path $workspaceRoot 'Cheat Engine' | Join-Path -ChildPath 'bin'
    
    if (Test-Path $binPath) {
        Write-Verbose "Binary protection enabled - filtering out files under: $binPath"
        
        $filesToDelete = $filesToDelete | Where-Object {
            -not $_.FullName.StartsWith($binPath, [StringComparison]::OrdinalIgnoreCase)
        }
        
        $directoriesToDelete = $directoriesToDelete | Where-Object {
            -not $_.FullName.StartsWith($binPath, [StringComparison]::OrdinalIgnoreCase)
        }
    }
}

# Remove duplicates (some files might match multiple patterns)
$filesToDelete = $filesToDelete | Sort-Object FullName -Unique
$directoriesToDelete = $directoriesToDelete | Sort-Object FullName -Unique

# Calculate statistics
$totalFiles = $filesToDelete.Count
$totalDirectories = $directoriesToDelete.Count
$totalSize = ($filesToDelete | Measure-Object -Property Length -Sum).Sum
$totalSizeMB = [math]::Round($totalSize / 1MB, 2)

# Display summary
Write-Host "`nCleanup Summary:" -ForegroundColor Yellow
Write-Host "  Files to delete:       $totalFiles" -ForegroundColor White
Write-Host "  Directories to delete: $totalDirectories" -ForegroundColor White
Write-Host "  Total size:            $totalSizeMB MB" -ForegroundColor White

if ($ProtectBinaries) {
    Write-Host "  Binary protection:     ENABLED (preserving 'Cheat Engine/bin')" -ForegroundColor Green
}
else {
    Write-Host "  Binary protection:     DISABLED" -ForegroundColor Yellow
}

# Display file list if requested
if ($DisplayAllFoundFiles -and ($totalFiles -gt 0 -or $totalDirectories -gt 0)) {
    Write-Host "`nFiles and directories to be removed:" -ForegroundColor Cyan
    
    if ($totalFiles -gt 0) {
        Write-Host "`n  Files:" -ForegroundColor White
        foreach ($file in $filesToDelete) {
            $relativePath = $file.FullName.Substring($workspaceRoot.Length + 1)
            $fileSizeKB = [math]::Round($file.Length / 1KB, 2)
            Write-Host "    $relativePath ($fileSizeKB KB)" -ForegroundColor Gray
        }
    }
    
    if ($totalDirectories -gt 0) {
        Write-Host "`n  Directories:" -ForegroundColor White
        foreach ($dir in $directoriesToDelete) {
            $relativePath = $dir.FullName.Substring($workspaceRoot.Length + 1)
            Write-Host "    $relativePath\" -ForegroundColor Gray
        }
    }
}

# Exit if nothing to delete
if ($totalFiles -eq 0 -and $totalDirectories -eq 0) {
    Write-Host "`nNo build artifacts found. Workspace is clean." -ForegroundColor Green
    exit 0
}

# Confirm deletion unless -Force is specified
if (-not $Force -and -not $PSCmdlet.ShouldProcess("$totalFiles files and $totalDirectories directories", "Delete")) {
    Write-Host "`nCleanup cancelled by user." -ForegroundColor Yellow
    exit 0
}

# Perform deletion
Write-Host "`nDeleting build artifacts..." -ForegroundColor Cyan

$deletedFiles = 0
$deletedDirectories = 0
$errors = [System.Collections.Generic.List[string]]::new()

# Delete files
foreach ($file in $filesToDelete) {
    try {
        if ($PSCmdlet.ShouldProcess($file.FullName, "Delete file")) {
            Remove-Item -Path $file.FullName -Force -ErrorAction Stop
            $deletedFiles++
            Write-Verbose "Deleted file: $($file.FullName)"
        }
    }
    catch {
        $errorMsg = "Failed to delete file '$($file.FullName)': $($_.Exception.Message)"
        $errors.Add($errorMsg)
        Write-Warning $errorMsg
    }
}

# Delete directories
foreach ($dir in $directoriesToDelete) {
    try {
        if ($PSCmdlet.ShouldProcess($dir.FullName, "Delete directory")) {
            Remove-Item -Path $dir.FullName -Recurse -Force -ErrorAction Stop
            $deletedDirectories++
            Write-Verbose "Deleted directory: $($dir.FullName)"
        }
    }
    catch {
        $errorMsg = "Failed to delete directory '$($dir.FullName)': $($_.Exception.Message)"
        $errors.Add($errorMsg)
        Write-Warning $errorMsg
    }
}

# Display results
Write-Host "`nCleanup complete!" -ForegroundColor Green
Write-Host "  Files deleted:       $deletedFiles / $totalFiles" -ForegroundColor White
Write-Host "  Directories deleted: $deletedDirectories / $totalDirectories" -ForegroundColor White

if ($errors.Count -gt 0) {
    Write-Host "`nEncountered $($errors.Count) error(s) during cleanup:" -ForegroundColor Red
    foreach ($error in $errors) {
        Write-Host "  - $error" -ForegroundColor Red
    }
    exit 1
}

Write-Host "`nWorkspace cleaned successfully!" -ForegroundColor Green
exit 0
