# Build script for Lazarus projects
# Builds: speedhack, luaclient, vehdebug DLLs (both 32-bit and 64-bit)
#         and main cheatengine.exe

param(
    [switch]$Clean,
    [switch]$Verbose,
    [string[]]$Projects = @(),  # Specific projects to build, or all if empty
    [switch]$SkipCheatEngine,   # Skip building main cheatengine.exe
    [switch]$SkipExisting = $true
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir | Split-Path -Parent
$CheatEngineDir = Join-Path $RootDir "Cheat Engine"
$BinDir = Join-Path $CheatEngineDir "bin"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Building Lazarus Projects" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Find lazbuild
$LazarusPath = "C:\lazarus"
$Lazbuild = Join-Path $LazarusPath "lazbuild.exe"

if (-not (Test-Path $Lazbuild)) {
    # Try to find in Program Files
    $PossiblePaths = @(
        "C:\Program Files\Lazarus\lazbuild.exe",
        "C:\Program Files (x86)\Lazarus\lazbuild.exe",
        "${env:ProgramFiles}\Lazarus\lazbuild.exe",
        "${env:ProgramFiles(x86)}\Lazarus\lazbuild.exe"
    )
    
    foreach ($path in $PossiblePaths) {
        if (Test-Path $path) {
            $Lazbuild = $path
            break
        }
    }
}

if (-not (Test-Path $Lazbuild)) {
    Write-Error "lazbuild.exe not found. Please install Lazarus or set the correct path."
    Write-Host "Expected location: $Lazbuild" -ForegroundColor Yellow
    Write-Host "Please install Lazarus 2.2.2 from https://sourceforge.net/projects/lazarus/" -ForegroundColor Yellow
    exit 1
}

Write-Host "Using Lazbuild: $Lazbuild" -ForegroundColor Green

# Define all Lazarus projects
$AllProjects = @{
    "speedhack" = @{
        Name = "SpeedHack"
        ProjectFile = Join-Path $CheatEngineDir "speedhack\speedhack.lpi"
        Targets = @(
            @{CPU = "i386"; OS = "win32"; Output = "speedhack.dll"; Dest = "bin\speedhack.dll"},
            @{CPU = "x86_64"; OS = "win64"; Output = "speedhack.dll"; Dest = "bin\speedhack64.dll"}
        )
    }
    "luaclient" = @{
        Name = "LuaClient"
        ProjectFile = Join-Path $CheatEngineDir "luaclient\luaclient.lpi"
        Targets = @(
            @{CPU = "i386"; OS = "win32"; Output = "luaclient.dll"; Dest = "bin\luaclient.dll"},
            @{CPU = "x86_64"; OS = "win64"; Output = "luaclient.dll"; Dest = "bin\luaclient64.dll"}
        )
    }
    "vehdebug" = @{
        Name = "VEH Debug"
        ProjectFile = Join-Path $CheatEngineDir "VEHDebug\vehdebug.lpi"
        Targets = @(
            @{CPU = "i386"; OS = "win32"; Output = "vehdebug.dll"; Dest = "bin\vehdebug.dll"},
            @{CPU = "x86_64"; OS = "win64"; Output = "vehdebug.dll"; Dest = "bin\vehdebug64.dll"}
        )
    }
}

# Filter projects if specific ones requested
if ($Projects.Count -gt 0) {
    $ProjectsToBuild = @{}
    foreach ($p in $Projects) {
        if ($AllProjects.ContainsKey($p)) {
            $ProjectsToBuild[$p] = $AllProjects[$p]
        } else {
            Write-Warning "Unknown project: $p. Skipping."
        }
    }
} else {
    $ProjectsToBuild = $AllProjects
}

# Build each project
$BuildResults = @{}
foreach ($projectKey in $ProjectsToBuild.Keys) {
    $project = $ProjectsToBuild[$projectKey]
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Building: $($project.Name)" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    if (-not (Test-Path $project.ProjectFile)) {
        Write-Warning "Project file not found: $($project.ProjectFile)"
        $BuildResults[$projectKey] = "SKIPPED"
        continue
    }
    
    # Check if all outputs already exist
    if ($SkipExisting -and -not $Clean) {
        $AllOutputsExist = $true
        foreach ($target in $project.Targets) {
            $destPath = Join-Path $CheatEngineDir $target.Dest
            if (-not (Test-Path $destPath)) {
                $AllOutputsExist = $false
                break
            }
        }
        
        if ($AllOutputsExist) {
            Write-Host "All outputs for $($project.Name) already exist. Skipping build." -ForegroundColor Green
            $BuildResults[$projectKey] = "SKIPPED (EXISTS)"
            continue
        }
    }
    
    try {
        foreach ($target in $project.Targets) {
            $targetName = "$($target.CPU)-$($target.OS)"
            Write-Host "`nBuilding target: $targetName" -ForegroundColor Yellow
            
            # Build arguments
            $buildArgs = @(
                "--build-mode=Release",
                "--cpu=$($target.CPU)",
                "--os=$($target.OS)",
                "--build-all",
                $project.ProjectFile
            )
            
            if ($Verbose) {
                $buildArgs += "--verbose"
            } else {
                $buildArgs += "--quiet"
            }
            
            # Clean if requested
            if ($Clean) {
                Write-Host "  Cleaning..." -ForegroundColor Gray
                $cleanArgs = @("--build-mode=Release", "--cpu=$($target.CPU)", "--os=$($target.OS)") + $project.ProjectFile
                & $Lazbuild $cleanArgs 2>&1 | Out-Null
            }
            
            # Build
            Write-Host "  Building..." -ForegroundColor Gray
            $output = & $Lazbuild $buildArgs 2>&1
            
            if ($LASTEXITCODE -ne 0) {
                Write-Host $output -ForegroundColor Red
                throw "Build failed with exit code $LASTEXITCODE"
            }
            
            # Copy output to destination
            $projectDir = Split-Path -Parent $project.ProjectFile
            $outputPath = Join-Path $projectDir $target.Output
            
            # Also check in lib subdirectory (common Lazarus output location)
            if (-not (Test-Path $outputPath)) {
                $libPath = Join-Path $projectDir "lib\$($target.CPU)-$($target.OS)\$($target.Output)"
                if (Test-Path $libPath) {
                    $outputPath = $libPath
                }
            }
            
            if (Test-Path $outputPath) {
                $destPath = Join-Path $CheatEngineDir $target.Dest
                $destDir = Split-Path -Parent $destPath
                
                if (-not (Test-Path $destDir)) {
                    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                }
                
                Copy-Item $outputPath $destPath -Force
                Write-Host "  ✓ Copied to $(Split-Path -Leaf $destPath)" -ForegroundColor Green
            } else {
                Write-Warning "  ✗ Output file not found: $outputPath"
            }
        }
        
        $BuildResults[$projectKey] = "SUCCESS"
        Write-Host "`n✓ $($project.Name) built successfully!" -ForegroundColor Green
        
    } catch {
        Write-Error "Failed to build $($project.Name): $_"
        $BuildResults[$projectKey] = "FAILED"
    }
}

# Build main Cheat Engine executable (if not skipped)
if (-not $SkipCheatEngine) {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Building: Cheat Engine (Main Application)" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    $MainProjectFile = Join-Path $CheatEngineDir "cheatengine.lpi"
    
    if (Test-Path $MainProjectFile) {
        # Check if cheatengine.exe already exists
        if ($SkipExisting -and -not $Clean) {
            $exePath = Join-Path $BinDir "cheatengine.exe"
            if (Test-Path $exePath) {
                Write-Host "`nCheat Engine executable already exists. Skipping build." -ForegroundColor Green
                Write-Host "Use -Clean or set `$SkipExisting = `$false to force rebuild." -ForegroundColor Yellow
                $BuildResults["CheatEngine"] = "SKIPPED (EXISTS)"
                continue
            }
        }
        
        try {
            Write-Host "`nBuilding Cheat Engine executable..." -ForegroundColor Yellow
            
            # Build main application (typically 64-bit, but can build multiple modes)
            $buildModes = @("Release", "Release32", "Release64")  # Common build modes
            $builtSuccessfully = $false
            
            foreach ($mode in $buildModes) {
                Write-Host "  Attempting build mode: $mode" -ForegroundColor Gray
                
                $buildArgs = @(
                    "--build-mode=$mode",
                    "--build-all"
                )
                
                if (-not $Verbose) {
                    $buildArgs += "--quiet"
                }
                
                $buildArgs += $MainProjectFile
                
                $output = & $Lazbuild $buildArgs 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    $builtSuccessfully = $true
                    Write-Host "  ✓ Built with mode: $mode" -ForegroundColor Green
                    break
                }
            }
            
            if ($builtSuccessfully) {
                $BuildResults["CheatEngine"] = "SUCCESS"
                Write-Host "`n✓ Cheat Engine built successfully!" -ForegroundColor Green
                Write-Host "Note: Run from Lazarus IDE or compile all modes for complete build" -ForegroundColor Yellow
            } else {
                Write-Warning "Could not build Cheat Engine with standard build modes"
                Write-Host "Tip: Open cheatengine.lpi in Lazarus and use Run->Compile many Modes" -ForegroundColor Yellow
                $BuildResults["CheatEngine"] = "PARTIAL"
            }
            
        } catch {
            Write-Error "Failed to build Cheat Engine: $_"
            $BuildResults["CheatEngine"] = "FAILED"
        }
    } else {
        Write-Warning "Main project file not found: $MainProjectFile"
        $BuildResults["CheatEngine"] = "SKIPPED"
    }
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Build Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

foreach ($projectKey in $BuildResults.Keys) {
    $status = $BuildResults[$projectKey]
    $color = switch ($status) {
        "SUCCESS" { "Green" }
        "FAILED" { "Red" }
        "SKIPPED" { "Yellow" }
        "PARTIAL" { "Yellow" }
    }
    Write-Host "$projectKey : $status" -ForegroundColor $color
}

# Check if any builds failed
$failedBuilds = $BuildResults.Values | Where-Object { $_ -eq "FAILED" }
if ($failedBuilds.Count -gt 0) {
    Write-Host "`nSome builds failed. Check the output above for details." -ForegroundColor Red
    exit 1
} else {
    Write-Host "`nAll Lazarus builds completed successfully!" -ForegroundColor Green
}
