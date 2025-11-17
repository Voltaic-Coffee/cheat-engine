# Build script for Visual Studio projects
# Builds: DirectXMess, DotNetCompiler, MonoDataCollector, DotNetDataCollector,
#         DotNetInvasiveDataCollector, CEJVMTI, DBKKernel

param(
    [switch]$Clean,
    [switch]$Verbose,
    [string[]]$Projects = @(),  # Specific projects to build, or all if empty
    [switch]$SkipExisting = $true
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir | Split-Path -Parent
$CheatEngineDir = Join-Path $RootDir "Cheat Engine"
$BinDir = Join-Path $CheatEngineDir "bin"
$DBKKernelDir = Join-Path $RootDir "DBKKernel"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Building Visual Studio Projects" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Find MSBuild
$MSBuild = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -latest -requires Microsoft.Component.MSBuild -find MSBuild\**\Bin\MSBuild.exe -prerelease | Select-Object -First 1

if (-not $MSBuild) {
    Write-Error "MSBuild not found. Please install Visual Studio 2017 or later."
    exit 1
}

Write-Host "Using MSBuild: $MSBuild" -ForegroundColor Green

# Define all projects
$AllProjects = @{
    "DirectXMess" = @{
        Name = "Direct X Mess"
        Solution = Join-Path $CheatEngineDir "Direct x mess\Direct x mess.sln"
        Platforms = @("Win32", "x64")
        Outputs = @{
            Win32 = @(
                @{Src = "Direct x mess\Release\CED3D9Hook.dll"; Dst = "bin\ced3d9hook.dll"},
                @{Src = "Direct x mess\Release\CED3D10Hook.dll"; Dst = "bin\CED3D10Hook.dll"},
                @{Src = "Direct x mess\Release\CED3D11Hook.dll"; Dst = "bin\CED3D11Hook.dll"},
                @{Src = "Direct x mess\Release\d3dhook.dll"; Dst = "bin\d3dhook.dll"}
            )
            x64 = @(
                @{Src = "Direct x mess\x64\Release\CED3D9Hook.dll"; Dst = "bin\ced3d9hook64.dll"},
                @{Src = "Direct x mess\x64\Release\CED3D10Hook.dll"; Dst = "bin\CED3D10Hook64.dll"},
                @{Src = "Direct x mess\x64\Release\CED3D11Hook.dll"; Dst = "bin\CED3D11Hook64.dll"},
                @{Src = "Direct x mess\x64\Release\d3dhook.dll"; Dst = "bin\d3dhook64.dll"}
            )
        }
    }
    "DotNetCompiler" = @{
        Name = "DotNetCompiler"
        Solution = Join-Path $CheatEngineDir "DotNetCompiler\CSCompiler\CSCompiler.sln"
        Platforms = @("Any CPU")
        Outputs = @{
            "Any CPU" = @(
                @{Src = "DotNetCompiler\CSCompiler\bin\Release\CSCompiler.exe"; Dst = "bin\CSCompiler.exe"}
            )
        }
    }
    "MonoDataCollector" = @{
        Name = "MonoDataCollector"
        Solution = Join-Path $CheatEngineDir "MonoDataCollector\MonoDataCollector.sln"
        Platforms = @("Win32", "x64")
        Outputs = @{
            Win32 = @(
                @{Src = "MonoDataCollector\Release\MonoDataCollector.dll"; Dst = "bin\MonoDataCollector.dll"}
            )
            x64 = @(
                @{Src = "MonoDataCollector\x64\Release\MonoDataCollector.dll"; Dst = "bin\MonoDataCollector64.dll"}
            )
        }
    }
    "DotNetDataCollector" = @{
        Name = "DotNetDataCollector"
        Solution = Join-Path $CheatEngineDir "DotNetDataCollector\DotNetDataCollector.sln"
        Platforms = @("x86", "x64")
        Outputs = @{
            x86 = @(
                @{Src = "DotNetDataCollector\DotNetDataCollector\bin\Release\DotNetDataCollector.exe"; Dst = "bin\DotNetDataCollector.exe"}
            )
            x64 = @(
                @{Src = "DotNetDataCollector\DotNetDataCollector\bin\x64\Release\DotNetDataCollector.exe"; Dst = "bin\DotNetDataCollector64.exe"}
            )
        }
    }
    "DotNetInvasiveDataCollector" = @{
        Name = "DotNetInvasiveDataCollector"
        Solution = Join-Path $CheatEngineDir "DotNetInvasiveDataCollector\DotNetInvasiveDataCollector.sln"
        Platforms = @("Any CPU")
        Outputs = @{
            "Any CPU" = @(
                @{Src = "DotNetInvasiveDataCollector\DotNetInvasiveDataCollector\bin\Release\DotNetInvasiveDataCollector.dll"; Dst = "bin\DotNetInvasiveDataCollector.dll"}
            )
        }
    }
    "CEJVMTI" = @{
        Name = "CEJVMTI"
        Solution = Join-Path $CheatEngineDir "Java\CEJVMTI\CEJVMTI.sln"
        Platforms = @("Win32", "x64")
        Outputs = @{
            Win32 = @(
                @{Src = "Java\CEJVMTI\Release\CEJVMTI.dll"; Dst = "bin\autorun\dlls\32\CEJVMTI.dll"}
            )
            x64 = @(
                @{Src = "Java\CEJVMTI\x64\Release\CEJVMTI.dll"; Dst = "bin\autorun\dlls\64\CEJVMTI.dll"}
            )
        }
    }
    "DBKKernel" = @{
        Name = "DBKKernel"
        Solution = Join-Path $DBKKernelDir "DBKKernel.sln"
        Platforms = @("Win32", "x64")
        Outputs = @{
            Win32 = @(
                @{Src = "dbk32.sys"; Dst = "bin\dbk32.sys"}
            )
            x64 = @(
                @{Src = "dbk64.sys"; Dst = "bin\dbk64.sys"}
            )
        }
        Note = "Requires WDK (Windows Driver Kit) and must be signed for production use"
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
    
    if ($project.Note) {
        Write-Host "Note: $($project.Note)" -ForegroundColor Yellow
    }
    
    if (-not (Test-Path $project.Solution)) {
        Write-Warning "Solution not found: $($project.Solution)"
        $BuildResults[$projectKey] = "SKIPPED"
        continue
    }
    
    # Check if all outputs already exist
    if ($SkipExisting -and -not $Clean) {
        $AllOutputsExist = $true
        foreach ($platform in $project.Platforms) {
            if ($project.Outputs.ContainsKey($platform)) {
                foreach ($output in $project.Outputs[$platform]) {
                    $dstPath = Join-Path $CheatEngineDir $output.Dst
                    if (-not (Test-Path $dstPath)) {
                        $AllOutputsExist = $false
                        break
                    }
                }
            }
            if (-not $AllOutputsExist) { break }
        }
        
        if ($AllOutputsExist) {
            Write-Host "All outputs for $($project.Name) already exist. Skipping build." -ForegroundColor Green
            $BuildResults[$projectKey] = "SKIPPED (EXISTS)"
            continue
        }
    }
    
    try {
        foreach ($platform in $project.Platforms) {
            Write-Host "`nBuilding platform: $platform" -ForegroundColor Yellow
            
            if ($Clean) {
                Write-Host "  Cleaning..." -ForegroundColor Gray
                & $MSBuild $project.Solution /t:Clean /p:Configuration=Release /p:Platform=$platform /v:minimal /nologo
            }
            
            Write-Host "  Building..." -ForegroundColor Gray
            & $MSBuild $project.Solution /t:Build /p:Configuration=Release /p:Platform=$platform /v:minimal /m /nologo
            
            if ($LASTEXITCODE -ne 0) {
                throw "Build failed with exit code $LASTEXITCODE"
            }
            
            # Copy outputs
            if ($project.Outputs.ContainsKey($platform)) {
                Write-Host "  Copying outputs..." -ForegroundColor Gray
                foreach ($output in $project.Outputs[$platform]) {
                    $srcPath = Join-Path $CheatEngineDir $output.Src
                    if (-not (Test-Path $srcPath)) {
                        $srcPath = Join-Path $RootDir $output.Src
                    }
                    
                    $dstPath = Join-Path $CheatEngineDir $output.Dst
                    $dstDir = Split-Path -Parent $dstPath
                    
                    if (-not (Test-Path $dstDir)) {
                        New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
                    }
                    
                    if (Test-Path $srcPath) {
                        Copy-Item $srcPath $dstPath -Force
                        Write-Host "    ✓ $(Split-Path -Leaf $dstPath)" -ForegroundColor Green
                    } else {
                        Write-Warning "    ✗ Source not found: $srcPath"
                    }
                }
            }
        }
        
        $BuildResults[$projectKey] = "SUCCESS"
        Write-Host "`n✓ $($project.Name) built successfully!" -ForegroundColor Green
        
    } catch {
        Write-Error "Failed to build $($project.Name): $_"
        $BuildResults[$projectKey] = "FAILED"
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
    }
    Write-Host "$projectKey : $status" -ForegroundColor $color
}

# Check if any builds failed
$failedBuilds = $BuildResults.Values | Where-Object { $_ -eq "FAILED" }
if ($failedBuilds.Count -gt 0) {
    Write-Host "`nSome builds failed. Check the output above for details." -ForegroundColor Red
    exit 1
} else {
    Write-Host "`nAll builds completed successfully!" -ForegroundColor Green
}
