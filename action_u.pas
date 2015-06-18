unit action_u;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls;

type
  TfrmAction = class(TForm)
    chkAsDefault: TCheckBox;
    mmoInfo: TMemo;
    btnBreak: TButton;
    btnContinue: TButton;
  private
    { Private declarations }
  public
    { Public declarations }
    class procedure ShowNotify(const AOwner: TComponent; const AMessage: string;
      var ADefaultAnswer: Integer; var AAnswer: Integer);
  end;

implementation

{$R *.dfm}

{ TfrmAction }

class procedure TfrmAction.ShowNotify(const AOwner: TComponent;
  const AMessage: string; var ADefaultAnswer: Integer; var AAnswer: Integer);
var
  frm: TfrmAction;
begin
  if ADefaultAnswer <> 0 then
  begin
    AAnswer := ADefaultAnswer;
    Exit;
  end;

  frm := TfrmAction.Create(AOwner);
  try
    frm.mmoInfo.Text := AMessage;
    if frm.ShowModal = mrOk then
      AAnswer := 1
    else
      AAnswer := 2;

    if frm.chkAsDefault.Checked then
      ADefaultAnswer := AAnswer;
  finally
    frm.Free;
  end;
end;

end.
