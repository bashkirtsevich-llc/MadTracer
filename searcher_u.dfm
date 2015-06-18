object frmSearcher: TfrmSearcher
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'Find process'
  ClientHeight = 157
  ClientWidth = 341
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object btnOk: TButton
    Left = 259
    Top = 15
    Width = 75
    Height = 25
    Caption = 'Ok'
    Default = True
    ModalResult = 1
    TabOrder = 0
  end
  object btnCancel: TButton
    Left = 259
    Top = 46
    Width = 75
    Height = 25
    Cancel = True
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 1
  end
  object grpSearcher: TGroupBox
    Left = 8
    Top = 8
    Width = 241
    Height = 141
    Caption = 'Searcher'
    TabOrder = 2
    object lblInfo: TLabel
      Left = 12
      Top = 22
      Width = 217
      Height = 31
      AutoSize = False
      Caption = 
        'Drag the Finder Tool over a window to select it, then release th' +
        'e mouse button.'
      WordWrap = True
    end
    object lblFinderTool: TLabel
      Left = 12
      Top = 68
      Width = 57
      Height = 13
      Caption = 'Finder Tool:'
    end
    object imgTool: TImage
      Left = 87
      Top = 59
      Width = 32
      Height = 32
      OnMouseDown = imgToolMouseDown
      OnMouseUp = imgToolMouseUp
    end
    object lblProcID: TLabel
      Left = 8
      Top = 112
      Width = 55
      Height = 13
      Caption = 'Process ID:'
    end
    object lblPID: TLabel
      Left = 87
      Top = 112
      Width = 37
      Height = 13
      Caption = 'unknow'
    end
  end
end
