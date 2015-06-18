unit param_box_u;

interface

uses
  Classes;

function ParamQuery(AOwner: TComponent; const ACaption, APrompt1,
  APrompt2: string; var Value1, Value2: string): Boolean;

implementation

uses
  Windows, Forms, StdCtrls, Graphics, Controls;

function ParamQuery(AOwner: TComponent; const ACaption, APrompt1,
  APrompt2: string; var Value1, Value2: string): Boolean;

  function GetAveCharSize(Canvas: TCanvas): TPoint;
  var
    I: Integer;
    Buffer: array [0 .. 51] of Char;
  begin
    for I := 0 to 25 do
      Buffer[I] := Chr(I + Ord('A'));
    for I := 0 to 25 do
      Buffer[I + 26] := Chr(I + Ord('a'));
    GetTextExtentPoint(Canvas.Handle, Buffer, 52, TSize(Result));
    Result.X := Result.X div 52;
  end;

var
  Form: TForm;
  Prompt1, Prompt2: TLabel;
  Edit1, Edit2: TEdit;
  DialogUnits: TPoint;
  ButtonTop, ButtonWidth, ButtonHeight: Integer;
begin
  Result := False;
  Form := TForm.Create(AOwner);
  with Form do
    try
      Canvas.Font := Font;
      DialogUnits := GetAveCharSize(Canvas);
      BorderStyle := bsDialog;
      Caption := ACaption;
      ClientWidth := MulDiv(320, DialogUnits.X, 4);
      PopupMode := pmAuto;
      Position := poOwnerFormCenter;
      Prompt1 := TLabel.Create(Form);
      with Prompt1 do
      begin
        Parent := Form;
        Caption := APrompt1;
        Left := MulDiv(8, DialogUnits.X, 4);
        Top := MulDiv(8, DialogUnits.Y, 8);
        Constraints.MaxWidth := MulDiv(302, DialogUnits.X, 4);
        WordWrap := True;
      end;
      Edit1 := TEdit.Create(Form);
      with Edit1 do
      begin
        Parent := Form;
        Left := Prompt1.Left;
        Top := Prompt1.Top + Prompt1.Height + 5;
        Width := MulDiv(302, DialogUnits.X, 4);
        MaxLength := 255;
        Text := Value1;
        SelectAll;
      end;
      Prompt2 := TLabel.Create(Form);
      with Prompt2 do
      begin
        Parent := Form;
        Caption := APrompt2;
        Left := MulDiv(8, DialogUnits.X, 4);
        Top := Edit1.Top + Edit1.Height + 5;
        Constraints.MaxWidth := MulDiv(302, DialogUnits.X, 4);
        WordWrap := True;
      end;
      Edit2 := TEdit.Create(Form);
      with Edit2 do
      begin
        Parent := Form;
        Left := Prompt2.Left;
        Top := Prompt2.Top + Prompt2.Height + 5;
        Width := MulDiv(302, DialogUnits.X, 4);
        MaxLength := 255;
        Text := Value2;
        SelectAll;
      end;
      ButtonTop := Edit2.Top + Edit2.Height + 15;
      ButtonWidth := MulDiv(50, DialogUnits.X, 4);
      ButtonHeight := MulDiv(14, DialogUnits.Y, 8);
      with TButton.Create(Form) do
      begin
        Parent := Form;
        Caption := 'Ok';
        ModalResult := mrOk;
        Default := True;
        SetBounds(MulDiv(100, DialogUnits.X, 4), ButtonTop, ButtonWidth,
          ButtonHeight);
      end;
      with TButton.Create(Form) do
      begin
        Parent := Form;
        Caption := 'Cancel';
        ModalResult := mrCancel;
        Cancel := True;
        SetBounds(MulDiv(170, DialogUnits.X, 4), Edit2.Top + Edit2.Height + 15,
          ButtonWidth, ButtonHeight);
        Form.ClientHeight := Top + Height + 13;
      end;
      if ShowModal = mrOk then
      begin
        Value1 := Edit1.Text;
        Value2 := Edit2.Text;
        Result := True;
      end;
    finally
      Form.Free;
    end;
end;

end.
