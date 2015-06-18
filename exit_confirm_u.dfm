object frmConfirm: TfrmConfirm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Confirm'
  ClientHeight = 105
  ClientWidth = 533
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
  object lblInfo: TLabel
    Left = 8
    Top = 8
    Width = 517
    Height = 57
    AutoSize = False
    Caption = 
      'This current debug session must end before the requested operati' +
      'on can complete. Please indicate how you would like to end the d' +
      'abug session.'
    WordWrap = True
  end
  object btnTerminate: TButton
    Left = 292
    Top = 76
    Width = 75
    Height = 25
    Caption = 'Terminate'
    Default = True
    ModalResult = 1
    TabOrder = 0
  end
  object btnDetach: TButton
    Left = 373
    Top = 76
    Width = 75
    Height = 25
    Caption = 'Detach'
    ModalResult = 3
    TabOrder = 1
  end
  object btnCancel: TButton
    Left = 454
    Top = 76
    Width = 75
    Height = 25
    Cancel = True
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 2
  end
end
