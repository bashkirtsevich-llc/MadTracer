unit searcher_u;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, StdCtrls, ComCtrls;

type
  TfrmSearcher = class(TForm)
    btnOk: TButton;
    btnCancel: TButton;
    grpSearcher: TGroupBox;
    lblInfo: TLabel;
    lblFinderTool: TLabel;
    imgTool: TImage;
    lblProcID: TLabel;
    lblPID: TLabel;
    procedure imgToolMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure imgToolMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormShow(Sender: TObject);
  private
    FToolCursor: HCURSOR;
    FFindIcon: HICON;
    FFindingIcon: HICON;
    FOldCur: TCursor;

    FCurrentWindowPID: Cardinal;

    function IsCurrentWindowHandle(const hWnd: THandle): Boolean;
  public
    procedure AfterConstruction; override;
    class function FindProcess(const aOwner: TComponent; out aPID: Cardinal): Boolean;
  end;

var
  frmSearcher: TfrmSearcher;

implementation

{$R *.dfm}

{ TfrmSearcher }

procedure TfrmSearcher.AfterConstruction;
begin
  inherited;
  FToolCursor := LoadCursor(HInstance, 'TOOL');
  Screen.Cursors[100] := FToolCursor;

  FFindIcon := LoadIcon(HInstance, 'ZFIND');
  FFindingIcon := LoadIcon(HInstance, 'ZFINDING');

  imgTool.Picture.Icon.Handle := FFindIcon;
end;

class function TfrmSearcher.FindProcess(const aOwner: TComponent;
  out aPID: Cardinal): Boolean;
var
  wnd: TfrmSearcher;
begin
  wnd := TfrmSearcher.Create(aOwner);
  try
    Result := wnd.ShowModal = mrOk;
    if Result then
      aPID := wnd.FCurrentWindowPID;
  finally
    wnd.Free;
  end;
end;

procedure TfrmSearcher.FormShow(Sender: TObject);
begin
  SetForegroundWindow(Self.Handle);
end;

procedure TfrmSearcher.imgToolMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if Button <> mbLeft then
    Exit;

  FOldCur := Screen.Cursor;
  Screen.Cursor := 100;
  imgTool.Picture.Icon.Handle := FFindingIcon;
end;

procedure TfrmSearcher.imgToolMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  p: TPoint;
  window: THandle;
begin
  Screen.Cursor := FOldCur;
  imgTool.Picture.Icon.Handle := FFindIcon;

  GetCursorPos(p);

  window := WindowFromPoint(p);
  if window <> INVALID_HANDLE_VALUE then
  begin
    if IsCurrentWindowHandle(window) then
      Exit;

    FCurrentWindowPID := 0;
    GetWindowThreadProcessId(window, FCurrentWindowPID);

    lblPID.Caption := IntToStr(FCurrentWindowPID);
  end;
end;

function TfrmSearcher.IsCurrentWindowHandle(const hWnd: THandle): Boolean;
var
  i: Integer;
begin
  for i := 0 to Pred(Self.ControlCount) do
    if (Self.Controls[i] is TWinControl) and
       (TWinControl(Self.Controls[i]).Handle = hWnd) then
      Exit(True);

  Result := Self.Handle = hWnd;
end;

end.
