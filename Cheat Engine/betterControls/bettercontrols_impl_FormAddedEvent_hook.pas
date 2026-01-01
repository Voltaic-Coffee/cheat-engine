unit betterControls;

{$mode delphi}

interface

{$ifdef windows}

uses
  windows,Classes, SysUtils, newRadioButton, newCheckBox, newButton, newListView,
  newEdit, newMainMenu, newForm, newListBox, newProgressBar, newMemo, newComboBox,
  newGroupBox, newSpeedButton, newTreeView, newHeaderControl, newScrollBar,
  newScrollBox, {$ifndef bc_skipsynedit}newSynEdit,{$endif}
  newPageControl, newtabcontrol, newStatusBar,
  newCheckListBox, newCheckGroup, newColorBox, newDirectoryEdit, NewHintwindow,
  newToggleBox, {$ifndef bc_skipvirtualstringtree}newvirtualstringtree,{$endif}
  newPanel, newLabel, newSplitter,
  Graphics, Themes, UxTheme, bettercontrolColorSet, DwmApi;
{$else}
uses {macport,} graphics,math, bettercontrolColorSet;
{$endif}

{$ifdef windows}
type
  TButton=class(TNewButton);
  TCheckBox=class(TNewCheckBox);
  TRadioButton=class(TNewRadioButton);
  TListView=class(TNewListView);
  TEdit=class(TNewEdit);
  TMainMenu=class(TNewMainMenu);
  TMenuItem=class(TNewMenuItem);
  TForm=class(TNewForm);
  TListBox=class(TNewListBox);
  TProgressBar=class(TNewProgressbar);
  TMemo=class(TNewMemo);
  TComboBox=class(TNewComboBox);
  TGroupBox=class(TNewGroupBox);
  TSpeedButton=class(TNewSpeedButton);
  TTreeview=class(TNewTreeView);
  THeaderControl=class(TNewHeaderControl);
  TScrollBar=class(TNewScrollBar);
  TScrollBox=class(TNewScrollBox);
{$ifndef bc_skipsynedit}
  TSynEdit=class(TNewSynEdit);
{$endif}
  TPageControl=class(TNewPageControl);
  TTabControl=class(TNewTabControl);
  TStatusBar=class(TNewStatusBar);
  TCheckListbox=class(TNewCheckListBox);
  TCheckGroup=class(TNewCheckGroup);  //not fully yet (too limited)
  TColorBox=class(TNewColorBox);
  TDirectoryEdit=class(TNewDirectoryEdit);
  THintWindow=class(TNewHintwindow);
  THintWindowClass =class of TNewHintwindow;

  TToggleBox=class(TNewToggleBox);
  {$ifndef bc_skipvirtualstringtree}
  TLazVirtualStringTree=class(TNewLazVirtualStringTree);
  {$endif}

  TPanel=class(TNewPanel);
  TLabel=class(TNewLabel);
  TSplitter=class(TNewSplitter);

{$endif}
var
  globalCustomDraw: boolean;
  currentColorSet: TBetterControlColorSet;

  //color overrides
  clWindowtext: TColor=graphics.clWindowText;
  clWindow: TColor=graphics.clWindow;
  clHighlight: TColor=graphics.clHighlight;
  clBtnFace: TColor=graphics.clBtnFace;
  clBtnText: TColor=graphics.clBtnText;

  ColorSet: TBetterControlColorSet; //set based on querying the system
  clBtnBorder: TColor=graphics.clBtnText;

  darkmodestring: string=''; //contains ' dark' if darkmode is used (used for settings)

{$ifdef windows}

type
  TAllowDarkModeForWindow = function(hwnd: HWND; state: DWORD): BOOL; stdcall;
  TAllowDarkModeForApp = function(state: integer): BOOL; stdcall;
  TFlushMenuThemes = procedure; stdcall;
  TRefreshImmersiveColorPolicyState = procedure; stdcall;
  TShouldAppsUseDarkMode = function: BOOL; stdcall;


var
  RefreshImmersiveColorPolicyState: TRefreshImmersiveColorPolicyState;
  AllowDarkModeForWindow: TAllowDarkModeForWindow;
  AllowDarkModeForApp: TAllowDarkModeForApp;
  FlushMenuThemes: TFlushMenuThemes;
  _ShouldAppsUseDarkMode: TShouldAppsUseDarkMode;


  procedure registerDarkModeHintHandler;
  procedure registerDarkModeFormAddHandler;
  {$endif}

  {$ifdef darwin}
  type BOOL=boolean;
  {$endif}
  function ShouldAppsUseDarkMode:BOOL;
  function incColor(c: tcolor; amount: integer): tcolor;


implementation

{$ifdef windows}
uses forms, controls, StdCtrls, ExtCtrls, ButtonPanel, Buttons, Registry, Win32Proc{$ifndef skip_mainunit2}, mainunit2{$endif};

{$ifdef skip_mainunit2}
const strCheatEngine='Cheat Engine';
{$endif}


var
  FHandle: THandle;
  FLoaded: Boolean;
  darkmodebuggy: boolean;
{$endif}
function inccolor(c: Tcolor; amount: integer): tcolor;
var  R, G, B : Byte;
begin
  RedGreenBlue(ColorToRGB(c), R, G, B);
  R := min(255, Integer(R) + amount);
  G := min(255, Integer(G) + amount);
  B := min(255, Integer(B) + amount);
  Result := RGBToColor(R, G, B);
end;
{$ifdef windows}
procedure RefreshImmersiveColorPolicyState_stub; stdcall;
begin
end;

function AllowDarkModeForWindow_stub(hwnd: HWND; state: DWORD): BOOL; stdcall;
begin
  exit(false);
end;

function AllowDarkModeForApp_stub(state: integer): BOOL; stdcall;
begin
  exit(false);
end;

var UsesDarkMode: (dmUnknown, dmYes, dmNo)=dmUnknown;

{$endif}
function ShouldAppsUseDarkMode:BOOL; stdcall;
{$ifdef windows}
var reg: tregistry;
{$endif}
begin
  {$IFDEF FORCEDDARKMODE}
  UsesDarkMode:=dmYes;
  exit(true);
  {$ENDIF}
  {$ifdef windows}
  if darkmodebuggy then exit(false);

  if UsesDarkMode=dmUnknown then
  begin

    reg:=TRegistry.Create;
    reg.RootKey:=HKEY_CURRENT_USER;
    if reg.OpenKey('Software\Microsoft\Windows\CurrentVersion\Themes\Personalize',false) then
    begin
      if reg.ValueExists('AppsUseLightTheme') then
      begin
        if reg.ReadInteger('AppsUseLightTheme')=0 then
          UsesDarkMode:=dmYes
        else
          UsesDarkMode:=dmNo;
      end;


      if UsesDarkMode=dmUnknown then
      begin
        if reg.ValueExists('SystemUsesLightTheme') then
        begin
          if reg.ReadInteger('SystemUsesLightTheme')=0 then
            UsesDarkMode:=dmYes
          else
            UsesDarkMode:=dmNo;
        end;
      end;
    end;

    reg.free;

    if UsesDarkMode=dmUnknown then
    begin
      UsesDarkMode:=dmNo;
      if assigned(_ShouldAppsUseDarkMode) then
      begin
        if _ShouldAppsUseDarkMode() then
          UsesDarkMode:=dmYes;
      end;
    end;
  end;

  exit(UsesDarkMode=dmyes);
  {$else}
  exit(false);
  {$endif}
end;

{$ifdef windows}


type
  TBCFormEventHandler=class
  private
    procedure ShowHintEvent(var HintStr: string; var CanShow: Boolean; var HintInfo: THintInfo);
    procedure FormAddedEvent(Sender: TObject; Form: TCustomForm);
  end;

procedure TBCFormEventHandler.ShowHintEvent(var HintStr: string; var CanShow: Boolean; var HintInfo: THintInfo);
begin
  if ShouldAppsUseDarkMode then
    HintInfo.HintColor:=ColorSet.TextBackground;
end;

procedure TBCFormEventHandler.FormAddedEvent(Sender: TObject; Form: TCustomForm);

  // Recursively apply dark mode colors to all controls on the form
  procedure ApplyDarkModeToControl(AControl: TControl);
  var
    i: Integer;
    shouldSetFont: Boolean;
  begin
    if AControl = nil then Exit;

    // Helper to determine if we should update font color
    // Only update if current color is default/standard light theme colors
    shouldSetFont := (AControl.Font.Color = clDefault) or
                     (AControl.Font.Color = graphics.clWindowText) or
                     (AControl.Font.Color = graphics.clBlack);

    {$IFDEF DEBUG_DARKMODE}
    OutputDebugString(PChar('  ApplyDarkModeToControl: ' + AControl.ClassName + ' [' + AControl.Name + ']'));
    {$ENDIF}

    // Apply colors based on control type
    if AControl is StdCtrls.TButton then
    begin
      StdCtrls.TButton(AControl).Color := ColorSet.ButtonFaceColorDefault;
      if shouldSetFont then
        AControl.Font.Color := ColorSet.FontColor;
      {$IFDEF DEBUG_DARKMODE}
      OutputDebugString(PChar('    -> Themed TButton'));
      {$ENDIF}
    end
    else if AControl is StdCtrls.TEdit then
    begin
      StdCtrls.TEdit(AControl).Color := ColorSet.EditBackground;
      if shouldSetFont then
        AControl.Font.Color := ColorSet.FontColor;
      {$IFDEF DEBUG_DARKMODE}
      OutputDebugString(PChar('    -> Themed TEdit'));
      {$ENDIF}
    end
    else if AControl is StdCtrls.TMemo then
    begin
      StdCtrls.TMemo(AControl).Color := ColorSet.EditBackground;
      if shouldSetFont then
        AControl.Font.Color := ColorSet.FontColor;
      {$IFDEF DEBUG_DARKMODE}
      OutputDebugString(PChar('    -> Themed TMemo'));
      {$ENDIF}
    end
    else if AControl is StdCtrls.TListBox then
    begin
      StdCtrls.TListBox(AControl).Color := ColorSet.EditBackground;
      if shouldSetFont then
        AControl.Font.Color := ColorSet.FontColor;
      {$IFDEF DEBUG_DARKMODE}
      OutputDebugString(PChar('    -> Themed TListBox'));
      {$ENDIF}
    end
    else if AControl is StdCtrls.TComboBox then
    begin
      StdCtrls.TComboBox(AControl).Color := ColorSet.EditBackground;
      if shouldSetFont then
        AControl.Font.Color := ColorSet.FontColor;
      {$IFDEF DEBUG_DARKMODE}
      OutputDebugString(PChar('    -> Themed TComboBox'));
      {$ENDIF}
    end
    else if AControl is StdCtrls.TCheckBox then
    begin
      if shouldSetFont then
        AControl.Font.Color := ColorSet.FontColor;
      {$IFDEF DEBUG_DARKMODE}
      OutputDebugString(PChar('    -> Themed TCheckBox'));
      {$ENDIF}
    end
    else if AControl is StdCtrls.TRadioButton then
    begin
      if shouldSetFont then
        AControl.Font.Color := ColorSet.FontColor;
      {$IFDEF DEBUG_DARKMODE}
      OutputDebugString(PChar('    -> Themed TRadioButton'));
      {$ENDIF}
    end
    else if AControl is StdCtrls.TGroupBox then
    begin
      if shouldSetFont then
        AControl.Font.Color := ColorSet.FontColor;
      {$IFDEF DEBUG_DARKMODE}
      OutputDebugString(PChar('    -> Themed TGroupBox'));
      {$ENDIF}
    end
    else if AControl is ExtCtrls.TPanel then
    begin
      // Panels with bvNone blend into form, others get slightly lighter color
      if ExtCtrls.TPanel(AControl).BevelOuter = bvNone then
        ExtCtrls.TPanel(AControl).Color := ColorSet.FormBackground
      else
        ExtCtrls.TPanel(AControl).Color := incColor(ColorSet.FormBackground, 8);

      if shouldSetFont then
        AControl.Font.Color := ColorSet.FontColor;
      {$IFDEF DEBUG_DARKMODE}
      OutputDebugString(PChar('    -> Themed TPanel'));
      {$ENDIF}
    end
    else if AControl is StdCtrls.TLabel then
    begin
      if shouldSetFont then
        AControl.Font.Color := ColorSet.FontColor;
      {$IFDEF DEBUG_DARKMODE}
      OutputDebugString(PChar('    -> Themed TLabel'));
      {$ENDIF}
    end
    else if AControl is TCustomButtonPanel then
    begin
      // ButtonPanel contains TBitBtn controls - theme the panel background
      TCustomButtonPanel(AControl).Color := ColorSet.FormBackground;
      if shouldSetFont then
        AControl.Font.Color := ColorSet.FontColor;
      {$IFDEF DEBUG_DARKMODE}
      OutputDebugString(PChar('    -> Themed TButtonPanel'));
      {$ENDIF}
    end
    else if AControl is TBitBtn then
    begin
      // TBitBtn (used in TButtonPanel) - theme like regular buttons
      TBitBtn(AControl).Color := ColorSet.ButtonFaceColorDefault;
      if shouldSetFont then
        AControl.Font.Color := ColorSet.FontColor;
      {$IFDEF DEBUG_DARKMODE}
      OutputDebugString(PChar('    -> Themed TBitBtn'));
      {$ENDIF}
    end
    else if AControl is TGraphicControl then
    begin
      // Generic graphic controls (non-windowed) - just update font
      if shouldSetFont then
        AControl.Font.Color := ColorSet.FontColor;
      {$IFDEF DEBUG_DARKMODE}
      OutputDebugString(PChar('    -> Themed TGraphicControl'));
      {$ENDIF}
    end;

    // Recursively process child controls for windowed controls
    if AControl is TWinControl then
    begin
      for i := 0 to TWinControl(AControl).ControlCount - 1 do
        ApplyDarkModeToControl(TWinControl(AControl).Controls[i]);
    end;
  end;

var
  ldark: DWORD;
  dwmResult: HRESULT;
begin
  {$IFDEF DEBUG_DARKMODE}
  OutputDebugString(PChar('FormAddedEvent called for: ' + Form.ClassName + ' [' + Form.Name + ']'));
  OutputDebugString(PChar('  Form.Handle = ' + IntToStr(Form.Handle)));
  OutputDebugString(PChar('  Form.HandleAllocated = ' + BoolToStr(Form.HandleAllocated, True)));
  OutputDebugString(PChar('  ShouldAppsUseDarkMode = ' + BoolToStr(ShouldAppsUseDarkMode, True)));
  {$ENDIF}

  // Only theme if dark mode is enabled
  if not ShouldAppsUseDarkMode then
    Exit;

  // Ensure handle is created before calling DWM functions
  if not Form.HandleAllocated then
  begin
    {$IFDEF DEBUG_DARKMODE}
    OutputDebugString(PChar('  WARNING: Handle not allocated, forcing creation...'));
    {$ENDIF}
    Form.HandleNeeded;
  end;

  {$IFDEF DEBUG_DARKMODE}
  OutputDebugString(PChar('  After HandleNeeded, Handle = ' + IntToStr(Form.Handle)));
  {$ENDIF}

  // Apply dark titlebar - both AllowDarkModeForWindow and DWM attributes needed
  if AllowDarkModeForWindow(Form.Handle, 1) then
  begin
    {$IFDEF DEBUG_DARKMODE}
    OutputDebugString(PChar('  AllowDarkModeForWindow succeeded'));
    {$ENDIF}
  end
  else
  begin
    {$IFDEF DEBUG_DARKMODE}
    OutputDebugString(PChar('  AllowDarkModeForWindow FAILED'));
    {$ENDIF}
  end;

  // Set DWM titlebar attribute (required for actual titlebar darkening)
  if InitDwmLibrary then
  begin
    {$IFDEF DEBUG_DARKMODE}
    OutputDebugString(PChar('  InitDwmLibrary succeeded'));
    {$ENDIF}
    ldark := 1;
    // Try attribute 20 first (Windows 11), fallback to 19 (Windows 10)
    dwmResult := DwmSetWindowAttribute(Form.Handle, 20, @ldark, sizeof(ldark));
    if dwmResult <> S_OK then
    begin
      {$IFDEF DEBUG_DARKMODE}
      OutputDebugString(PChar('  DwmSetWindowAttribute(20) failed with code: ' + IntToHex(dwmResult, 8)));
      OutputDebugString(PChar('  Trying attribute 19...'));
      {$ENDIF}
      dwmResult := DwmSetWindowAttribute(Form.Handle, 19, @ldark, sizeof(ldark));
      {$IFDEF DEBUG_DARKMODE}
      if dwmResult = S_OK then
        OutputDebugString(PChar('  DwmSetWindowAttribute(19) succeeded'))
      else
        OutputDebugString(PChar('  DwmSetWindowAttribute(19) FAILED with code: ' + IntToHex(dwmResult, 8)));
      {$ENDIF}
    end
    else
    begin
      {$IFDEF DEBUG_DARKMODE}
      OutputDebugString(PChar('  DwmSetWindowAttribute(20) succeeded'));
      {$ENDIF}
    end;
  end
  else
  begin
    {$IFDEF DEBUG_DARKMODE}
    OutputDebugString(PChar('  InitDwmLibrary FAILED'));
    {$ENDIF}
  end;

  // Set form background and font
  {$IFDEF DEBUG_DARKMODE}
  OutputDebugString(PChar('  Setting form colors...'));
  {$ENDIF}
  Form.Color := ColorSet.FormBackground;
  if (Form.Font.Color = clDefault) or
     (Form.Font.Color = graphics.clWindowText) or
     (Form.Font.Color = graphics.clBlack) then
    Form.Font.Color := ColorSet.FontColor;

  // Recursively theme all controls on the form
  {$IFDEF DEBUG_DARKMODE}
  OutputDebugString(PChar('  Theming child controls...'));
  {$ENDIF}
  ApplyDarkModeToControl(Form);

  {$IFDEF DEBUG_DARKMODE}
  OutputDebugString(PChar('FormAddedEvent completed for: ' + Form.ClassName));
  {$ENDIF}
end;

procedure registerDarkModeHintHandler;
var hh: TBCFormEventHandler;
begin
  hh:=TBCFormEventHandler.Create;
  application.AddOnShowHintHandler(hh.ShowHintEvent);
end;

procedure registerDarkModeFormAddHandler;
var hh: TBCFormEventHandler;
begin
  hh:=TBCFormEventHandler.Create;
  screen.AddHandlerFormAdded(hh.FormAddedEvent);
end;

var
  c: TColorRef;
  theme: THandle;
  i: integer;
  reg: TRegistry;

{$endif}
initialization

  //setup ColorSet

  ColorSet.FontColor:=clWindowtext;
  colorset.TextBackground:=clWindow;

  {$ifdef windows}
  darkmodebuggy:=true;
  try
    currentColorSet:=ColorSet;

    RefreshImmersiveColorPolicyState:=@RefreshImmersiveColorPolicyState_stub;
    AllowDarkModeForWindow:=@AllowDarkModeForWindow_stub;
    AllowDarkModeForApp:=@AllowDarkModeForApp_stub;
    FlushMenuThemes:=@RefreshImmersiveColorPolicyState_stub;

    for i:=1 to Paramcount do
      if uppercase(ParamStr(i))='NOTDARK' then exit;

    reg:=tregistry.create;
    try
      Reg.RootKey := HKEY_CURRENT_USER;
      if Reg.OpenKey('\Software\'+strCheatEngine,false) then
      begin
        if reg.ValueExists('Disable DarkMode Support') and
           reg.ReadBool('Disable DarkMode Support') then exit;
      end;
    finally
      reg.free;
    end;


    if WindowsVersion>=wv10 then
    begin
      FHandle := LoadLibrary('uxtheme.dll');
      if FHandle<>0 then
      begin
        @RefreshImmersiveColorPolicyState := GetProcAddress(FHandle, MakeIntResource(104));
        @AllowDarkModeForWindow := GetProcAddress(FHandle, MakeIntResource(133));
        @AllowDarkModeForApp := GetProcAddress(FHandle, MakeIntResource(135));
        @FlushMenuThemes := GetProcAddress(FHandle, MakeIntResource(136));
        @_ShouldAppsUseDarkMode := GetProcAddress(FHandle, MakeIntResource(132));
      end;


      if not assigned(RefreshImmersiveColorPolicyState) then RefreshImmersiveColorPolicyState:=@RefreshImmersiveColorPolicyState_stub;
      if not assigned(AllowDarkModeForWindow) then AllowDarkModeForWindow:=@AllowDarkModeForWindow_stub;
      if not assigned(AllowDarkModeForApp) then AllowDarkModeForApp:=@AllowDarkModeForApp_stub;
      if not assigned(FlushMenuThemes) then FlushMenuThemes:=@RefreshImmersiveColorPolicyState_stub;


      AllowDarkModeForApp({$IFDEF FORCEDDARKMODE}2{$ELSE}1{$ENDIF});  //3 is disable, 2=force on, 1=system default


      FlushMenuThemes;
      RefreshImmersiveColorPolicyState;

      darkmodebuggy:=false;

      theme:=OpenThemeData(0,'ItemsView');
      if theme<>0 then
      begin
        GetThemeColor(theme, 0,0,TMT_TEXTCOLOR,ColorSet.FontColor);
        GetThemeColor(theme, 0,0,TMT_FILLCOLOR,ColorSet.TextBackground);
        colorset.InactiveFontColor:=ColorSet.FontColor xor clInactiveFontMask;
        ColorSet.ButtonBorderColor:=deccolor(ColorSet.FontColor,10);

        clwindowText:=ColorSet.FontColor;

        CloseThemeData(theme);

        if ShouldAppsUseDarkMode() then
        begin
          ColorSet.CheckboxFillColor:=clCheckboxFillDark;
          ColorSet.InactiveCheckboxFillColor:=clInactiveCheckboxFillDark;

          // Initialize edit and form backgrounds
          ColorSet.EditBackground:=ColorSet.TextBackground;
          ColorSet.FormBackground:=clFormBackgroundDark;
          ColorSet.HighlightColor:=incColor(ColorSet.TextBackground, 32);

          // Dark mode color variants (from bettercontrolcolorset.pas constants)
          ColorSet.Red:=clRedDark;
          ColorSet.Green:=clGreenDark;
          ColorSet.Lime:=clLimeDark;
          ColorSet.Blue:=clBlueDark;
          ColorSet.Yellow:=clYellowDark;
          ColorSet.Teal:=clTealDark;
          ColorSet.Orange:=clOrangeDark;
          ColorSet.Purple:=clPurpleDark;

          // Semantic color mappings
          ColorSet.StatusOK:=ColorSet.Green;
          ColorSet.StatusWarning:=ColorSet.Orange;
          ColorSet.StatusError:=ColorSet.Red;
          ColorSet.ValidationError:=ColorSet.Red;

          clBtnFace:=inccolor(ColorSet.TextBackground,8);
          clBtnText:=ColorSet.FontColor;
          clBtnBorder:=clBtnBorderDark;
          clWindow:=colorset.TextBackground;

          ColorSet.CheckboxCheckMarkColor:=InvertColor(ColorSet.CheckboxFillColor);
          ColorSet.InactiveCheckboxCheckMarkColor:=InvertColor(ColorSet.CheckboxCheckMarkColor);

          darkmodestring:=' dark';
        end
        else
        begin
          // Light mode: use standard colors from Graphics unit
          ColorSet.EditBackground:=ColorSet.TextBackground;
          ColorSet.FormBackground:=clBtnFace;
          ColorSet.HighlightColor:=clHighlight;

          // Standard color variants from Graphics unit
          ColorSet.Red:=clRed;
          ColorSet.Green:=clGreen;
          ColorSet.Lime:=clLime;
          ColorSet.Blue:=clBlue;
          ColorSet.Yellow:=clYellow;
          ColorSet.Teal:=clTeal;
          ColorSet.Orange:=clOrange;
          ColorSet.Purple:=clPurple;

          // Semantic color mappings
          ColorSet.StatusOK:=ColorSet.Green;
          ColorSet.StatusWarning:=ColorSet.Orange;
          ColorSet.StatusError:=ColorSet.Red;
          ColorSet.ValidationError:=ColorSet.Red;
        end;
      end;
    end;


  except

  end;
  {$endif}
end.

