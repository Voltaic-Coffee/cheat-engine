unit newSplitter;

{$mode objfpc}{$H+}

interface

uses
  jwawindows, windows, Classes, SysUtils, Controls, ExtCtrls, Graphics;

type
  TNewSplitter=class(TSplitter)
  private
  protected
    procedure ChildHandlesCreated; override;
  public
  end;


implementation

uses betterControls;


procedure TNewSplitter.ChildHandlesCreated;
begin
  inherited ChildHandlesCreated;

  if ShouldAppsUseDarkMode and (Parent<>nil) then
  begin
    AllowDarkModeForWindow(handle, 1);

    if Color = clDefault then
      Color := ColorSet.HighlightColor;
  end;
end;

end.
