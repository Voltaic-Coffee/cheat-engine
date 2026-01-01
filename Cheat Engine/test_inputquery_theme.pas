program test_inputquery_theme;

{$mode objfpc}{$H+}
{$DEFINE DEBUG_DARKMODE}
{$define bc_skipsynedit}
{$define bc_skipvirtualstringtree}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  {$IFDEF HASAMIGA}
  athreads,
  {$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, Dialogs, betterControls, SysUtils;

var
  TestValue: string;
  MsgResult: Integer;

begin
  Application.Title:='InputQuery Theme Test';
  Application.Scaled:=True;
  Application.Initialize;

  // Register the dark mode form handler
  registerDarkModeFormAddHandler;

  // Test 1: InputQuery
  TestValue := 'Default Value';
  if InputQuery('Test InputQuery', 'Enter some text:', TestValue) then
    ShowMessage('InputQuery result: ' + TestValue)
  else
    ShowMessage('InputQuery cancelled');

  // Test 2: MessageDlg with multiple buttons
  MsgResult := MessageDlg('Test MessageDlg', 'This is a warning message. All controls should be dark themed.',
                          mtWarning, [mbYes, mbNo, mbCancel], 0);
  ShowMessage('MessageDlg result: ' + IntToStr(MsgResult));

  // Test 3: ShowMessage
  ShowMessage('This is ShowMessage test. Form, titlebar, and all controls should be fully dark themed.');

  // Test 4: Another InputQuery to test multiple instances
  TestValue := '';
  if InputQuery('Second InputQuery', 'This should also be dark themed:', TestValue) then
    ShowMessage('Second test result: ' + TestValue);

  Application.Run;
end.
