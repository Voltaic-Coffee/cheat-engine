unit newForm;

{$mode objfpc}{$H+}

interface

uses
  jwawindows, windows, Classes, SysUtils, forms, controls, messages, lmessages,
  Win32Extra, LCLClasses,LCLProc;

type
  TNewForm=class(TForm)
  private
  protected
   // procedure WndProc(var TheMessage: TLMessage); override;
  public
    constructor Create(TheOwner: TComponent); override;
    constructor CreateNew(AOwner: TComponent; Num: Integer=0); override;
  published
  end;


implementation

uses graphics, Menus, Win32WSMenus, betterControls;

constructor TNewForm.Create(TheOwner: TComponent);
begin
  inherited create(TheOwner);

  if ShouldAppsUseDarkMode() then
  begin
    AllowDarkModeForWindow(handle,1);

    color:=$242424;
    if font.color=clDefault then
      font.color:=colorset.FontColor;

    SetWindowDarkTitlebar(handle);
  end;
end;

constructor TNewForm.CreateNew(AOwner: TComponent; Num: Integer=0);
begin
  inherited CreateNew(AOwner, num);
  if ShouldAppsUseDarkMode() then
  begin
    AllowDarkModeForWindow(handle,1);

    color:=$242424;
    if font.color=clDefault then
      font.color:=colorset.FontColor;

    SetWindowDarkTitlebar(handle);
  end;
end;

end.

