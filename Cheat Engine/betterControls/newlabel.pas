unit newLabel;

{$mode objfpc}{$H+}

interface

uses
  jwawindows, windows, Classes, SysUtils, Controls, StdCtrls, Graphics;

type
  TNewLabel=class(TLabel)
  private
  protected
    procedure SetParent(NewParent: TWinControl); override;
  public
  end;


implementation

uses betterControls;


procedure TNewLabel.SetParent(NewParent: TWinControl);
begin
  inherited SetParent(NewParent);

  if ShouldAppsUseDarkMode and (NewParent<>nil) then
  begin
    if Font.Color = clDefault then
      Font.Color := ColorSet.FontColor;

    // Labels typically inherit background from parent
    ParentColor := True;
  end;
end;

end.
