# Build script for Lua 5.3 components
# Builds: lua.exe, luac32.exe, luac64.exe, lua53-32.dll, lua53-64.dll, and .lib files

param(
    [switch]$Clean,
    [switch]$Verbose,
    [switch]$SkipExisting = $true
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir | Split-Path -Parent
$LuaDir = Join-Path $RootDir "Cheat Engine\lua53\lua53"
$OutputDir = Join-Path $RootDir "Cheat Engine\bin\lua_extra"
$PluginDir = Join-Path $RootDir "Cheat Engine\plugin"

# Visual Studio solution path
$SolutionPath = Join-Path $LuaDir "vs2013\lua53\lua53.sln"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Building Lua 5.3 Components" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Check if outputs already exist and skip if requested
if ($SkipExisting -and -not $Clean) {
    $RequiredFiles = @(
        "lua.exe",
        "luac32.exe",
        "luac64.exe",
        "lua53-32.dll",
        "lua53-64.dll",
        "lua53-32.lib",
        "lua53-64.lib"
    )
    
    $AllExist = $true
    foreach ($file in $RequiredFiles) {
        if (-not (Test-Path (Join-Path $OutputDir $file))) {
            $AllExist = $false
            break
        }
    }
    
    if ($AllExist) {
        Write-Host "`nAll Lua 5.3 components already exist. Skipping build." -ForegroundColor Green
        Write-Host "Use -Clean or set `$SkipExisting = `$false to force rebuild." -ForegroundColor Yellow
        exit 0
    }
}

# Verify Visual Studio is available
$MSBuild = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -latest -requires Microsoft.Component.MSBuild -find MSBuild\**\Bin\MSBuild.exe -prerelease | Select-Object -First 1

if (-not $MSBuild) {
    Write-Error "MSBuild not found. Please install Visual Studio 2017 or later."
    exit 1
}

Write-Host "Using MSBuild: $MSBuild" -ForegroundColor Green

# Clean if requested
if ($Clean) {
    Write-Host "`nCleaning previous builds..." -ForegroundColor Yellow
    & $MSBuild $SolutionPath /t:Clean /p:Configuration=Release /p:Platform=Win32 /v:minimal
    & $MSBuild $SolutionPath /t:Clean /p:Configuration=Release /p:Platform=x64 /v:minimal
}

# Create output directories
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# Build 32-bit versions
Write-Host "`nBuilding Lua 5.3 (32-bit)..." -ForegroundColor Yellow
& $MSBuild $SolutionPath /t:Build /p:Configuration=Release /p:Platform=Win32 /v:minimal /m
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to build Lua 5.3 (32-bit)"
    exit 1
}

# Build 64-bit versions
Write-Host "`nBuilding Lua 5.3 (64-bit)..." -ForegroundColor Yellow
& $MSBuild $SolutionPath /t:Build /p:Configuration=Release /p:Platform=x64 /v:minimal /m
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to build Lua 5.3 (64-bit)"
    exit 1
}

# Copy built files to output directory
Write-Host "`nCopying build artifacts..." -ForegroundColor Yellow

# Define source paths (adjust based on actual VS project output)
$Lua32Dir = Join-Path $LuaDir "vs2013\lua53\Release"
$Lua64Dir = Join-Path $LuaDir "vs2013\lua53\x64\Release"
$Luac32Dir = Join-Path $LuaDir "vs2013\lua53\luac\Release"
$Luac64Dir = Join-Path $LuaDir "vs2013\lua53\luac\x64\Release"

# Copy lua53 DLL and LIB files (32-bit)
if (Test-Path "$Lua32Dir\lua53.dll") {
    Copy-Item "$Lua32Dir\lua53.dll" "$OutputDir\lua53-32.dll" -Force
    Write-Host "  ✓ Copied lua53-32.dll" -ForegroundColor Green
}

if (Test-Path "$Lua32Dir\lua53.lib") {
    Copy-Item "$Lua32Dir\lua53.lib" "$OutputDir\lua53-32.lib" -Force
    Copy-Item "$Lua32Dir\lua53.lib" "$PluginDir\lua53-32.lib" -Force
    Write-Host "  ✓ Copied lua53-32.lib" -ForegroundColor Green
}

# Copy lua53 DLL and LIB files (64-bit)
if (Test-Path "$Lua64Dir\lua53.dll") {
    Copy-Item "$Lua64Dir\lua53.dll" "$OutputDir\lua53-64.dll" -Force
    Write-Host "  ✓ Copied lua53-64.dll" -ForegroundColor Green
}

if (Test-Path "$Lua64Dir\lua53.lib") {
    Copy-Item "$Lua64Dir\lua53.lib" "$OutputDir\lua53-64.lib" -Force
    Copy-Item "$Lua64Dir\lua53.lib" "$PluginDir\lua53-64.lib" -Force
    Write-Host "  ✓ Copied lua53-64.lib" -ForegroundColor Green
}

# Copy lua.exe
if (Test-Path "$Lua32Dir\lua.exe") {
    Copy-Item "$Lua32Dir\lua.exe" "$OutputDir\lua.exe" -Force
    Write-Host "  ✓ Copied lua.exe" -ForegroundColor Green
} elseif (Test-Path "$Lua64Dir\lua.exe") {
    Copy-Item "$Lua64Dir\lua.exe" "$OutputDir\lua.exe" -Force
    Write-Host "  ✓ Copied lua.exe (64-bit)" -ForegroundColor Green
}

# Copy luac executables
if (Test-Path "$Luac32Dir\luac.exe") {
    Copy-Item "$Luac32Dir\luac.exe" "$OutputDir\luac32.exe" -Force
    Write-Host "  ✓ Copied luac32.exe" -ForegroundColor Green
}

if (Test-Path "$Luac64Dir\luac.exe") {
    Copy-Item "$Luac64Dir\luac.exe" "$OutputDir\luac64.exe" -Force
    Write-Host "  ✓ Copied luac64.exe" -ForegroundColor Green
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Lua 5.3 Build Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

# Verify all required files exist
Write-Host "`nVerifying build artifacts..." -ForegroundColor Yellow
$RequiredFiles = @(
    "lua.exe",
    "luac32.exe",
    "luac64.exe",
    "lua53-32.dll",
    "lua53-64.dll",
    "lua53-32.lib",
    "lua53-64.lib"
)

$AllPresent = $true
foreach ($file in $RequiredFiles) {
    $filePath = Join-Path $OutputDir $file
    if (Test-Path $filePath) {
        Write-Host "  ✓ $file" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $file (missing)" -ForegroundColor Red
        $AllPresent = $false
    }
}

if ($AllPresent) {
    Write-Host "`nAll Lua components built successfully!" -ForegroundColor Green
} else {
    Write-Warning "Some Lua components are missing. Check the build output."
    exit 1
}
