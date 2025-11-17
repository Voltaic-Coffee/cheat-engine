# Master Build Script for Cheat Engine
# Orchestrates the complete build process for all components

param(
    [switch]$Clean,
    [switch]$Verbose,
    [switch]$SkipLua,
    [switch]$SkipVSProjects,
    [switch]$SkipLazarus,
    [switch]$SkipDependencies,
    [switch]$SkipCheatEngine,
    [string[]]$Only = @(),  # Build only specific components: lua, vs, lazarus, dependencies, cheatengine
    [switch]$SkipExisting = $true
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BuildDir = Split-Path -Parent $ScriptDir

# Load configuration from build-config.local.ps1 or build-config.template.ps1
$ConfigFile = Join-Path (Join-Path $BuildDir "config") "build-config.local.ps1"
if (-not (Test-Path $ConfigFile)) {
    $ConfigFile = Join-Path (Join-Path $BuildDir "config") "build-config.template.ps1"
}

if (Test-Path $ConfigFile) {
    . $ConfigFile
    # Override with script parameter if explicitly provided
    if ($PSBoundParameters.ContainsKey('SkipExisting')) {
        # Use the parameter value
    } elseif (Get-Variable -Name 'SkipExisting' -Scope Script -ErrorAction SilentlyContinue) {
        # Use config file value
        $script:SkipExisting = $SkipExisting
    }
}

Write-Host @"
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║                    CHEAT ENGINE - MASTER BUILD SCRIPT                        ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

Write-Host ""
Write-Host "Build started at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Determine what to build
$BuildAll = ($Only.Count -eq 0)
$BuildLua = $BuildAll -and -not $SkipLua
$BuildVS = $BuildAll -and -not $SkipVSProjects
$BuildLazarus = $BuildAll -and -not $SkipLazarus
$BuildDeps = $BuildAll -and -not $SkipDependencies
$BuildCE = $BuildAll -and -not $SkipCheatEngine

if ($Only.Count -gt 0) {
    $BuildLua = $Only -contains "lua"
    $BuildVS = $Only -contains "vs"
    $BuildLazarus = $Only -contains "lazarus"
    $BuildDeps = $Only -contains "dependencies"
    $BuildCE = $Only -contains "cheatengine"
}

# Build summary
$BuildResults = @{}
$StartTime = Get-Date

# Helper function to run a build script
function Invoke-BuildScript {
    param(
        [string]$ScriptName,
        [string]$DisplayName,
        [hashtable]$Parameters = @{}
    )
    
    $scriptPath = Join-Path $ScriptDir $ScriptName
    
    Write-Host "╔══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║ Building: $DisplayName" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    try {
        $params = @{}
        if ($Clean) { $params['Clean'] = $true }
        if ($Verbose) { $params['Verbose'] = $true }
        if ($SkipExisting) { $params['SkipExisting'] = $true }
        
        # Merge additional parameters
        foreach ($key in $Parameters.Keys) {
            $params[$key] = $Parameters[$key]
        }
        
        & $scriptPath @params
        
        if ($LASTEXITCODE -ne 0) {
            throw "Build script exited with code $LASTEXITCODE"
        }
        
        return "SUCCESS"
    } catch {
        Write-Host ""
        Write-Host "ERROR: Failed to build $DisplayName" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        return "FAILED"
    }
}

# Build Lua 5.3 components
if ($BuildLua) {
    $BuildResults["Lua 5.3"] = Invoke-BuildScript -ScriptName "build-lua53.ps1" -DisplayName "Lua 5.3 Components"
    Write-Host ""
}

# Build Visual Studio projects
if ($BuildVS) {
    $BuildResults["Visual Studio Projects"] = Invoke-BuildScript -ScriptName "build-vs-projects.ps1" -DisplayName "Visual Studio Projects"
    Write-Host ""
}

# Build Lazarus projects (DLLs)
if ($BuildLazarus) {
    $params = @{}
    if ($SkipCheatEngine) {
        $params['SkipCheatEngine'] = $true
    }
    
    $BuildResults["Lazarus DLL Projects"] = Invoke-BuildScript -ScriptName "build-lazarus-projects.ps1" -DisplayName "Lazarus DLL Projects" -Parameters $params
    Write-Host ""
}

# Build main Cheat Engine executable (if not already built by Lazarus script)
if ($BuildCE -and -not $BuildLazarus) {
    $BuildResults["Cheat Engine"] = Invoke-BuildScript -ScriptName "build-lazarus-projects.ps1" -DisplayName "Cheat Engine Main Application" -Parameters @{Projects = @(); SkipCheatEngine = $false}
    Write-Host ""
}

# Build dependencies (TCC, LFS, etc.)
if ($BuildDeps) {
    $BuildResults["Dependencies"] = Invoke-BuildScript -ScriptName "build-dependencies.ps1" -DisplayName "TCC and Dependencies"
    Write-Host ""
}

# Calculate total build time
$EndTime = Get-Date
$BuildDuration = $EndTime - $StartTime

# Print final summary
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                            BUILD SUMMARY                                     ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

if ($BuildResults.Count -eq 0) {
    Write-Host "No components were built (all skipped or filtered)." -ForegroundColor Yellow
} else {
    foreach ($component in $BuildResults.Keys) {
        $status = $BuildResults[$component]
        $statusColor = if ($status -eq "SUCCESS") { "Green" } else { "Red" }
        $statusSymbol = if ($status -eq "SUCCESS") { "✓" } else { "✗" }
        
        Write-Host "  $statusSymbol " -NoNewline -ForegroundColor $statusColor
        Write-Host "$component : " -NoNewline
        Write-Host "$status" -ForegroundColor $statusColor
    }
}

Write-Host ""
Write-Host "Build Duration: $($BuildDuration.ToString('hh\:mm\:ss'))" -ForegroundColor Gray
Write-Host "Completed at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Check for failures
$failures = $BuildResults.Values | Where-Object { $_ -eq "FAILED" }
if ($failures.Count -gt 0) {
    Write-Host "╔══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║                         BUILD COMPLETED WITH ERRORS                          ║" -ForegroundColor Red
    Write-Host "╚══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
    Write-Host "Some components failed to build. Please review the output above." -ForegroundColor Red
    Write-Host "For troubleshooting, see: Build\docs\TROUBLESHOOTING.md" -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "╔══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║                        BUILD COMPLETED SUCCESSFULLY!                         ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "All components built successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Review build output in 'Cheat Engine\bin\' directory" -ForegroundColor Gray
    Write-Host "  2. Run Cheat Engine from Lazarus IDE or the compiled executable" -ForegroundColor Gray
    Write-Host "  3. For distribution guidance, see: Build\README.md" -ForegroundColor Gray
    Write-Host ""
}
