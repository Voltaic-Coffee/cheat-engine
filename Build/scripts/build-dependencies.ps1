# Build script for TCC library and other dependencies
# Builds: libtcc for 32-32, 64-32, and 64-64 configurations
#         LuaFileSystem (lfs.dll) for 32-bit and 64-bit

param(
    [switch]$Clean,
    [switch]$Verbose,
    [switch]$SkipTCC,
    [switch]$SkipLFS,
    [switch]$SkipExisting = $true
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir | Split-Path -Parent
$CheatEngineDir = Join-Path $RootDir "Cheat Engine"
$TCCDir = Join-Path $CheatEngineDir "tcclib"
$BinDir = Join-Path $CheatEngineDir "bin"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Building TCC Library and Dependencies" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Build TCC library
if (-not $SkipTCC) {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Building: TCC Library" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    if (-not (Test-Path $TCCDir)) {
        Write-Warning "TCC directory not found: $TCCDir"
    } else {
        # Check if tcc is already built or needs building
        $tccBuildScript = Join-Path $TCCDir "win32\build-tcc.bat"
        
        if (Test-Path $tccBuildScript) {
            Write-Host "`nBuilding TCC using build-tcc.bat..." -ForegroundColor Yellow
            Write-Host "Note: This builds 32-bit and 64-bit versions of TCC" -ForegroundColor Yellow
            
            Push-Location (Join-Path $TCCDir "win32")
            
            try {
                if ($Clean) {
                    Write-Host "  Cleaning TCC build..." -ForegroundColor Gray
                    & cmd /c "build-tcc.bat -clean" 2>&1 | Out-Null
                }
                
                # Build TCC (it will build both 32 and 64-bit)
                Write-Host "  Building TCC..." -ForegroundColor Gray
                $output = & cmd /c "build-tcc.bat -c gcc" 2>&1
                
                if ($LASTEXITCODE -ne 0) {
                    Write-Warning "TCC build encountered issues. Output:"
                    Write-Host $output
                } else {
                    Write-Host "  ✓ TCC built successfully" -ForegroundColor Green
                }
                
                # TCC builds in-place, files should be in win32 directory
                # For Cheat Engine, the tcclib.pas unit handles loading TCC dynamically
                Write-Host "`nNote: TCC is typically loaded dynamically by Cheat Engine" -ForegroundColor Yellow
                Write-Host "The built files are in: $TCCDir\win32\" -ForegroundColor Yellow
                
            } catch {
                Write-Warning "Failed to build TCC: $_"
            } finally {
                Pop-Location
            }
        } else {
            Write-Host "TCC build script not found. TCC may need manual compilation." -ForegroundColor Yellow
            Write-Host "Note: TCC provides {`$C} and {`$CCODE} support in Auto Assembler scripts" -ForegroundColor Yellow
        }
    }
}

# Build LuaFileSystem (lfs.dll)
if (-not $SkipLFS) {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Building: LuaFileSystem (lfs.dll)" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    # LFS typically needs to be built separately with Lua headers
    # Check if there's a pre-built version or build script
    
    $lfs32Dir = Join-Path $BinDir "clibs32"
    $lfs64Dir = Join-Path $BinDir "clibs64"
    
    # Create directories if they don't exist
    if (-not (Test-Path $lfs32Dir)) {
        New-Item -ItemType Directory -Path $lfs32Dir -Force | Out-Null
    }
    if (-not (Test-Path $lfs64Dir)) {
        New-Item -ItemType Directory -Path $lfs64Dir -Force | Out-Null
    }
    
    Write-Host "Note: LuaFileSystem (lfs.dll) typically requires manual compilation" -ForegroundColor Yellow
    Write-Host "Expected output locations:" -ForegroundColor Yellow
    Write-Host "  32-bit: $lfs32Dir\lfs.dll" -ForegroundColor Gray
    Write-Host "  64-bit: $lfs64Dir\lfs.dll" -ForegroundColor Gray
    Write-Host "`nTo build lfs.dll:" -ForegroundColor Yellow
    Write-Host "  1. Get LuaFileSystem source from https://github.com/lunarmodules/luafilesystem" -ForegroundColor Gray
    Write-Host "  2. Compile with Lua 5.3 headers as a shared library" -ForegroundColor Gray
    Write-Host "  3. Place the compiled lfs.dll files in the appropriate directories" -ForegroundColor Gray
}

# Check for additional dependencies
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Checking Additional Dependencies" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# List of required DLLs that are typically third-party
$ThirdPartyDependencies = @{
    "libipt-32.dll" = "Intel Processor Trace library (32-bit)"
    "libipt-64.dll" = "Intel Processor Trace library (64-bit)"
    "libmikmod32.dll" = "MikMod audio library (32-bit)"
    "libmikmod64.dll" = "MikMod audio library (64-bit)"
    "win32\dbghelp.dll" = "Debugging Tools for Windows (32-bit)"
    "win32\sqlite3.dll" = "SQLite database (32-bit)"
    "win32\symsrv.dll" = "Symbol Server (32-bit)"
    "win64\dbghelp.dll" = "Debugging Tools for Windows (64-bit)"
    "win64\sqlite3.dll" = "SQLite database (64-bit)"
    "win64\symsrv.dll" = "Symbol Server (64-bit)"
    "win64\old\dbghelp.dll" = "Debugging Tools for Windows - old version (64-bit)"
    "win64\old\symsrv.dll" = "Symbol Server - old version (64-bit)"
}

Write-Host "`nThird-party dependencies (typically pre-compiled):" -ForegroundColor Yellow
foreach ($dll in $ThirdPartyDependencies.Keys) {
    $dllPath = Join-Path $BinDir $dll
    if (Test-Path $dllPath) {
        Write-Host "  ✓ $dll" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $dll (missing) - $($ThirdPartyDependencies[$dll])" -ForegroundColor Red
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "TCC and Dependencies Build Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`nNote: Some components require third-party libraries or manual compilation." -ForegroundColor Yellow
Write-Host "Refer to Build\docs\DEPENDENCIES.md for more information." -ForegroundColor Yellow
