unit newPanel;

{$mode objfpc}{$H+}

interface

uses
  jwawindows, windows, Classes, SysUtils, Controls, ExtCtrls, Graphics;

type
  TNewPanel=class(TPanel)
  private
  protected
    procedure ChildHandlesCreated; override;
  public
  end;


implementation

uses betterControls;


procedure TNewPanel.ChildHandlesCreated;
begin
  inherited ChildHandlesCreated;

  if ShouldAppsUseDarkMode and (Parent<>nil) then
  begin
    AllowDarkModeForWindow(handle, 1);

    if Color = clDefault then
      Color := ColorSet.TextBackground;

    if Font.Color = clDefault then
      Font.Color := ColorSet.FontColor;
  end;
end;

end.
