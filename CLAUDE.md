# CLAUDE.md

Guidance for AI assistants working in this repository. For end-user build instructions see `README.md` (English) or `READMEes.md` (Spanish).

## 1. Project Overview

This is the upstream source for **Cheat Engine** — a cross-platform memory scanner, debugger, and modding environment. The repository contains four loosely-coupled subsystems:

- a **Free Pascal / Lazarus** desktop GUI (the main app) targeting Windows, Linux, macOS, and Android;
- an optional **Windows kernel driver** (`DBKKernel/`) for ring‑0 memory access;
- an optional **hardware hypervisor** (`dbvm/`, plus a UEFI variant in `DBVM UEFI/`) using Intel VT‑x / AMD‑V;
- an **embedded Lua scripting engine** (Lua 5.1 in `lua/`, Lua 5.3 vendored under `Cheat Engine/lua53/`).

The main application is Windows-first but cross-compiled to other OSes. Helper libraries written in C, C++, C#, and CUDA live alongside the Pascal core.

## 2. Repository Layout

| Path | Purpose | Language / Tooling |
|---|---|---|
| `Cheat Engine/` | Main GUI app + all helper DLL/EXE sub‑projects | Free Pascal (Lazarus), C/C++, C# |
| `DBKKernel/` | Windows ring‑0 kernel driver | C + WDK / Visual Studio |
| `dbvm/` | Hardware hypervisor (VT‑x / AMD‑V) | C + x86/x64 ASM + GNU Make |
| `DBVM UEFI/` | UEFI build variant of DBVM | C + ASM (Eclipse CDT project) |
| `lua/` | Vendored Lua 5.1 source | C |
| `.github/` | `FUNDING.yml` only — no CI workflows here | — |
| `appveyor.yml` | AppVeyor Windows CI config | — |
| `README.md` / `READMEes.md` | End-user build instructions (EN/ES) | — |
| `.gitmodules` | Present but empty — no submodules | — |

## 3. Primary Toolchain

- **Lazarus 2.2.2 + FPC 3.2.2** for every `.lpi` / `.lpr` project. Install the Windows 64‑bit base plus the `cross-i386-win32-win64` add‑on (see `README.md:40`).
- **Visual Studio 2017** for `.sln` / `.vcxproj` projects (DBKKernel, DirectXMess, DotNetCompiler, DotNetDataCollector, DotNetInvasiveDataCollector, MonoDataCollector, cejvmti, tcclib).
- **GNU Make** for `dbvm/` (`dbvm/Makefile`).
- **CI:** `appveyor.yml` uses an older Lazarus 1.6.4 / FPC 3.0.2 snapshot and recursively builds every `*.lpi` with `lazbuild --build-all` (`appveyor.yml:48`). `test: off` — the CI runs no tests.

## 4. Entry Points & Key Projects

### Main application
- `Cheat Engine/cheatengine.lpi` → `Cheat Engine/cheatengine.lpr` — open this in Lazarus; Shift+F9 to build, or `Run → Compile many Modes` (first three modes typically).
- `Cheat Engine/MainUnit.pas` (+ `MainUnit.lfm`) — main window.
- Build output: `Cheat Engine/bin/`.

### Android JNI library
- `Cheat Engine/cecore.lpi` / `cecore.lpr`.

### Secondary Lazarus projects (build each separately for 32‑bit AND 64‑bit)
- `Cheat Engine/speedhack/speedhack.lpi` — speedhack DLL.
- `Cheat Engine/luaclient/luaclient.lpi` — enables `{$luacode}` scripting.
- `Cheat Engine/VEHDebug/vehdebug.lpi` — VEH debugger interface.
- `Cheat Engine/allochook/allochook.lpi` — allocation hooking.
- `Cheat Engine/launcher/cheatengine.lpi` — lightweight launcher.
- `Cheat Engine/cepack/cepack.lpi`, `Cheat Engine/xmplayer/`, `Cheat Engine/winhook/`, `Cheat Engine/windowsrepair/`, `Cheat Engine/Tutorial/`, `Cheat Engine/debuggertest/`, `Cheat Engine/ceregreset/`.

### Secondary Visual Studio projects
- `DBKKernel/DBKKernel.sln` — kernel driver (build the "no‑sig" variant during development; requires test‑signing mode or a signed driver to load).
- `Cheat Engine/Direct x mess/DirectXMess.sln` — D3D9/10/11 overlay hooks.
- `Cheat Engine/DotNetCompiler/DotNetCompiler.sln` — `cscompile` Lua command.
- `Cheat Engine/MonoDataCollector/monodatacollector.sln` — Mono inspection.
- `Cheat Engine/DotNetDataCollector/dotnetdatacollector.sln` — .NET symbols.
- `Cheat Engine/DotNetInvasiveDataCollector/dotnetinvasivedatacollector.sln` — runtime JIT support.
- `Cheat Engine/Java/cejvmti.sln` — JVM inspection.
- `Cheat Engine/tcclib/tcclib.sln` — `{$C}` / `{$CCODE}` inline C support.

## 5. Major Subsystems

### Memory scanning / debugger core
- `Cheat Engine/memscan.pas` — user-mode scanner.
- `Cheat Engine/CEDebugger.pas`, `Cheat Engine/DebuggerInterface.pas`, `Cheat Engine/DebuggerInterfaceAPIWrapper.pas`.

### Assembler / Disassembler
- `Cheat Engine/Assemblerunit.pas`, `Cheat Engine/Assembler.pas`.
- `Cheat Engine/disassembler.pas`, `Cheat Engine/DisassemblerArm.pas`.

### Lua integration
- `Cheat Engine/LuaHandler.pas` — central dispatcher (> 9 000 lines).
- `Cheat Engine/LuaClass.pas`, `Cheat Engine/LuaCaller.pas` — class-binding / callback plumbing.
- ~100 `Lua*.pas` binding units expose GUI, canvas, memory view, disassembler, memory record, stream, structure, byte table, memscan, thread, internet, and SQL APIs to scripts.
- `lua/` — Lua 5.1 vendored source.
- `Cheat Engine/lua53/` — Lua 5.3 vendored source (used by newer binding paths).

### Autorun Lua scripts
- `Cheat Engine/bin/autorun/*.lua` — executed at startup; edits here change shipped behaviour without recompiling. Notable: `monoscript.lua`, `java.lua`, `pseudocodediagram.lua`, `DotNetInterface.lua`, `JavaInfo.lua`, `ceshare.lua`.
- `Cheat Engine/bin/autorun/forms/*.frm` — pre-built forms (see §5a).

### 5a. Form creator & runtime form loading

Cheat Engine ships an in-app **form designer** so users (and `.CT` cheat tables) can build custom UIs without recompiling. Designed forms are serialised to a binary blob (Lazarus `LRS` component stream) and either saved as a `.frm` file, embedded in a cheat table's XML, or handed to a Lua script that instantiates them at runtime.

- **Designer UI:** `Cheat Engine/formdesignerunit.pas` (+ `.lfm`) — drag‑and‑drop editor built on JEDI's `JvDesignSurface`.
- **Serialisable base form:** `Cheat Engine/ceguicomponents.pas` — defines `TCEForm` (descendant of `TForm`). Key methods:
  - `SaveCurrentStateasDesign` — writes the component tree to the `savedDesign` `TMemoryStream` via `WriteComponentAsBinaryToStreamWithMethods` (LRS binary format).
  - `SaveToStream` / `LoadFromStream` — XML wrapper around the binary blob (used for in-memory round-tripping and `.frm` files).
  - `SaveToFile` / `LoadFromFile` / `SaveToFileLFM` / `LoadFromFileLFM` — file I/O plus binary⇄text conversion through `LRSObjectBinaryToText` / `LRSObjectTextToBinary`.
  - `SaveToXML` / `LoadFromXML` — DOM-level read/write used when forms are embedded in a larger document.
- **Cheat-table embedding:** `Cheat Engine/OpenSave.pas` — `LoadXML` walks `<Forms>` nodes in a `.CT` / `.CETRAINER` file, instantiates `TCEForm.createnew(nil)` per form, calls `f.LoadFromXML(form)`, and registers it in `mainform.LuaForms`. The binary form data is Ascii85-encoded inside the XML.
- **Lua bindings:** `Cheat Engine/LuaForm.pas` — exposes `createFormFromFile(filename)`, `createFormFromStream(stream)`, and `form:saveToStream(s)` to Lua; `TCEForm` is surfaced through the `LuaClass` binding system.
- **Shipped pre-built forms:** `Cheat Engine/bin/autorun/forms/*.frm` (e.g. `DotNetInfo.frm`) — XML files with Ascii85-encoded binary form data in a `<FormData>` node, loaded at startup by matching autorun Lua scripts.

### 5b. Theme / skin / dark-mode system

The app has its own custom-drawn control set (`betterControls`) with a global colour palette that adapts to Windows/macOS dark mode at startup. There is **no dedicated theme editor UI** — theme is system-detected.

- **Palette + detection:** `Cheat Engine/betterControls/bettercontrols.pas` — owns the global `currentColorSet: TBetterControlColorSet`, the `globalCustomDraw` flag, and `ShouldAppsUseDarkMode()` (reads `AllowDarkModeForWindow` / `_ShouldAppsUseDarkMode` via WinAPI on Windows, system settings on macOS). Initialises palette entries from Windows UxTheme constants.
- **Palette record:** `Cheat Engine/betterControls/bettercontrolcolorset.pas` — the `TBetterControlColorSet` shape (button/checkbox/edit states, active/inactive variants).
- **Custom controls:** `Cheat Engine/betterControls/new*.pas` (30+ units — `TNewButton`, `TNewCheckBox`, `TNewEdit`, `TNewForm`, …). On Windows they custom-paint using `currentColorSet`; on non‑Windows they fall back to native rendering.
- **DPI scaling:** `Cheat Engine/DPIHelper.pas` — `getDPIScaleFactor` (`screen.PixelsPerInch / 96`) plus helpers to rescale toolbars, buttons, combos, edits for high-DPI displays.
- **Application to forms:** `TCEForm` in `ceguicomponents.pas` checks `ShouldAppsUseDarkMode()` inside `LoadFromStream` / `LoadFromFileLFM` — if the form's colour is `clDefault`, it substitutes `clWindow` / `clWindowText` so themed colours win. Because both `TCEForm` and the form designer use `betterControls` transitively, **user-designed Lua forms inherit the theme automatically** — no explicit `ApplyTheme` call is needed.

### Plugin SDK
- `Cheat Engine/plugin/cepluginsdk.pas`, `cepluginsdk.h` — C / Pascal headers.
- `Cheat Engine/plugin/plugin.pas`, `pluginexports.pas` — interface + exported functions.
- `Cheat Engine/plugin/example*/` — C / C++ / Pascal / .NET sample plugins.

### Windows kernel driver (DBKKernel)
- `DBKKernel/DBKDrvr.c` — driver entry / dispatcher.
- `DBKKernel/IOPLDispatcher.c` — I/O privilege‑level dispatch.
- `DBKKernel/debugger.c`, `DBKKernel/memscan.c`, `DBKKernel/ultimap2.c`, `DBKKernel/vmxhelper.c`, `DBKKernel/vmxoffload.c`.
- Architecture-specific code: `DBKKernel/i386/`, `DBKKernel/amd64/`.
- `DBKKernel/DBK32.inf`, `DBKKernel/DBK64.inf` — driver install info.

### DBVM hypervisor
- `dbvm/vmm/` — VMM core (`vmeventhandler.c`, `vmxemu.c`, `paging.c`, `luahandler.c`, …).
- `dbvm/vmloader/` — load path into kernel mode.
- `dbvm/bootsector/` — x86 bootloader (ASM).
- `dbvm/imagemaker/` — tools that build bootable DBVM disk images.
- `dbvm/Makefile` — top-level build (release, USB, QEMU, CD targets).
- `DBVM UEFI/` — UEFI variant (Eclipse CDT project, `main.c`, `dbvmoffload.c`, ASM helpers).

### Other native helpers
- `Cheat Engine/Direct x mess/` — D3D9/10/11 overlay + snapshot hook DLLs.
- `Cheat Engine/ceserver/` — remote debugging server (C, Linux/Android).
- `Cheat Engine/CUDA pointerscan/` — GPU-accelerated pointer scan (CUDA / C++).

## 6. Pascal / Lazarus Conventions & Gotchas

Most foot‑guns here come from Lazarus's file bookkeeping:

- **Form file trio:** each UI unit is `Foo.pas` (code) + `Foo.lfm` (form layout, text‑serialised) + `Foo.lrt` (translation strings, **auto‑generated**). Do not hand‑edit `.lrt` — Lazarus regenerates it. Do edit `.lfm`, but preserve its exact indentation.
- **Lazarus rewrites files on open.** Upstream README warns: *"Lazarus auto‑modifies files when opened; make only necessary changes"*. Do not commit incidental re‑serialisation churn in `.lpi` / `.lfm` files after merely opening them in the IDE — stage hunks deliberately.
- **`.lpi` vs `.lps`:** `.lps` is per‑user session state (in `.gitignore`; never add it). `.lpi` is the versioned project file; edits should be reviewed.
- **Line endings:** CRLF (Windows project). Preserve existing endings; do not bulk-convert.
- **`uses` clauses:** when adding a new unit, update `uses` sections *and* the relevant `.lpi` `<Units>` list if the file is wholly new.
- **`Cheat Engine/bin/` contents:** DLLs, EXEs, and some Lua scripts are committed. Lua files under `bin/autorun/` and `.frm` files under `bin/autorun/forms/` are **source** (do edit); compiled `.dll` / `.exe` are build outputs (do **not** hand-edit).
- **Encoding:** Pascal sources are mostly ANSI / Windows‑1252. Be careful with non-ASCII characters.
- **Naming:** Pascal is case-insensitive, but the codebase uses PascalCase for types / methods and camelCase or lower-case for locals. Match surrounding style.

## 7. Build Workflow (typical contributor flow)

Condensed from `README.md:38-61`:

1. Install Lazarus 2.2.2 + FPC 3.2.2 (win64 installer + i386 cross add-on).
2. Open `Cheat Engine/cheatengine.lpi`; build with Shift+F9 or `Run → Compile many Modes` (first three modes typically cover 32/64-bit Windows).
3. Run Lazarus as Administrator if you need to debug from the IDE on Windows.
4. Build required sibling Lazarus projects (`speedhack`, `luaclient`, `VEHDebug`, `allochook`) separately for both 32‑ and 64‑bit.
5. For Mono / .NET / Java / TCC / DirectX features, build the corresponding `.sln` in Visual Studio 2017.
6. For kernel-mode features, build `DBKKernel.sln` (no‑sig variant) and enable Windows test‑signing mode or sign the driver yourself.

## 8. Testing

- The repo ships **no automated test suite**. `appveyor.yml` has `test: off`.
- Manual verification tooling:
  - `Cheat Engine/Tutorial/tutorial.lpi` — the well-known Cheat Engine Tutorial executable.
  - `Cheat Engine/debuggertest/debuggertest.lpi` — debugger harness.
- Code changes are usually validated manually: build, attach to a test process, exercise the affected feature.

## 9. Contribution & Git Workflow

- Fork → feature branch → PR back to upstream (`cheat-engine/cheat-engine`), per `README.md`.
- Keep diffs minimal; **do not commit Lazarus re‑serialisation churn**.
- `.github/` contains only `FUNDING.yml` — no issue / PR templates or CODEOWNERS to follow.
- `.gitmodules` exists but is empty; the repo has no submodules.

## 10. Things to Avoid

- Editing `*.lrt` files (auto-generated).
- Editing compiled artefacts in `Cheat Engine/bin/*.dll`, `*.exe`.
- Reformatting `.lfm` / `.lpi` files wholesale.
- Assuming a Unix toolchain — the main project targets Windows first.
- Running the built executables inside sandboxes or standard CI — Cheat Engine needs Administrator / ring‑0 / hypervisor privileges that most CI environments cannot provide.
