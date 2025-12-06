#requires -Version 5.1
Set-StrictMode -Version Latest

$script:LogFilePath = $null
$script:VerboseLoggingEnabled = $false
$script:LogRotationSettings = @{
    EnableRotation      = $true
    MaxFileSizeBytes    = 5MB
    MaxRetainedFiles    = 3
    MinFreeDiskSpaceMB  = 100
}
$script:LogLevels = @{
    INFO    = 'INFO '
    WARN    = 'WARN '
    ERROR   = 'ERROR'
    SUCCESS = 'OK   '
    DEBUG   = 'DEBUG'
}

function Start-BuildLog {
    [CmdletBinding()]
    param(
        [string]$LogDirectory,
        [string]$FileNamePrefix = 'build',
        [switch]$DisableFileLogging,
        [string]$LogSettingsPath,
        [switch]$EnableVerbose
    )

    $script:VerboseLoggingEnabled = $EnableVerbose

    if ($DisableFileLogging) {
        $script:LogFilePath = $null
        return
    }

    # Override defaults with settings from config file if provided
    if ($LogSettingsPath) {
        if (-not (Test-Path -LiteralPath $LogSettingsPath)) {
            throw "Log settings file not found at $LogSettingsPath"
        }

        $settings = Get-Content -LiteralPath $LogSettingsPath -Raw | ConvertFrom-Json

        $script:LogRotationSettings = @{
            EnableRotation      = if ($null -ne $settings.EnableRotation) { [bool]$settings.EnableRotation } else { $script:LogRotationSettings.EnableRotation }
            MaxFileSizeBytes    = if ($settings.MaxFileSizeMB) { [int64]$settings.MaxFileSizeMB * 1MB } else { $script:LogRotationSettings.MaxFileSizeBytes }
            MaxRetainedFiles    = if ($settings.MaxRetainedFiles) { [int]$settings.MaxRetainedFiles } else { $script:LogRotationSettings.MaxRetainedFiles }
            MinFreeDiskSpaceMB  = if ($settings.MinFreeDiskSpaceMB) { [int64]$settings.MinFreeDiskSpaceMB } else { $script:LogRotationSettings.MinFreeDiskSpaceMB }
        }
    }

    if (-not $LogDirectory) {
        throw 'LogDirectory must be provided when file logging is enabled.'
    }

    if (-not (Test-Path -LiteralPath $LogDirectory)) {
        $null = New-Item -Path $LogDirectory -ItemType Directory -Force
    }

    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $fileName = '{0}_{1}.log' -f $FileNamePrefix, $timestamp
    $script:LogFilePath = Join-Path -Path $LogDirectory -ChildPath $fileName

    # Enforce retention policy on startup (keep MaxRetainedFiles total including the new one)
    if ($script:LogRotationSettings -and $script:LogRotationSettings.EnableRotation) {
        $maxFiles = $script:LogRotationSettings.MaxRetainedFiles
        if ($maxFiles -gt 0) {
            $pattern = "{0}_*.log" -f $FileNamePrefix
            $existingFiles = Get-ChildItem -LiteralPath $LogDirectory -Filter $pattern -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
            # Skip (MaxRetainedFiles - 1) to account for the new log file we're about to create
            $toRemove = $existingFiles | Select-Object -Skip ($maxFiles - 1)
            foreach ($f in $toRemove) {
                try { Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue } catch {}
            }
        }
    }
}

function Stop-BuildLog {
    [CmdletBinding()]
    param()

    $script:LogFilePath = $null
}

function Write-BuildLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [ValidateSet('INFO','WARN','ERROR','SUCCESS','DEBUG')]
        [string]$Level = 'INFO'
    )

    # Skip DEBUG messages unless verbose logging is enabled
    if ($Level -eq 'DEBUG' -and -not $script:VerboseLoggingEnabled) {
        return
    }

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $tag = $script:LogLevels[$Level]
    $formatted = '[{0}] [{1}] {2}' -f $timestamp, $tag, $Message

    switch ($Level) {
        'ERROR'   { Write-Error -Message $formatted }
        'WARN'    { Write-Warning -Message $formatted }
        'SUCCESS' { Write-Host $formatted -ForegroundColor Green }
        'DEBUG'   { Write-Host $formatted -ForegroundColor DarkGray }
        default   { Write-Host $formatted }
    }

    if ($script:LogFilePath) {
        Invoke-LogRotationIfNeeded
        Add-Content -LiteralPath $script:LogFilePath -Value $formatted
    }
}

function Invoke-LogRotationIfNeeded {
    [CmdletBinding()]
    param()

    if (-not $script:LogRotationSettings.EnableRotation) {
        return
    }

    if (-not $script:LogFilePath) {
        return
    }

    if (-not (Test-Path -LiteralPath $script:LogFilePath)) {
        return
    }

    try {
        $fileInfo = Get-Item -LiteralPath $script:LogFilePath
    }
    catch {
        return
    }

    $maxSize = $script:LogRotationSettings.MaxFileSizeBytes
    if ($fileInfo.Length -lt $maxSize) {
        return
    }

    $logDir = Split-Path -Parent $script:LogFilePath
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($script:LogFilePath)
    $ext = [System.IO.Path]::GetExtension($script:LogFilePath)

    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $rotatedName = '{0}.{1}{2}' -f $baseName, $timestamp, $ext
    $rotatedPath = Join-Path -Path $logDir -ChildPath $rotatedName

    # Check free disk space before rotating
    $driveRoot = [System.IO.Path]::GetPathRoot($logDir)
    try {
        $drive = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID = '$driveRoot'"
        if ($drive.FreeSpace -lt ($script:LogRotationSettings.MinFreeDiskSpaceMB * 1MB)) {
            # Not enough disk space; stop file logging
            $script:LogFilePath = $null
            return
        }
    }
    catch {
        # If disk query fails, continue rotation without the check
    }

    try {
        Move-Item -LiteralPath $script:LogFilePath -Destination $rotatedPath -Force
    }
    catch {
        return
    }

    # Enforce retention policy
    $maxFiles = $script:LogRotationSettings.MaxRetainedFiles
    if ($maxFiles -gt 0) {
        $pattern = "{0}*{1}" -f $baseName, $ext
        $files = Get-ChildItem -LiteralPath $logDir -Filter $pattern | Sort-Object LastWriteTime -Descending
        $toRemove = $files | Select-Object -Skip $maxFiles
        foreach ($f in $toRemove) {
            try { Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue } catch {}
        }
    }
}

function Write-BuildSection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Title
    )

    $line = ('=' * 10) + ' ' + $Title + ' '
    Write-BuildLog -Message $line -Level 'INFO'
}

function Get-BuildLogFilePath {
    [CmdletBinding()]
    param()

    return $script:LogFilePath
}

Export-ModuleMember -Function Start-BuildLog, Stop-BuildLog, Write-BuildLog, Write-BuildSection, Get-BuildLogFilePath, Invoke-LogRotationIfNeeded
