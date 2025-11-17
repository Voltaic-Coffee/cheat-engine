# Build Environment Checker
# Validates that all required tools and dependencies are available

param(
    [switch]$Detailed
)

$ErrorActionPreference = "Continue"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir | Split-Path -Parent
$CheatEngineDir = Join-Path $RootDir "Cheat Engine"
$BinDir = Join-Path $CheatEngineDir "bin"

Write-Host @"
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║                  CHEAT ENGINE BUILD ENVIRONMENT CHECKER                      ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

Write-Host ""

# Helper function to test and report
function Test-Component {
    param(
        [string]$Name,
        [scriptblock]$Test,
        [string]$Message,
        [string]$FixMessage = "",
        [bool]$Required = $true
    )
    
    try {
        $result = & $Test
        if ($result) {
            Write-Host "✓ " -NoNewline -ForegroundColor Green
            Write-Host "$Name" -NoNewline
            if ($Detailed -and $Message) {
                Write-Host " - $Message" -ForegroundColor Gray
            } else {
                Write-Host ""
            }
            return $true
        } else {
            throw "Not found"
        }
    } catch {
        $color = if ($Required) { "Red" } else { "Yellow" }
        $symbol = if ($Required) { "✗" } else { "○" }
        
        Write-Host "$symbol " -NoNewline -ForegroundColor $color
        Write-Host "$Name" -NoNewline
        if ($Message) {
            Write-Host " - $Message" -ForegroundColor Gray
        } else {
            Write-Host ""
        }
        
        if ($FixMessage) {
            Write-Host "  → $FixMessage" -ForegroundColor Gray
        }
        
        return $false
    }
}

# Track results
$BuildTools = @{}
$RuntimeDeps = @{}
$Issues = @()

# Check Build Tools
Write-Host "BUILD TOOLS" -ForegroundColor Cyan
Write-Host "─────────────────────────────────────────" -ForegroundColor DarkGray

# Lazarus
$BuildTools['Lazarus'] = Test-Component -Name "Lazarus" -Test {
    $paths = @(
        "C:\lazarus\lazbuild.exe",
        "${env:ProgramFiles}\Lazarus\lazbuild.exe",
        "${env:ProgramFiles(x86)}\Lazarus\lazbuild.exe"
    )
    
    foreach ($path in $paths) {
        if (Test-Path $path) {
            if ($Detailed) {
                $version = & $path --version 2>&1 | Select-Object -First 1
                return $version
            }
            return $path
        }
    }
    return $false
} -Message "Required for main application" -FixMessage "Install Lazarus 2.2.2 from https://sourceforge.net/projects/lazarus/"

# Visual Studio / MSBuild
$BuildTools['MSBuild'] = Test-Component -Name "MSBuild / Visual Studio" -Test {
    try {
        $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
        if (-not (Test-Path $vswhere)) { return $false }
        
        $msbuild = & $vswhere -latest -requires Microsoft.Component.MSBuild -find MSBuild\**\Bin\MSBuild.exe -prerelease | Select-Object -First 1
        
        if ($msbuild) {
            if ($Detailed) {
                $vsInfo = & $vswhere -latest -property displayName
                return "$vsInfo`n  MSBuild: $msbuild"
            }
            return $msbuild
        }
    } catch {}
    return $false
} -Message "Required for DirectX, .NET, Java components" -FixMessage "Install Visual Studio 2017+ with C++ and .NET workloads"

# Windows SDK
$BuildTools['WindowsSDK'] = Test-Component -Name "Windows SDK" -Test {
    $sdkPath = "C:\Program Files (x86)\Windows Kits\10"
    if (Test-Path $sdkPath) {
        if ($Detailed) {
            $versions = Get-ChildItem "$sdkPath\Include" -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
            if ($versions) {
                return "Versions: $($versions -join ', ')"
            }
        }
        return $sdkPath
    }
    return $false
} -Message "Usually included with Visual Studio" -Required $false

# Java JDK (optional)
$BuildTools['JavaJDK'] = Test-Component -Name "Java JDK" -Test {
    if ($env:JAVA_HOME -and (Test-Path "$env:JAVA_HOME\include\jni.h")) {
        if ($Detailed) {
            $version = & "$env:JAVA_HOME\bin\java.exe" -version 2>&1 | Select-Object -First 1
            return $version
        }
        return $env:JAVA_HOME
    }
    return $false
} -Message "Required only for CEJVMTI (Java support)" -FixMessage "Set JAVA_HOME to JDK installation path" -Required $false

# Git (optional)
$BuildTools['Git'] = Test-Component -Name "Git" -Test {
    try {
        $gitVersion = git --version 2>&1
        return $gitVersion
    } catch {
        return $false
    }
} -Message "Version control" -Required $false

Write-Host ""

# Check Runtime Dependencies
Write-Host "RUNTIME DEPENDENCIES" -ForegroundColor Cyan
Write-Host "─────────────────────────────────────────" -ForegroundColor DarkGray

# Check for required DLLs
$dependencies = @{
    "dbghelp.dll (32-bit)" = @{Path = "win32\dbghelp.dll"; Required = $true}
    "dbghelp.dll (64-bit)" = @{Path = "win64\dbghelp.dll"; Required = $true}
    "symsrv.dll (32-bit)" = @{Path = "win32\symsrv.dll"; Required = $true}
    "symsrv.dll (64-bit)" = @{Path = "win64\symsrv.dll"; Required = $true}
    "sqlite3.dll (32-bit)" = @{Path = "win32\sqlite3.dll"; Required = $true}
    "sqlite3.dll (64-bit)" = @{Path = "win64\sqlite3.dll"; Required = $true}
    "libipt-32.dll" = @{Path = "libipt-32.dll"; Required = $false}
    "libipt-64.dll" = @{Path = "libipt-64.dll"; Required = $false}
    "libmikmod32.dll" = @{Path = "libmikmod32.dll"; Required = $false}
    "libmikmod64.dll" = @{Path = "libmikmod64.dll"; Required = $false}
    "lfs.dll (32-bit)" = @{Path = "clibs32\lfs.dll"; Required = $false}
    "lfs.dll (64-bit)" = @{Path = "clibs64\lfs.dll"; Required = $false}
}

foreach ($dep in $dependencies.Keys) {
    $info = $dependencies[$dep]
    $fullPath = Join-Path $BinDir $info.Path
    
    $RuntimeDeps[$dep] = Test-Component -Name $dep -Test {
        if (Test-Path $fullPath) {
            if ($Detailed) {
                $fileInfo = Get-Item $fullPath
                return "Size: $($fileInfo.Length) bytes, Modified: $($fileInfo.LastWriteTime)"
            }
            return $fullPath
        }
        return $false
    } -Required $info.Required -FixMessage "See Build\docs\DEPENDENCIES.md for download instructions"
}

Write-Host ""

# Check Build Artifacts (if any exist)
Write-Host "BUILD ARTIFACTS (if built)" -ForegroundColor Cyan
Write-Host "─────────────────────────────────────────" -ForegroundColor DarkGray

$artifacts = @(
    "bin\lua_extra\lua.exe",
    "bin\lua_extra\luac32.exe",
    "bin\lua_extra\luac64.exe",
    "bin\lua_extra\lua53-32.dll",
    "bin\lua_extra\lua53-64.dll",
    "bin\speedhack.dll",
    "bin\speedhack64.dll",
    "bin\luaclient.dll",
    "bin\luaclient64.dll",
    "bin\d3dhook.dll",
    "bin\d3dhook64.dll"
)

$builtCount = 0
foreach ($artifact in $artifacts) {
    $fullPath = Join-Path $CheatEngineDir $artifact
    if (Test-Path $fullPath) {
        $builtCount++
        if ($Detailed) {
            Write-Host "  ✓ $(Split-Path -Leaf $artifact)" -ForegroundColor Green
        }
    }
}

if ($builtCount -gt 0) {
    Write-Host "Found $builtCount built artifacts" -ForegroundColor Green
} else {
    Write-Host "No build artifacts found (build hasn't been run yet)" -ForegroundColor Yellow
}

Write-Host ""

# Summary
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host "─────────────────────────────────────────" -ForegroundColor DarkGray

$requiredBuildTools = $BuildTools.Values | Where-Object { $_ -eq $true }
$requiredRuntimeDeps = $RuntimeDeps.GetEnumerator() | Where-Object { 
    $dependencies[$_.Key].Required -and $_.Value -eq $true 
}

$readyToBuild = ($BuildTools['Lazarus'] -and $BuildTools['MSBuild'])
$hasRequiredDeps = ($requiredRuntimeDeps.Count -eq ($dependencies.GetEnumerator() | Where-Object { $_.Value.Required }).Count)

Write-Host "Build Tools: " -NoNewline
if ($readyToBuild) {
    Write-Host "✓ Ready" -ForegroundColor Green
} else {
    Write-Host "✗ Missing required tools" -ForegroundColor Red
    $Issues += "Install missing build tools"
}

Write-Host "Runtime Dependencies: " -NoNewline
if ($hasRequiredDeps) {
    Write-Host "✓ All required dependencies present" -ForegroundColor Green
} else {
    Write-Host "✗ Missing required dependencies" -ForegroundColor Red
    $Issues += "Install missing runtime dependencies"
}

Write-Host "Build Artifacts: " -NoNewline
if ($builtCount -gt 0) {
    Write-Host "○ $builtCount files found" -ForegroundColor Yellow
} else {
    Write-Host "○ Not built yet" -ForegroundColor Gray
}

Write-Host ""

# Recommendations
if ($Issues.Count -gt 0) {
    Write-Host "ACTION REQUIRED" -ForegroundColor Red
    Write-Host "─────────────────────────────────────────" -ForegroundColor DarkGray
    foreach ($issue in $Issues) {
        Write-Host "• $issue" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "See Build\docs\QUICKSTART.md for installation instructions" -ForegroundColor Cyan
    exit 1
} elseif ($readyToBuild) {
    Write-Host "✓ Environment is ready to build Cheat Engine!" -ForegroundColor Green
    Write-Host ""
    Write-Host "To start building, run:" -ForegroundColor Cyan
    Write-Host "  .\Build\scripts\build-all.ps1" -ForegroundColor White
    Write-Host ""
    
    if (-not $hasRequiredDeps) {
        Write-Host "Note: Some runtime dependencies are missing." -ForegroundColor Yellow
        Write-Host "The build will succeed, but you'll need to add them before running CE." -ForegroundColor Yellow
        Write-Host "See: Build\docs\DEPENDENCIES.md" -ForegroundColor Cyan
        Write-Host ""
    }
} else {
    Write-Host "Some components are missing. Review the output above." -ForegroundColor Yellow
    exit 1
}
