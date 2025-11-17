# Dependencies Guide

This document details all dependencies required to build and run Cheat Engine.

## Table of Contents

- [Build-Time Dependencies](#build-time-dependencies)
- [Runtime Dependencies](#runtime-dependencies)
- [Component Dependencies](#component-dependencies)
- [Optional Components](#optional-components)
- [Dependency Installation Script](#dependency-installation-script)
- [License Information](#license-information)
- [Getting Dependencies Quickly](#getting-dependencies-quickly)
- [Version Compatibility](#version-compatibility)
- [Troubleshooting Dependencies](#troubleshooting-dependencies)

## Build-Time Dependencies

These tools are required to compile Cheat Engine from source.

### Lazarus & Free Pascal

**Required Version**: Lazarus 2.2.2 with FPC 3.2.2

**Download**: https://sourceforge.net/projects/lazarus/files/Lazarus%20Windows%2064%20bits/Lazarus%202.2.2/

**Installation Order**:
1. `lazarus-2.2.2-fpc-3.2.2-win64.exe` (main installation)
2. `lazarus-2.2.2-fpc-3.2.2-cross-i386-win32-win64.exe` (cross-compiler for 32-bit)

**Purpose**: Compiles main Cheat Engine executable and Lazarus-based DLL projects (speedhack, luaclient, vehdebug)

### Visual Studio

**Required Version**: Visual Studio 2017 or later

**Editions**: Community, Professional, or Enterprise

**Download**: https://visualstudio.microsoft.com/downloads/

**Required Workloads**:
- Desktop development with C++
- .NET desktop development

**Purpose**: Compiles DirectX hooks, .NET components, Mono support, Java support, and kernel drivers

### Windows SDK

**Required Version**: Windows 10 SDK or later

**Download**: Included with Visual Studio or https://developer.microsoft.com/en-us/windows/downloads/windows-sdk/

**Purpose**: Provides Windows API headers and libraries for compilation

### Windows Driver Kit (WDK)

**Required**: Only for building DBKKernel

**Download**: https://docs.microsoft.com/en-us/windows-hardware/drivers/download-the-wdk

**Note**: DBKKernel is optional and requires driver signing for production use

## Runtime Dependencies

These libraries and tools are required for Cheat Engine to run.

### Lua 5.3

**Built by**: `build-lua53.ps1` script

**Components**:
- `lua.exe` - Lua interpreter
- `luac32.exe` / `luac64.exe` - Lua compilers
- `lua53-32.dll` / `lua53-64.dll` - Lua runtime libraries
- `lua53-32.lib` / `lua53-64.lib` - Import libraries

**Location**: `Cheat Engine/bin/lua_extra/`

**Purpose**: Lua scripting engine for Cheat Engine's automation features

### Third-Party DLLs

The following DLLs are typically pre-compiled and must be obtained separately or from an existing Cheat Engine installation.

#### Debugging Tools

**Files**:
- `bin/win32/dbghelp.dll`
- `bin/win32/symsrv.dll`
- `bin/win64/dbghelp.dll`
- `bin/win64/symsrv.dll`
- `bin/win64/old/dbghelp.dll`
- `bin/win64/old/symsrv.dll`

**Source**: Windows SDK Debugging Tools for Windows

**Download**: https://developer.microsoft.com/en-us/windows/downloads/windows-sdk/

**Alternative**: Copy from installed Windows SDK at:
```
C:\Program Files (x86)\Windows Kits\10\Debuggers\x86\
C:\Program Files (x86)\Windows Kits\10\Debuggers\x64\
```

**Purpose**: Symbol resolution and debugging support

#### SQLite

**Files**:
- `bin/win32/sqlite3.dll`
- `bin/win64/sqlite3.dll`

**Source**: SQLite official website

**Download**: https://www.sqlite.org/download.html
- Get "Precompiled Binaries for Windows"
- Download both 32-bit and 64-bit DLLs

**Purpose**: Database support for saved scans and tables

#### Intel Processor Trace

**Files**:
- `bin/libipt-32.dll`
- `bin/libipt-64.dll`

**Source**: Intel Processor Trace library

**Repository**: https://github.com/intel/libipt

**Download**: 
- Pre-built releases: https://github.com/intel/libipt/releases
- Or build from source

**Purpose**: Intel PT tracing support for advanced debugging

#### MikMod Audio Library

**Files**:
- `bin/libmikmod32.dll`
- `bin/libmikmod64.dll`

**Source**: MikMod library

**Website**: http://mikmod.sourceforge.net/

**Download**: 
- Windows binaries from SourceForge
- Compile from source if needed

**Purpose**: Audio playback for XM/MOD files (used by xmplayer component)

#### LuaFileSystem

**Files**:
- `bin/clibs32/lfs.dll`
- `bin/clibs64/lfs.dll`

**Source**: LuaFileSystem project

**Repository**: https://github.com/lunarmodules/luafilesystem

**Building**:
```bash
# Requires Lua 5.3 headers and libraries

# 32-bit (with MinGW)
gcc -O2 -shared -o lfs.dll src/lfs.c \
    -I"path/to/lua53/src" \
    -L"path/to/lua53/lib" \
    -llua53-32

# 64-bit (with MinGW-w64)
gcc -O2 -shared -o lfs.dll src/lfs.c \
    -I"path/to/lua53/src" \
    -L"path/to/lua53/lib" \
    -llua53-64
```

**Purpose**: File system operations for Lua scripts

## Component Dependencies

### DirectX Hooks (DirectXMess)

**Requirements**:
- Visual Studio with C++ tools
- DirectX SDK (included in Windows SDK 8.0+)

**Purpose**: D3D9, D3D10, D3D11 overlay and snapshot capabilities

**Outputs**:
- `CED3D9Hook.dll` / `CED3D9Hook64.dll`
- `CED3D10Hook.dll` / `CED3D10Hook64.dll`
- `CED3D11Hook.dll` / `CED3D11Hook64.dll`
- `d3dhook.dll` / `d3dhook64.dll`

### .NET Support

**Requirements**:
- Visual Studio with .NET desktop development
- .NET Framework 4.x SDK

**Components**:

**DotNetCompiler**:
- Purpose: C# compilation via `cscompile` Lua command
- Output: `CSCompiler.exe`

**MonoDataCollector**:
- Purpose: Inspect Mono/.NET process structures
- Output: `MonoDataCollector.dll` / `MonoDataCollector64.dll`

**DotNetDataCollector**:
- Purpose: Collect .NET symbols and metadata
- Output: `DotNetDataCollector.exe` / `DotNetDataCollector64.exe`

**DotNetInvasiveDataCollector**:
- Purpose: Runtime JIT inspection
- Output: `DotNetInvasiveDataCollector.dll`

### Java Support (CEJVMTI)

**Requirements**:
- Visual Studio with C++ tools
- Java JDK (not JRE) - version 8 or later
- JAVA_HOME environment variable set

**Purpose**: Java Virtual Machine inspection via JVMTI

**Outputs**:
- `bin/autorun/dlls/32/CEJVMTI.dll`
- `bin/autorun/dlls/64/CEJVMTI.dll`

**Setup**:
```powershell
# Set JAVA_HOME (adjust path to your JDK)
$env:JAVA_HOME = "C:\Program Files\Java\jdk-17"

# Verify
Test-Path "$env:JAVA_HOME\include\jni.h"
```

### TCC Library

**Requirements**:
- MinGW GCC or TCC itself
- GNU Make (optional)

**Purpose**: Inline C code compilation in Auto Assembler scripts via {$C} and {$CCODE}

**Building**:
```batch
cd "Cheat Engine\tcclib\win32"
build-tcc.bat -c gcc
```

**Note**: TCC is optional - Cheat Engine works without it, but {$C} features won't be available

### Kernel Driver (DBKKernel)

**Requirements**:
- Windows Driver Kit (WDK)
- Driver signing certificate (for production)

**Purpose**: Kernel-mode operations (Settings → Extra features)

**Note**: Requires one of:
- Test signing mode enabled (bcdedit /set testsigning on)
- Driver signature enforcement disabled
- Properly signed driver

**Warning**: Building and using kernel drivers requires advanced knowledge and can affect system stability

## Optional Components

### CUDA Pointer Scanner

**Requirements**:
- NVIDIA CUDA Toolkit
- NVIDIA GPU with CUDA support

**Purpose**: GPU-accelerated pointer scanning

**Location**: `Cheat Engine/CUDA pointerscan/`

**Note**: Not required for core functionality

## Dependency Installation Script

You can create a helper script to check dependencies:

```powershell
# Check-Dependencies.ps1

function Test-Dependency {
    param($Name, $Path, $Required = $true)
    
    $exists = Test-Path $Path
    $status = if ($exists) { "✓" } else { "✗" }
    $color = if ($exists) { "Green" } else { if ($Required) { "Red" } else { "Yellow" } }
    
    Write-Host "$status $Name" -ForegroundColor $color
    if (-not $exists -and $Required) {
        Write-Host "    Missing: $Path" -ForegroundColor Red
    }
}

Write-Host "Checking Build Dependencies..." -ForegroundColor Cyan
Test-Dependency "Lazarus" "C:\lazarus\lazbuild.exe"
Test-Dependency "Visual Studio" "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"

Write-Host "`nChecking Runtime Dependencies..." -ForegroundColor Cyan
$binDir = "Cheat Engine\bin"
Test-Dependency "dbghelp.dll (32-bit)" "$binDir\win32\dbghelp.dll"
Test-Dependency "dbghelp.dll (64-bit)" "$binDir\win64\dbghelp.dll"
Test-Dependency "sqlite3.dll (32-bit)" "$binDir\win32\sqlite3.dll"
Test-Dependency "sqlite3.dll (64-bit)" "$binDir\win64\sqlite3.dll"
Test-Dependency "libipt-32.dll" "$binDir\libipt-32.dll" $false
Test-Dependency "libipt-64.dll" "$binDir\libipt-64.dll" $false
Test-Dependency "lfs.dll (32-bit)" "$binDir\clibs32\lfs.dll" $false
Test-Dependency "lfs.dll (64-bit)" "$binDir\clibs64\lfs.dll" $false
```

## License Information

When distributing Cheat Engine or using these dependencies, ensure compliance with their licenses:

- **Lua**: MIT License
- **SQLite**: Public Domain
- **libmikmod**: LGPL
- **LuaFileSystem**: MIT License
- **Intel PT**: BSD License
- **dbghelp/symsrv**: Microsoft proprietary (redistribution allowed)

Always check the LICENSE files in each component's source directory.

## Getting Dependencies Quickly

### From Official Cheat Engine Release

The easiest way to get runtime dependencies:

1. Download official Cheat Engine installer: https://github.com/cheat-engine/cheat-engine/releases/latest
2. Install or extract files
3. Copy `bin/` directory to your build
4. This ensures all third-party DLLs are present

### Building Everything

For a complete source-only build (excluding third-party DLLs):

```powershell
# Build all Cheat Engine components
.\Build\scripts\build-all.ps1

# Manually obtain and place third-party DLLs in bin/ directories
# See sections above for download links
```

## Version Compatibility

| Component | Minimum Version | Recommended | Notes |
|-----------|----------------|-------------|-------|
| Lazarus | 2.2.2 | 2.2.2 | Exact version recommended |
| FPC | 3.2.2 | 3.2.2 | Comes with Lazarus |
| Visual Studio | 2017 | 2019/2022 | Community edition OK |
| Windows SDK | 10.0 | Latest | Included with VS |
| .NET Framework | 4.5 | 4.8 | For .NET components |
| Java JDK | 8 | 11 or 17 | For CEJVMTI only |

## Troubleshooting Dependencies

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for detailed help with dependency issues.
