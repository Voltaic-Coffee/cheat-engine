# Build Scripts Reference

This document centralizes details for all build scripts under `Build/scripts/`.

## Table of Contents

- [Overview](#overview)
- [Common Conventions](#common-conventions)
- [build-all.ps1](#build-allps1)
- [build-lua53.ps1](#build-lua53ps1)
- [build-vs-projects.ps1](#build-vs-projectsps1)
- [build-lazarus-projects.ps1](#build-lazarus-projectsps1)
- [build-dependencies.ps1](#build-dependenciesps1)
- [check-environment.ps1](#check-environmentps1)
- [Outputs by Component](#outputs-by-component)

## Overview

- Scripts are designed to be idempotent and safe to re-run.
- Run PowerShell as Administrator. If scripts are blocked, set execution policy:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

- For first-time setup, see [QUICKSTART.md](QUICKSTART.md).
- For prerequisites, see [DEPENDENCIES.md](DEPENDENCIES.md).
- For manual builds without scripts, see [MANUAL_BUILD.md](MANUAL_BUILD.md).

## Common Conventions

- `-Clean`: Forces a clean rebuild, ignoring incremental outputs.
- `-Verbose`: Enables detailed logging for troubleshooting.
- `-Only`: For `build-all.ps1`, limits which components run (comma-separated).
- `-Projects`: For component scripts, builds only the specified sub-projects.

Environment configuration can be customized using `Build/config/build-config.template.ps1` (copy to `build-config.local.ps1`).

## build-all.ps1

Orchestrates the entire build in the correct order.

```powershell
# Build everything
.\Build\scripts\build-all.ps1

# Clean rebuild
.\Build\scripts\build-all.ps1 -Clean

# Verbose output
.\Build\scripts\build-all.ps1 -Verbose

# Build specific components only (lua, vs, lazarus, deps)
.\Build\scripts\build-all.ps1 -Only lua,vs

# Skip building the main Lazarus app
.\Build\scripts\build-all.ps1 -SkipCheatEngine
```

Order of operations:
- Lua 5.3
- Visual Studio projects
- Lazarus DLL projects and optionally main app
- Dependencies check/TCC

## build-lua53.ps1

Builds Lua 5.3 interpreter, compilers, and libraries.

```powershell
.\Build\scripts\build-lua53.ps1
.\Build\scripts\build-lua53.ps1 -Clean
```

Outputs (to `Cheat Engine/bin/lua_extra/`):
- `lua.exe` (interpreter)
- `luac32.exe`, `luac64.exe` (compilers)
- `lua53-32.dll`, `lua53-64.dll` (runtime)
- `lua53-32.lib`, `lua53-64.lib` (import libraries)

Purpose: Required for Lua scripting, trainers, and Auto Assembler features.

## build-vs-projects.ps1

Builds all Visual Studio-based components. Supports `-Projects` and `-Clean`.

```powershell
# Build all VS projects
.\Build\scripts\build-vs-projects.ps1

# Build specific projects
.\Build\scripts\build-vs-projects.ps1 -Projects DirectXMess,CEJVMTI

# Clean build
.\Build\scripts\build-vs-projects.ps1 -Clean
```

Projects and purposes:
- `DirectXMess`: D3D9/10/11 overlay and snapshot hooks
- `DotNetCompiler`: C# compilation support (`CSCompiler.exe`)
- `MonoDataCollector`: Mono/.NET process inspection
- `DotNetDataCollector`: .NET symbols/metadata collection
- `DotNetInvasiveDataCollector`: Runtime JIT inspection helpers
- `CEJVMTI`: Java VM inspection via JVMTI
- `DBKKernel` (optional): Kernel-mode driver (requires WDK & signing)

## build-lazarus-projects.ps1

Builds Lazarus DLL projects and optionally the main application.

```powershell
# Build all Lazarus DLLs and optionally main app
.\Build\scripts\build-lazarus-projects.ps1

# Build specific projects only
.\Build\scripts\build-lazarus-projects.ps1 -Projects speedhack,luaclient

# Skip main Cheat Engine executable
.\Build\scripts\build-lazarus-projects.ps1 -SkipCheatEngine

# Clean build
.\Build\scripts\build-lazarus-projects.ps1 -Clean
```

Lazarus projects:
- `speedhack`: `speedhack.dll`, `speedhack64.dll`
- `luaclient`: `luaclient.dll`, `luaclient64.dll`
- `vehdebug`: `vehdebug.dll`, `vehdebug64.dll`
- `cheatengine` (main app): Built via Lazarus IDE or script as needed

## build-dependencies.ps1

Builds TCC library and verifies third-party dependencies.

```powershell
.\Build\scripts\build-dependencies.ps1
.\Build\scripts\build-dependencies.ps1 -SkipTCC
```

Includes:
- TCC build for `{$C}` and `{$CCODE}` Auto Assembler features
- Checks presence of third-party DLLs (see DEPENDENCIES.md)

## check-environment.ps1

Validates your environment for required tools and SDKs.

```powershell
# Quick check
.\Build\scripts\check-environment.ps1

# Detailed output
.\Build\scripts\check-environment.ps1 -Detailed
```

Checks include:
- Lazarus `lazbuild.exe`
- Visual Studio/MSBuild via `vswhere`
- Windows SDK presence
- Optional tools (JDK/WDK)

## Outputs by Component

Main artifact locations under `Cheat Engine/bin/`:

- `lua_extra/`: Lua executables and libraries
- `autorun/dlls/32`, `autorun/dlls/64`: Auto-loaded tools (e.g., `CEJVMTI.dll`)
- `clibs32/`, `clibs64/`: Optional Lua C libraries (e.g., `lfs.dll`)
- `win32/`, `win64/`: Third-party Windows DLLs (e.g., `dbghelp.dll`, `sqlite3.dll`)
- Root `bin/`: Hook DLLs and utilities (e.g., `d3dhook*.dll`, `MonoDataCollector*.dll`)

For full dependency sources and download links, see [DEPENDENCIES.md](DEPENDENCIES.md).
