object frmAction: TfrmAction
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'MAD Tracer notification'
  ClientHeight = 133
  ClientWidth = 561
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poOwnerFormCenter
  PixelsPerInch = 96
  TextHeight = 13
  object chkAsDefault: TCheckBox
    Left = 8
    Top = 108
    Width = 197
    Height = 17
    Caption = 'Set as default answer'
    TabOrder = 0
  end
  object mmoInfo: TMemo
    Left = 8
    Top = 8
    Width = 545
    Height = 85
    Lines.Strings = (
      'mmoInfo')
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 1
  end
  object btnBreak: TButton
    Left = 397
    Top = 104
    Width = 75
    Height = 25
    Caption = 'Break'
    Default = True
    ModalResult = 1
    TabOrder = 2
  end
  object btnContinue: TButton
    Left = 478
    Top = 104
    Width = 75
    Height = 25
    Cancel = True
    Caption = 'Continue'
    ModalResult = 2
    TabOrder = 3
  end
end
