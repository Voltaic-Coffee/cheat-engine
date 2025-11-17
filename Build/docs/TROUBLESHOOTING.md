# Troubleshooting Guide

This guide helps resolve common issues when building Cheat Engine from source.

## Table of Contents

- [Build Tool Issues](#build-tool-issues)
- [Compilation Errors](#compilation-errors)
- [Missing Dependencies](#missing-dependencies)
- [Runtime Issues](#runtime-issues)
- [Environment Problems](#environment-problems)
- [Debug Build](#debug-build)
- [Getting More Help](#getting-more-help)
- [Known Issues](#known-issues)
- [Clean Slate Rebuild](#clean-slate-rebuild)

## Build Tool Issues

### MSBuild Not Found

**Error**: "MSBuild not found. Please install Visual Studio 2017 or later."

**Solutions**:
1. Install Visual Studio 2017 or later (Community edition is free)
2. Ensure you installed the "Desktop development with C++" workload
3. Verify installation:
   ```powershell
   & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -latest -requires Microsoft.Component.MSBuild -find MSBuild\**\Bin\MSBuild.exe
   ```

### Lazbuild Not Found

**Error**: "lazbuild.exe not found. Please install Lazarus or set the correct path."

**Solutions**:
1. Install Lazarus 2.2.2 from the official source
2. Install to default location (`C:\lazarus`)
3. If installed elsewhere, modify the script:
   ```powershell
   $Lazbuild = "C:\Your\Custom\Path\lazbuild.exe"
   ```
4. Verify installation:
   ```powershell
   Test-Path "C:\lazarus\lazbuild.exe"
   ```

### VsWhere Command Failed

**Error**: VsWhere returns no results

**Solutions**:
1. Update Visual Studio to latest version
2. Repair Visual Studio installation via Visual Studio Installer
3. Manually set MSBuild path in scripts if needed

## Compilation Errors

### Lua Build Failures

**Error**: Lua 5.3 compilation fails
**Common Causes**:
1. Visual Studio version incompatibility
2. Missing Windows SDK
3. Project files need upgrade

**Solutions**:
```powershell
# Try clean build
.\Build\scripts\build-lua53.ps1 -Clean

# Check Visual Studio version supports the project format
# Projects are VS2013 format but should work with VS2017+

# Manual build from Visual Studio:
# Open: Cheat Engine\lua53\lua53\vs2013\lua53\lua53.sln
# Build → Batch Build → Select All → Build
```

### Lazarus Project Errors

**Error**: "Fatal: Cannot find unit X used by Y"

**Solutions**:
1. Ensure the 32-bit cross-compiler is installed:
   - `lazarus-2.2.2-fpc-3.2.2-cross-i386-win32-win64.exe`
2. Rebuild Lazarus IDE and packages if prompted.
3. Clean the project before building:
   ```powershell
   ./Build/scripts/build-lazarus-projects.ps1 -Clean
   ```

**Error**: "Can't create executable for CPU: x86_64"
**Solutions**:
1. Install cross-compiler for 64-bit:
   - Ensure Lazarus has the 64-bit toolchain available
2. Verify cross-compiler in Lazarus:
   - Tools → Options → Compiler → Test
   - Check both 32-bit and 64-bit compile

### Visual Studio Project Errors

**Error**: "The platform 'Win32' is not supported by this project"

**Solutions**:
1. Open solution in Visual Studio
2. Configuration Manager → Add platform if missing
3. Ensure project has both Win32 and x64 configurations

**Error**: "Cannot open include file: 'jni.h'"

**Solutions** (for CEJVMTI):
1. Install Java JDK (not just JRE)
2. Set JAVA_HOME environment variable:
   ```powershell
   $env:JAVA_HOME = "C:\Program Files\Java\jdk-17"
   ```
3. Update project include paths to point to JDK include directory

**Error**: ".NET Framework X.X targeting pack is not installed"

**Solutions**:
1. Install required .NET Framework Developer Pack
2. Or update project to target installed framework version
3. For .NET projects, ensure .NET desktop development workload is installed

## Missing Dependencies

### Third-Party DLLs Missing

**Issue**: Build succeeds but missing DLLs like dbghelp.dll, sqlite3.dll

**Solutions**:

These are typically pre-compiled third-party dependencies. Options:

1. **Copy from existing Cheat Engine installation**:
   - Download official Cheat Engine release
   - Extract and copy `bin/` folder contents

2. **Download individually**:
   - **dbghelp.dll / symsrv.dll**: From Windows SDK Debugging Tools
     - Download: https://developer.microsoft.com/en-us/windows/downloads/windows-sdk/
     - Or use from: `C:\Program Files (x86)\Windows Kits\10\Debuggers\`
   
   - **sqlite3.dll**: From SQLite official site
     - Download: https://www.sqlite.org/download.html
     - Get "Precompiled Binaries for Windows"
   
   - **libipt**: Intel Processor Trace library
     - From Intel or build from source
     - https://github.com/intel/libipt
   
   - **libmikmod**: Audio library
     - From MikMod project
     - http://mikmod.sourceforge.net/

3. **Check repository**: Some may already be in the bin directory

### LuaFileSystem (lfs.dll)

**Issue**: `bin/clibs32/lfs.dll` and `bin/clibs64/lfs.dll` missing

**Solutions**:

LFS needs to be compiled with Lua 5.3 headers:

1. Get LuaFileSystem source:
   ```
   git clone https://github.com/lunarmodules/luafilesystem
   ```

2. Compile with MinGW or Visual Studio:
   ```bash
   # Example with MinGW (32-bit)
   gcc -O2 -shared -o lfs.dll src/lfs.c -I"path\to\lua53\include" -L"path\to\lua53\lib" -llua53
   
   # For 64-bit, use 64-bit compiler
   ```

3. Or find pre-compiled versions for Lua 5.3

### TCC Library

**Issue**: TCC build fails or not found

**Solutions**:

TCC (Tiny C Compiler) is used for inline C code in scripts:

1. Build using provided script:
   ```powershell
   cd "Cheat Engine\tcclib\win32"
   .\build-tcc.bat -c gcc
   ```

2. Requires MinGW GCC:
   - Install MinGW-w64
   - Add to PATH
   - Or use TCC itself to bootstrap (shipped with some CE versions)

3. TCC is optional - CE works without {$C} support

## Runtime Issues

### Cheat Engine Crashes on Startup

**Possible Causes**:
1. Missing required DLLs
2. Mismatched 32-bit/64-bit DLL versions
3. Corrupted build

**Solutions**:
1. Use Dependency Walker or Dependencies.exe to check for missing DLLs
2. Verify all DLLs in bin directory are correct architecture
3. Clean rebuild all components:
   ```powershell
   .\Build\scripts\build-all.ps1 -Clean
   ```

### "Access Violation" on Startup

**Solutions**:
1. Run as Administrator (required for some features)
2. Disable antivirus temporarily (false positives common with CE)
3. Check Windows Defender exclusions
4. Rebuild with debug symbols and check stack trace

### Features Not Working

**Speedhack not available**:
- Ensure `speedhack.dll` and `speedhack64.dll` are built and in bin directory
- Rebuild: `.\Build\scripts\build-lazarus-projects.ps1 -Projects speedhack`

**{$luacode} not working**:
- Ensure `luaclient.dll` and `luaclient64.dll` are present
- Rebuild: `.\Build\scripts\build-lazarus-projects.ps1 -Projects luaclient`

**D3D overlay missing**:
- Build DirectX components: `.\Build\scripts\build-vs-projects.ps1 -Projects DirectXMess`
- Ensure d3dhook DLLs are in bin directory

**Mono/.NET features missing**:
- Build data collectors: `.\Build\scripts\build-vs-projects.ps1 -Projects MonoDataCollector,DotNetDataCollector,DotNetInvasiveDataCollector`

**Java inspection not working**:
- Build CEJVMTI: `.\Build\scripts\build-vs-projects.ps1 -Projects CEJVMTI`
- Ensure JDK is installed (not just JRE)

## Environment Problems

### Antivirus Interference

**Issue**: Build fails or files are deleted

**Solutions**:
1. Add build directory to antivirus exclusions
2. Add Cheat Engine directory to exclusions
3. Add lazbuild.exe and MSBuild.exe to exclusions
4. Temporarily disable real-time protection during build

### Permission Errors

**Error**: "Access denied" when building

**Solutions**:
1. Run PowerShell as Administrator
2. Check folder permissions
3. Disable read-only attributes on source folders
4. Check if files are locked by another process

### Path Too Long Errors

**Error**: "The specified path, file name, or both are too long"

**Solutions**:
1. Move repository to shorter path (e.g., `C:\CE\`)
2. Enable long path support in Windows 10/11:
   ```powershell
   # Run as Administrator
   New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1 -PropertyType DWORD -Force
   ```
3. Restart computer after changing registry

### Execution Policy Errors

**Error**: "... cannot be loaded because running scripts is disabled on this system"

**Solutions**:
```powershell
# Check current policy
Get-ExecutionPolicy

# Set policy for current user (recommended)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Or bypass for single script
PowerShell -ExecutionPolicy Bypass -File .\Build\scripts\build-all.ps1
```

## Debug Build

For troubleshooting, build with debug symbols:

### Lazarus Debug Build

1. Open project in Lazarus IDE
2. Select Debug build mode
3. Build
4. Run with debugger attached

### Visual Studio Debug Build

```powershell
# Modify script to use Debug configuration
# In build-vs-projects.ps1, change /p:Configuration=Release to /p:Configuration=Debug
```

## Getting More Help

If problems persist:

1. **Check build output carefully**: Run with `-Verbose` flag
2. **Search forums**: https://forum.cheatengine.org
3. **GitHub Issues**: https://github.com/cheat-engine/cheat-engine/issues
4. **Wiki**: https://wiki.cheatengine.org

When asking for help, provide:
- Full error message
- PowerShell/build output
- Windows version
- Visual Studio version
- Lazarus version
- What you've already tried

## Known Issues

### Windows 11 ARM

Building on ARM64 Windows requires:
- ARM64 native tools
- x86/x64 emulation may be slow
- Some components may not support ARM64

### Visual Studio 2022

Generally compatible, but:
- Older project files may need upgrading
- Right-click solution → "Retarget Projects" if needed
- Some legacy components may need Windows 10 SDK

### Lazarus Trunk/Unstable

Using development versions of Lazarus:
- May have breaking changes
- Stick to Lazarus 2.2.2 stable for building CE
- Newer versions untested with CE source

## Clean Slate Rebuild

If all else fails, clean rebuild:

```powershell
# Delete all build artifacts
Remove-Item -Recurse -Force "Cheat Engine\bin\*"
Remove-Item -Recurse -Force "Cheat Engine\lib\*"

# Clean all projects
.\Build\scripts\build-all.ps1 -Clean

# Full rebuild
.\Build\scripts\build-all.ps1 -Verbose
```
