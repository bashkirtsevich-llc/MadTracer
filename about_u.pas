unit about_u;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, pngimage, ExtCtrls, StdCtrls;

type
  TfrmAbout = class(TForm)
    imgLogo: TImage;
    btnOk: TButton;
    bvlBottom: TBevel;
    lblAppName: TLabel;
    lblCopyright: TLabel;
  private
    { Private declarations }
  public
    { Public declarations }
    class procedure ShowAbout(AOwner: TComponent);
  end;

implementation

{$R *.dfm}

{ TfrmAbout }

class procedure TfrmAbout.ShowAbout(AOwner: TComponent);
var
  frm: TfrmAbout;
begin
  frm := TfrmAbout.Create(AOwner);
  try
    frm.ShowModal;
  finally
    frm.Free;
  end;
end;

end.
