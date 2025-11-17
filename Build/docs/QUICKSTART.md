# Quick Start Guide - Building Cheat Engine

This is a streamlined guide to get Cheat Engine built as quickly as possible.

## Table of Contents

- [Prerequisites Installation](#prerequisites-installation-30-60-minutes)
- [Building Cheat Engine](#building-cheat-engine-10-30-minutes)
- [Verify Build](#verify-build)
- [First Run](#first-run)
- [Common First-Time Issues](#common-first-time-issues)
- [Getting Third-Party Dependencies](#getting-third-party-dependencies)
- [Build Troubleshooting](#build-troubleshooting)
- [Development Workflow](#development-workflow)
- [Next Steps](#next-steps)

## Prerequisites Installation (30-60 minutes)

### Step 1: Install Lazarus (10 minutes)

1. Download from: https://sourceforge.net/projects/lazarus/files/Lazarus%20Windows%2064%20bits/Lazarus%202.2.2/

2. Install **in this order**:
   ```
   lazarus-2.2.2-fpc-3.2.2-win64.exe
   lazarus-2.2.2-fpc-3.2.2-cross-i386-win32-win64.exe
   ```

3. Accept default installation path: `C:\lazarus`

### Step 2: Install Visual Studio (20-40 minutes)

1. Download Visual Studio Community: https://visualstudio.microsoft.com/downloads/

2. During installation, select these workloads:
   - ✓ Desktop development with C++
   - ✓ .NET desktop development

3. Click Install and wait (this takes a while)

### Step 3: Optional - Java JDK (5 minutes)

Only needed for Java inspection features:

1. Download JDK 17: https://adoptium.net/
2. Install and note installation path
3. Set environment variable:
   ```powershell
   [System.Environment]::SetEnvironmentVariable('JAVA_HOME', 'C:\Program Files\Eclipse Adoptium\jdk-17.0.x-hotspot\', 'Machine')
   ```

## Building Cheat Engine (10-30 minutes)

### Configuration

- `config/build-config.template.ps1`: Template for build script configuration settings (DO NOT customize this file directly)
- You should create a `config/build-config.local.ps1` next to it to override paths and options (this file is git-ignored).

### Quick Build - All Components

Open PowerShell (as Administrator) and run:

```powershell
# Navigate to repository
cd C:\path\to\cheat-engine

# Set execution policy (if needed)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# (Recommended) Check your environment first
.\Build\scripts\check-environment.ps1 -Detailed

# Build everything
.\Build\scripts\build-all.ps1
```

This will build:
- Lua components (2-5 minutes)
- Visual Studio projects (5-10 minutes)
- Lazarus projects (5-10 minutes)
- Check dependencies (1 minute)

**Total time**: ~15-25 minutes depending on your PC

Note: Scripts skip rebuilding existing outputs by default. Use `-Clean` to force a full rebuild.

### Step-by-Step Build

If you prefer to build components individually:

For script options and project lists, see `SCRIPTS.md`.

#### 1. Build Lua (2-5 minutes)
```powershell
.\Build\scripts\build-lua53.ps1
```

#### 2. Build Visual Studio Projects (5-10 minutes)
```powershell
.\Build\scripts\build-vs-projects.ps1
```

#### 3. Build Lazarus DLLs (3-5 minutes)
```powershell
.\Build\scripts\build-lazarus-projects.ps1
```

#### 4. Build Main Application (2-5 minutes)

**Option A**: Using script (may need manual intervention)
```powershell
.\Build\scripts\build-lazarus-projects.ps1 -Projects @()
```

**Option B**: Using Lazarus IDE (recommended)
1. Open Lazarus
2. File → Open → `Cheat Engine\cheatengine.lpi`
3. Run → Compile many Modes
4. Select first three modes and click OK

For detailed manual build instructions, see [MANUAL_BUILD.md](MANUAL_BUILD.md).

## Verify Build

Check that key files exist:

```powershell
# Quick verification script
$required = @(
    "Cheat Engine\bin\lua_extra\lua.exe",
    "Cheat Engine\bin\lua_extra\luac32.exe",
    "Cheat Engine\bin\lua_extra\luac64.exe",
    "Cheat Engine\bin\speedhack.dll",
    "Cheat Engine\bin\luaclient.dll",
    "Cheat Engine\bin\d3dhook.dll"
)

foreach ($file in $required) {
    if (Test-Path $file) {
        Write-Host "✓ $file" -ForegroundColor Green
    } else {
        Write-Host "✗ $file" -ForegroundColor Red
    }
}
```

## First Run

### Option 1: Run from Lazarus IDE

1. Open `Cheat Engine\cheatengine.lpi` in Lazarus
2. Press F9 or click the green play button
3. **Note**: Must run Lazarus as Administrator

### Option 2: Run Compiled Executable

1. Navigate to the compiled executable location (varies by build mode)
2. Right-click → Run as Administrator
3. Default location might be `Cheat Engine\` or `Cheat Engine\bin\`

## Common First-Time Issues

### "MSBuild not found"
→ Install Visual Studio with C++ workload

### "lazbuild.exe not found"
→ Install Lazarus to default path or update script

### Build succeeds but some features missing
→ Likely missing third-party DLLs, see next section

### "Access denied" errors
→ Run PowerShell as Administrator

## Getting Third-Party Dependencies

Some DLLs are third-party and not built from source. Easiest approach:

### Quick Method: Copy from Official Release

1. Download latest Cheat Engine: https://github.com/cheat-engine/cheat-engine/releases/latest
2. Extract or install
3. Copy these folders to your build:
   ```
   bin/win32/*.dll
   bin/win64/*.dll
   bin/clibs32/*.dll (if exists)
   bin/clibs64/*.dll (if exists)
   ```

### Manual Method: Download Each

See [DEPENDENCIES.md](../docs/DEPENDENCIES.md) for individual download links:
- dbghelp.dll & symsrv.dll (from Windows SDK)
- sqlite3.dll (from sqlite.org)
- libipt-32/64.dll (optional)
- libmikmod32/64.dll (optional)
- lfs.dll (optional, for Lua file system)

## Build Troubleshooting

### Build fails with error code 1

```powershell
# Try with verbose output
.\Build\scripts\build-all.ps1 -Verbose

# Or clean build
.\Build\scripts\build-all.ps1 -Clean
```

### Partial build success

Build specific components:
```powershell
# Just Lua
.\Build\scripts\build-all.ps1 -Only lua

# Just Visual Studio projects
.\Build\scripts\build-all.ps1 -Only vs

# Lua and Lazarus projects only
.\Build\scripts\build-all.ps1 -Only lua,lazarus
```

### Need detailed help

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

## Development Workflow

### Rebuilding After Changes

**For Lazarus projects** (Pascal code):
- Open in Lazarus IDE
- Make changes
- Press F9 to compile and run

**For Visual Studio projects** (C/C++/C#):
```powershell
# Rebuild specific project
.\Build\scripts\build-vs-projects.ps1 -Projects DirectXMess -Clean
```

**For Lua changes**:
- No rebuild needed (interpreted language)
- Just restart Cheat Engine

### Incremental Builds

```powershell
# Build without cleaning (faster)
.\Build\scripts\build-all.ps1

# Only clean and rebuild what changed
.\Build\scripts\build-lazarus-projects.ps1 -Projects speedhack
```

## Next Steps

Once built successfully:

1. **Test core features**: Open a process, scan for values
2. **Test Lua scripts**: Try built-in tutorials
3. **Test advanced features**: Mono dissector, D3D overlay (if game available)
4. **Read documentation**: Check main README.md and Wiki

## Getting Help

Stuck? Ask for help:

- **Forum**: https://forum.cheatengine.org
- **GitHub Issues**: https://github.com/cheat-engine/cheat-engine/issues
- **Wiki**: https://wiki.cheatengine.org

When asking for help, include:
- Error message (full text)
- Build script output
- Windows version
- Visual Studio version
- Lazarus version

## Summary of Commands

```powershell
# Complete build from scratch
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
cd C:\path\to\cheat-engine
.\Build\scripts\build-all.ps1

# Or step by step
.\Build\scripts\build-lua53.ps1
.\Build\scripts\build-vs-projects.ps1
.\Build\scripts\build-lazarus-projects.ps1

# Then build main app in Lazarus IDE:
# - Open cheatengine.lpi
# - Run → Compile many Modes
# - Select first 3 modes → OK

# Run (from Lazarus or compiled .exe as admin)
```

That's it! You should now have a working Cheat Engine build.
