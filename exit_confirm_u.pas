unit exit_confirm_u;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls;

type
  TfrmConfirm = class(TForm)
    btnTerminate: TButton;
    btnDetach: TButton;
    btnCancel: TButton;
    lblInfo: TLabel;
  private
    { Private declarations }
  public
    { Public declarations }
    class function ConfirmEndSession(AOwner: TComponent): Integer;
  end;

implementation

{$R *.dfm}

{ TfrmConfirm }

class function TfrmConfirm.ConfirmEndSession(AOwner: TComponent): Integer;
var
  frm: TfrmConfirm;
begin
  Result := 0;
  frm := TfrmConfirm.Create(AOwner);
  try
    case frm.ShowModal of
      mrCancel: Result := 0;
      mrOk    : Result := 1;
      mrAbort : Result := 2;
    end;
  finally
    frm.Free;
  end;
end;

end.
