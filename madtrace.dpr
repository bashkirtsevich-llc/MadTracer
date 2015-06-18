program madtrace;

uses
  Forms,
  Dialogs,
  main_u in 'main_u.pas' {frmMain},
  tracer_core_u in 'tracer_core_u.pas',
  searcher_u in 'searcher_u.pas' {frmSearcher},
  types_const_u in 'types_const_u.pas',
  about_u in 'about_u.pas' {frmAbout},
  action_u in 'action_u.pas' {frmAction},
  param_box_u in 'param_box_u.pas',
  exit_confirm_u in 'exit_confirm_u.pas' {frmConfirm},
  map_parser_u in 'map_parser_u.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
