# Cheat Engine Build Helper System

Centralized build system for Cheat Engine, including PowerShell scripts and configuration. This README is the main entry point; it links to focused docs for details.

## Table of Contents

- [Quick Start](#quick-start) — minimal commands to build
- [Documentation](#documentation) — detailed guides and references
- [Dependencies](#dependencies) — required tools and third‑party DLLs
- [Scripts](#scripts) — build script overview
- [Outputs](#outputs) — where artifacts go and what to expect
- [IDE Build](#ide-build-lazarus) — building from Lazarus
- [Troubleshooting](#troubleshooting) — common issues and fixes
- [Contributing and Support](#contributing-and-support)

## Documentation

Detailed guides are in `Build/docs/`:

- [QUICKSTART.md](docs/QUICKSTART.md) — step-by-step first-time build guide
- [DEPENDENCIES.md](docs/DEPENDENCIES.md) — complete list of required software and libraries
- [SCRIPTS.md](docs/SCRIPTS.md) — detailed reference for all build scripts
- [MANUAL_BUILD.md](docs/MANUAL_BUILD.md) — building manually with IDEs (without scripts)
- [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) — solutions to common build problems

## Quick Start

Build everything from an elevated PowerShell prompt:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
./Build/scripts/check-environment.ps1 -Detailed
./Build/scripts/build-all.ps1
```

- For a clean rebuild: `./Build/scripts/build-all.ps1 -Clean`
- To build specific parts: `./Build/scripts/build-all.ps1 -Only lua,vs`

See the step-by-step guide in [docs/QUICKSTART.md](docs/QUICKSTART.md).

For manual builds without scripts, see [docs/MANUAL_BUILD.md](docs/MANUAL_BUILD.md).

## Dependencies

Required software (Lazarus/FPC, Visual Studio, Windows SDK) and optional tooling (JDK, WDK), plus runtime DLLs, are documented in detail in [docs/DEPENDENCIES.md](docs/DEPENDENCIES.md).

Highlights:
- Windows 10+ (64-bit), 8 GB RAM minimum
- Lazarus 2.2.2 + FPC 3.2.2
- Visual Studio 2017+ with C++ and .NET workloads

## Scripts

All scripts live in `Build/scripts/`. For options, examples, and outputs, see [docs/SCRIPTS.md](docs/SCRIPTS.md).

Common commands:

```powershell
# Master build
./Build/scripts/build-all.ps1 [-Clean] [-Verbose] [-Only lua,vs,lazarus,deps]

# Individual components
./Build/scripts/build-lua53.ps1
./Build/scripts/build-vs-projects.ps1 [-Projects DirectXMess,CEJVMTI]
./Build/scripts/build-lazarus-projects.ps1 [-Projects speedhack,luaclient] [-SkipCheatEngine]
./Build/scripts/build-dependencies.ps1 [-SkipTCC]
```

## Outputs

Artifacts are placed under `Cheat Engine/bin/`:

```
Cheat Engine/bin/
├── lua_extra/              # Lua executables and libraries
├── autorun/dlls/           # Auto-loaded DLLs
│   ├── 32/
│   └── 64/
├── clibs32/                # 32-bit C libraries
├── clibs64/                # 64-bit C libraries
├── win32/                  # 32-bit Windows dependencies
├── win64/                  # 64-bit Windows dependencies
├── *.dll                   # Various DLLs (speedhack, luaclient, etc.)
└── *.exe                   # Executables
```

For a component-to-output map, see [docs/SCRIPTS.md](docs/SCRIPTS.md). For sources of third‑party DLLs, see [docs/DEPENDENCIES.md](docs/DEPENDENCIES.md).

## IDE Build (Lazarus)

You can build the main application from the IDE:

1. Open `Cheat Engine/cheatengine.lpi` in Lazarus
2. Run → Compile many Modes (select first three) or Run → Build (Shift+F9)

Note: Run Lazarus as Administrator for debugging and runtime features.

## Troubleshooting

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for common issues (MSBuild, lazbuild, missing DLLs) and fixes. Use `-Verbose` on scripts to collect logs.
