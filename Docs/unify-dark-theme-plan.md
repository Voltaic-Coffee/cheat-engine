# Unify dark-theme behaviour across all Cheat Engine forms

## Context

Users report inconsistent visuals when Cheat Engine runs in Windows dark mode: text inside `TEdit`/`TMemo`/`TListBox` stays black on dark backgrounds, checkboxes look bright-white on dark forms, some form titlebars are dark and others light, and pre-built `.frm` forms plus cheat-table-embedded forms don't pick up the theme. Investigation confirms five concrete defects and one missing hook — all in the `betterControls` / `TCEForm` theming subsystem. No third-party framework change is required.

Root causes:

1. `font.color := ColorSet.FontColor` is commented-out in `TNewEdit`, `TNewMemo`, `TNewListBox` (background is themed, foreground is not → unreadable text).
2. Checkbox fill colors are hardcoded to light grays (`$e8e8e8`, `$999999`) inside the dark-mode branch.
3. `TNewForm.Create` calls `DwmSetWindowAttribute(handle, 19, ...)` but `TNewForm.CreateNew` calls it with `20`; `formdesignerunit.pas` uses `19`. Attribute 20 is the official Win10 2004+ value; 19 is the pre-release fallback. Depending on OS version and which constructor ran, the titlebar may or may not darken.
4. `TCEForm.LoadFromStream` and `TCEForm.LoadFromFileLFM` apply a `Color=clDefault → clWindow` substitution, but `TCEForm.LoadFromXML` (used for cheat-table-embedded forms via `OpenSave.pas:448`) does not — so those forms never get themed.
5. Theming only ever touches the form's own `Color` / `Font.Color`. Child controls whose color came from the binary `.frm` blob (or `.lfm`) as `clDefault` are never recolored.
6. A `FormAddedEvent` handler exists in `bettercontrols.pas:223–233` with its dark-mode body commented out (`//todo`), and `registerDarkModeFormAddHandler` is defined but never called — so there is no global safety net for forms that bypass `TNewForm`.

## Approach

Six-file patch, no `.lfm` edits, no `.frm` regeneration. All new code paths gate on `ShouldAppsUseDarkMode` (which returns `false` off Windows), so Linux/macOS builds are unaffected.

Introduce two shared helpers in `bettercontrols.pas`:

- `SetWindowDarkTitlebar(h: HWND)` — tries DWMWA attribute 20 first, falls back to 19 on failure. Unifies every `DwmSetWindowAttribute` call site.
- `ApplyThemeRecursive(c: TComponent)` — walks a component tree and substitutes `clDefault` values only. Conservative: hardcoded colors (hex-dump black, assembly view, etc.) are preserved.

Extract the self-coloring block from the three `TCEForm` loaders into a private `ApplyThemeColorsToSelf` that also invokes `ApplyThemeRecursive(self)` after deserialisation — this themes both the form and its child controls, including `.frm`-loaded and cheat-table-embedded forms.

Re-enable `FormAddedEvent` (wired through the new `ApplyThemeRecursive`) as a safety net and actually call `registerDarkModeFormAddHandler` at startup.

## File-by-file changes

### 1. `Cheat Engine/betterControls/newedit.pas`
Line 35 — uncomment:
```pascal
      font.color:=ColorSet.FontColor;
```

### 2. `Cheat Engine/betterControls/newmemo.pas`
Line 36 — uncomment:
```pascal
      font.color:=colorset.FontColor;
```

### 3. `Cheat Engine/betterControls/newlistbox.pas`
Line 36 — uncomment:
```pascal
    font.color:=colorset.FontColor;
```

### 4. `Cheat Engine/betterControls/bettercontrols.pas`

**4a. Checkbox palette (lines 330–331)** — derive from the dark background instead of hardcoding light gray:
```pascal
      ColorSet.CheckboxFillColor:=inccolor(ColorSet.TextBackground, 24);
      ColorSet.InactiveCheckboxFillColor:=inccolor(ColorSet.TextBackground, 12);
```
The existing `InvertColor` on lines 339–340 will then produce a light check-glyph on the darker fill.

**4b. Add `DwmApi` to the windows implementation `uses`** (line 109, next to `forms, controls, Registry, Win32Proc`).

**4c. Declare two new helpers in the interface section** (near line 102–103):
```pascal
procedure SetWindowDarkTitlebar(h: HWND);
procedure ApplyThemeRecursive(c: TComponent);
```

**4d. Implementation (place above `initialization`, inside the existing `{$ifdef windows}` block):**
```pascal
procedure SetWindowDarkTitlebar(h: HWND);
var ldark: DWORD;
begin
  if not ShouldAppsUseDarkMode then exit;
  if h=0 then exit;
  if not InitDwmLibrary then exit;
  ldark:=1;
  if DwmSetWindowAttribute(h, 20, @ldark, sizeof(ldark)) <> S_OK then
    DwmSetWindowAttribute(h, 19, @ldark, sizeof(ldark));
end;

procedure ApplyThemeRecursive(c: TComponent);
var i: integer; ctl: TControl;
begin
  if c=nil then exit;
  if not ShouldAppsUseDarkMode then exit;
  if c is TControl then
  begin
    ctl:=TControl(c);
    if ctl.Color=clDefault then
      ctl.Color:=ColorSet.TextBackground;
    if (not ctl.ParentFont) and (ctl.Font.Color=clDefault) then
      ctl.Font.Color:=ColorSet.FontColor;
  end;
  for i:=0 to c.ComponentCount-1 do
    ApplyThemeRecursive(c.Components[i]);
end;
```

**4e. Replace `FormAddedEvent` body (lines 223–233):**
```pascal
procedure TBCFormEventHandler.FormAddedEvent(Sender: TObject; Form: TCustomForm);
begin
  if not ShouldAppsUseDarkMode then exit;
  if Form=nil then exit;
  if Form.Color=clDefault then
    Form.Color:=$242424;
  if (not Form.ParentFont) and (Form.Font.Color=clDefault) then
    Form.Font.Color:=ColorSet.FontColor;
  if Form.HandleAllocated then
    SetWindowDarkTitlebar(Form.Handle);
  ApplyThemeRecursive(Form);
end;
```

### 5. `Cheat Engine/betterControls/newform.pas`
Replace the DWM blocks at lines 42–46 and 60–65 (in both `Create` and `CreateNew`) with a single call:
```pascal
    SetWindowDarkTitlebar(handle);
```
Remove `DwmApi` from the `uses` (line 25) — the dependency now lives in `bettercontrols.pas`.

### 6. `Cheat Engine/formdesignerunit.pas`
Lines 1258–1262 — replace the inline DWM call with:
```pascal
        SetWindowDarkTitlebar(handle);
```
(`betterControls` is already imported by this unit.)

### 7. `Cheat Engine/ceguicomponents.pas`

**7a. Add private method declaration** inside `TCEForm` (around line 618):
```pascal
    procedure ApplyThemeColorsToSelf;
```

**7b. Add implementation just before `LoadFromStream` (~line 1411):**
```pascal
procedure TCEForm.ApplyThemeColorsToSelf;
begin
  if not ShouldAppsUseDarkMode then exit;
  if color=clDefault then
  begin
    color:=clWindow;
    font.color:=clWindowtext;
  end;
  ApplyThemeRecursive(self);
end;
```

**7c. Replace the inline substitutions at three sites:**
- `LoadFromStream` (lines 1433–1438): replace the whole `if ShouldAppsUseDarkMode … end;` block with `ApplyThemeColorsToSelf;`.
- `LoadFromFileLFM` (lines 1469–1474): same replacement.
- `LoadFromXML` (after `RestoreToDesignState;` on line 1367, before `active:=wasActive;`): add `ApplyThemeColorsToSelf;`. This is the fix that themes `.frm`-loaded and cheat-table-embedded forms; the call must come *after* `RestoreToDesignState` because child controls don't exist before then.

### 8. `Cheat Engine/cheatengine.lpr`
Line 303 currently calls `registerDarkModeHintHandler;`. Add immediately after:
```pascal
  registerDarkModeFormAddHandler;
```
(The procedure is already defined in `bettercontrols.pas:242`; it is just never invoked today.)

## Existing helpers reused

- `incColor` / `InvertColor` — `Cheat Engine/betterControls/bettercontrols.pas:121` for deriving palette values.
- `ShouldAppsUseDarkMode` — `Cheat Engine/betterControls/bettercontrols.pas:148`, central dark-mode predicate.
- `InitDwmLibrary` — standard Lazarus `DwmApi` helper.
- `TBCFormEventHandler.FormAddedEvent` + `registerDarkModeFormAddHandler` — already wired into `Screen.AddHandlerFormAdded`, just dormant.
- `RestoreToDesignState` — `TCEForm` method that rebuilds child components from `saveddesign`; reuse as the anchor before `ApplyThemeRecursive`.

## Implementation order (each step a separate commit, bisectable)

1. Uncomment the three `font.color` lines (§1–3). Rebuild; open *Settings* and confirm light text in edits/memos/listboxes.
2. Fix the checkbox palette (§4a). Rebuild; confirm checkboxes are no longer bright-white on dark forms.
3. Add `SetWindowDarkTitlebar` + migrate the three call sites (§4b–d partial, §5, §6). Rebuild on both a modern and older Win10 if available; confirm titlebar darkens in all three construction paths.
4. Add `ApplyThemeColorsToSelf` and migrate the two existing loaders; add the new call in `LoadFromXML` (§7 without yet introducing `ApplyThemeRecursive` into it). Reload a cheat table with an embedded form; confirm the form itself is dark.
5. Add `ApplyThemeRecursive` and invoke it from `ApplyThemeColorsToSelf` (§4d `ApplyThemeRecursive` + the call in §7b). Open `DotNetInfo.frm` and `JavaInfo.frm` via the autorun path; confirm child controls themed. Open the Memory Viewer hex dump; confirm the intentional black region is still black (validates the conservative `clDefault`-only rule).
6. Re-enable `FormAddedEvent` and register it (§4e, §8). Open About / Advanced Options; confirm no flicker or double-theming.

If step 5 regresses a specialist viewer, the single point of rollback is that commit — the `clDefault` guard is the only new policy it introduces.

## Verification

No automated tests (`appveyor.yml: test: off`). Manual desktop verification on Windows 10+ with dark mode on.

Enable dark mode:
- Registry: `HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize\AppsUseLightTheme = 0`, then relaunch CE.
- Or compile with `-dFORCEDDARKMODE` (gate in `bettercontrols.pas:153`).

Forms to open and expected state:

| Form | How to open | Expected |
|---|---|---|
| About | Help → About | Dark titlebar, dark body, light text |
| Settings | Edit → Settings | Every tab dark; `TEdit` / `TListBox` text light on dark |
| Advanced Options | Settings → Extra | Dark bg; checkboxes readable (not bright white) |
| Memory Viewer | Ctrl-M | Dark titlebar; hex dump region **still black** (authored color) |
| Memory Browser | View → Memory Browser | Dark titlebar; grid cells keep authored palette |
| Trainer Generator | Tools → Generate Trainer | Dark (this is the one `TCEForm`-inheriting built-in form) |
| Form designer | Table → Add form | Dark titlebar via migrated `SetWindowDarkTitlebar` site |
| DotNetInfo.frm | Attach to .NET process → .NET Info | Dark body **and** dark children (the `.frm` fix) |
| JavaInfo.frm | Attach to JVM → Java Info | Same as above |
| Cheat-table-embedded form | Open a `.CT` that contains a `<Forms>` section | Dark (the `LoadFromXML` fix) |

Non-Windows regression check: build on Linux/macOS; `ShouldAppsUseDarkMode` returns `false`; every new helper early-outs; no `DwmApi` call attempted.

## Out of scope

- The 59 hardcoded `Color=…` properties in `.lfm` files. Many are intentional (hex dump, assembly view); blanket editing would trigger Lazarus re-serialisation churn forbidden by CLAUDE.md §5b. Any genuinely mis-themed `.lfm` is a separate targeted PR.
- Regenerating the five binary `.frm` files. The runtime loader fix themes them without touching the blobs.
- Full dark-mode support on Linux/macOS (`ShouldAppsUseDarkMode` stays stubbed to `false` there).
- Plugins that create raw HWNDs without registering the form with `Screen` — the `FormAddedEvent` safety net only catches forms added to the application's screen.
- Syntax-highlighted editors (`TNewSynEdit`) — own color pipeline; not touched.
- Hover/focus colors of `TNewButton` / `TNewSpeedButton` — not a reported issue.

## Residual risk

- `ApplyThemeRecursive` descends into non-visual components (timers, datamodules). The `if c is TControl` guard skips them for color work but still recurses — correct for nested frames/panels.
- `FormAddedEvent` may fire before a form's handle is allocated; the `HandleAllocated` guard avoids a premature DWM call. Color assignments are safe pre-handle.
- A form created via `TNewForm.Create` will run both constructor theming and `FormAddedEvent`. Both paths are idempotent and `clDefault`-gated, so double-execution is a no-op.
