unit main_u;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, StdCtrls, searcher_u, ToolWin, ComCtrls, Buttons, ImgList,
  ActnList, tracer_core_u, types_const_u, AppEvnts, ShellAPI;

type
  TfrmMain = class(TForm)
    pnlToolBar: TPanel;
    tlbMain: TToolBar;
    btnOpen: TToolButton;
    btnAttach: TToolButton;
    spr1: TToolButton;
    btnDetach: TToolButton;
    spr2: TToolButton;
    btnSuspend: TToolButton;
    btnResume: TToolButton;
    btnTerminate: TToolButton;
    ilMain: TImageList;
    actlstMain: TActionList;
    aOpenFile: TAction;
    aAttach: TAction;
    aDetach: TAction;
    dlgOpenFile: TOpenDialog;
    pgcMain: TPageControl;
    tsEventLog: TTabSheet;
    statMain: TStatusBar;
    tsThreads: TTabSheet;
    tsStack: TTabSheet;
    tsModules: TTabSheet;
    tsContext: TTabSheet;
    lstEvents: TListBox;
    aSuspend: TAction;
    aResume: TAction;
    aStop: TAction;
    spr3: TToolButton;
    btnClear: TToolButton;
    aClear: TAction;
    aSaveReport: TAction;
    btnSave: TToolButton;
    spr4: TToolButton;
    btnAbout: TToolButton;
    aAbout: TAction;
    lvThreads: TListView;
    tsExceptionInfo: TTabSheet;
    mmoExceptInfo: TMemo;
    lstContext: TListBox;
    mmoStackTrace: TMemo;
    lvModules: TListView;
    dlgSaveLog: TSaveDialog;
    procedure aOpenFileExecute(Sender: TObject);
    procedure aAttachExecute(Sender: TObject);
    procedure actlstMainUpdate(Action: TBasicAction; var Handled: Boolean);
    procedure aResumeExecute(Sender: TObject);
    procedure aClearExecute(Sender: TObject);
    procedure lstEventsDrawItem(Control: TWinControl; Index: Integer;
      Rect: TRect; State: TOwnerDrawState);
    procedure aAboutExecute(Sender: TObject);
    procedure lstContextDrawItem(Control: TWinControl; Index: Integer;
      Rect: TRect; State: TOwnerDrawState);
    procedure aDetachExecute(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure aStopExecute(Sender: TObject);
    procedure aSaveReportExecute(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  private
    FFileName,
    FFilePath,
    FFileParams: string;
    FProcessID: Cardinal;

    FTracer: TTracer;

    FNotifInfo: TNotifyStruct;

    procedure PrintNotify;

    procedure DoOpenFile;
    procedure Clear;
    procedure ClearControls;
    procedure OnTracerNotify(const aNotifyInfo: TNotifyStruct);
    procedure OnTerminateTracer(Sender: TObject);

    procedure ShowStatusInfo(const AStatusInfo: string);
    procedure DragFile(var AMsg: TWMDropFiles); message WM_DROPFILES;
  public
    procedure AfterConstruction; override;
  end;

var
  frmMain: TfrmMain;
  defAnsw: Integer;

implementation

uses
  Contnrs, about_u, action_u, param_box_u, exit_confirm_u;

{$R *.dfm}
{$R res.res}

procedure TfrmMain.aAboutExecute(Sender: TObject);
begin
  TfrmAbout.ShowAbout(Self);
end;

procedure TfrmMain.aAttachExecute(Sender: TObject);
begin
  try
    Hide;

    if TfrmSearcher.FindProcess(Self, FProcessID) then
      aResumeExecute(Sender);
  finally
    Show;

    SetForegroundWindow(Self.Handle);
  end;
end;

procedure TfrmMain.aClearExecute(Sender: TObject);
begin
  ClearControls;
end;

procedure TfrmMain.actlstMainUpdate(Action: TBasicAction; var Handled: Boolean);
var
  state: Boolean;
begin
  state := (FFileName <> '') or (FProcessID <> 0);
  aOpenFile.Enabled := not state;
  aAttach.Enabled := aOpenFile.Enabled;
  aDetach.Enabled := state;

  aResume.Enabled := ((FTracer = nil) and state) or
                     ((FTracer <> nil) and (FTracer.Suspended));

  aDetach.Enabled := (FTracer <> nil);
  aStop.Enabled := aDetach.Enabled;
  aSaveReport.Enabled := aDetach.Enabled;
end;

procedure TfrmMain.aDetachExecute(Sender: TObject);
begin
  if not aDetach.Enabled then
    Exit;

  FTracer.DetachFromProgramm;
end;

procedure TfrmMain.AfterConstruction;
begin
  inherited;
  Constraints.MinHeight := Height;
  Constraints.MinWidth := Width;
  DragAcceptFiles(Handle, True);
end;

procedure TfrmMain.aOpenFileExecute(Sender: TObject);
begin
  if not dlgOpenFile.Execute then
    Exit;

  Clear;
  FFileName := dlgOpenFile.FileName;
  DoOpenFile;
end;

procedure TfrmMain.aResumeExecute(Sender: TObject);
var
  i: Integer;
begin
  if not aResume.Enabled then
    Exit;

  if FTracer = nil then
  begin
    defAnsw := 0;
    FTracer := TTracer.CreateTracer;
    FTracer.OnTerminate := OnTerminateTracer;
    FTracer.OnNotify := OnTracerNotify;

    if FProcessID <> 0 then
      FTracer.AttachToProcess(FProcessID)
    else

    if FFileName <> '' then
      FTracer.StartProcess(FFileName, FFilePath, FFileParams)
    else
    begin
      MessageBox(Handle,
                'What i must do?? PID = Unknow, File name = Unknow',
                'Something wrong',
                MB_OK + MB_ICONEXCLAMATION
                );
      Exit;
    end;
  end;

  FTracer.StartTrace;

  i := pgcMain.ActivePageIndex;

  pgcMain.Pages[5].TabVisible := False;
  pgcMain.Pages[4].TabVisible := False;
  pgcMain.Pages[3].TabVisible := False;

  if not i in [3..5] then
    pgcMain.ActivePageIndex := i;
end;

procedure TfrmMain.aSaveReportExecute(Sender: TObject);
const
  END_STR: string = '~~ .end'#13#10#13#10;
var
  textLog: TStringStream;
  i, j: Integer;
begin
  if not dlgSaveLog.Execute then
    Exit;

  textLog := TStringStream.Create;
  try
    textLog.WriteString('~~ General information'#13#10);
    textLog.WriteString(' * File name : ' + FFileName   + #13#10);
    textLog.WriteString(' * File path : ' + FFilePath   + #13#10);
    textLog.WriteString(' * File param: ' + FFileParams + #13#10);
    textLog.WriteString(END_STR);

    // THREADS
    textLog.WriteString('~~ Thread information'#13#10);
    textLog.WriteString('   TID'#9 +
                           'Kernel time'#9 +
                           'User time'#9 +
                           'Create time'#9 +
                           'Start address'#9 +
                           'Priority'#9 +
                           'Base priority'#9 +
                           'Context switches'#9 +
                           'Thread state'#9 +
                           'Wait reason' +
                           #13#10);
    for i := 0 to Pred(lvThreads.Items.Count) do
    begin
      textLog.WriteString('   ' + lvThreads.Items[i].Caption + #9);
      for j := 0 to Pred(lvThreads.Items[i].SubItems.Count) do
      begin
        textLog.WriteString(lvThreads.Items[i].SubItems[j]+ #9);
      end;
      textLog.WriteString(#13#10);
    end;
    textLog.WriteString(END_STR);

    // MODULES
    textLog.WriteString('~~ Modules information'#13#10);
    textLog.WriteString('   Name'#9 +
                           'Base'#9 +
                           'Size'#9 +
                           'Flags'#9 +
                           'Index'#9 +
                           'Load count'#9 +
                           'Image name' +
                           #13#10);

    for i := 0 to Pred(lvModules.Items.Count) do
    begin
      textLog.WriteString('   ' + lvModules.Items[i].Caption + #9);
      for j := 0 to Pred(lvModules.Items[i].SubItems.Count) do
      begin
        textLog.WriteString(lvModules.Items[i].SubItems[j]+ #9);
      end;
      textLog.WriteString(#13#10);
    end;
    textLog.WriteString(END_STR);

    // LOGS
    if mmoExceptInfo.Text <> '' then
    begin
      textLog.WriteString('~~ Exception information'#13#10);
      textLog.WriteString(mmoExceptInfo.Text);
      textLog.WriteString(END_STR);
    end;

    if mmoStackTrace.Text <> '' then
    begin
      textLog.WriteString('~~ Stack trace'#13#10);
      textLog.WriteString(mmoStackTrace.Text);
      textLog.WriteString(END_STR);
    end;

    if lstContext.Items.Text <> '' then
    begin
      textLog.WriteString('~~ Thread context'#13#10);
      textLog.WriteString(lstContext.Items.Text);
      textLog.WriteString(END_STR);
    end;

    if lstEvents.Items.Text <> '' then
    begin
      textLog.WriteString('~~ Event log'#13#10);
      textLog.WriteString(lstEvents.Items.Text);
      textLog.WriteString(END_STR);
    end;

    textLog.SaveToFile(dlgSaveLog.FileName);
  finally
    textLog.Free;
  end;
end;

procedure TfrmMain.aStopExecute(Sender: TObject);
begin
  if not aStop.Enabled then
    Exit;

  FTracer.TerminateProc;
end;

procedure TfrmMain.Clear;
begin
  FFileName := '';
  FFileParams := '';
  FProcessID := 0;
  FTracer := nil;
end;

procedure TfrmMain.ClearControls;
begin
  lstEvents.Clear;
end;

procedure TfrmMain.DoOpenFile;
begin
  FFilePath := ExtractFilePath(FFileName);
  if not ParamQuery(Self, 'Parameters', 'Work dir', 'Parameters', FFilePath, FFileParams) then
  begin
    FFilePath := '';
    FFileName := '';
    FFileParams := '';
  end;
end;

procedure TfrmMain.DragFile(var AMsg: TWMDropFiles);
var
  hDrop: integer;
  NameSize: integer;
begin
  hDrop := AMsg.Drop;
  NameSize := DragQueryFile(hDrop, 0, nil, 0);
  SetLength(FFileName, NameSize);
  DragQueryFile(hDrop, 0, PChar(FFileName), NameSize + 1);
  DragFinish(hDrop);

  DoOpenFile;
end;

procedure TfrmMain.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := FTracer = nil;
  if not CanClose then
    case TfrmConfirm.ConfirmEndSession(Self) of
      0:;
      1: aStopExecute(aStop);
      2: aDetachExecute(aDetach);
    end;
end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  pgcMain.Pages[5].TabVisible := False;
  pgcMain.Pages[4].TabVisible := False;
  pgcMain.Pages[3].TabVisible := False;
  pgcMain.ActivePageIndex := 0;
end;

procedure TfrmMain.lstContextDrawItem(Control: TWinControl; Index: Integer;
  Rect: TRect; State: TOwnerDrawState);
var
  s: string;
  i: Integer;
begin
  with lstContext do
  begin
    s := Items[Index];
    if s = '' then
    begin
      Canvas.TextRect(Rect, Rect.Left + 4, Rect.Top, '');
      Exit;
    end;
    i := Pos(':', s);
    Canvas.Font.Color := clMaroon;
    Canvas.TextRect(Rect, Rect.Left + 4, Rect.Top, Trim(Copy(s, 1, i - 1)));
    Canvas.Font.Color := clBlue;
    Canvas.TextOut(Rect.Left + Canvas.TextWidth('________________'),
                   Rect.Top,
                   '$' + Trim(Copy(s, i + 1, Length(s) - i + 1)));
  end;
end;

procedure TfrmMain.lstEventsDrawItem(Control: TWinControl; Index: Integer;
  Rect: TRect; State: TOwnerDrawState);
var
  data: TNotifyStruct;
begin
  with lstEvents do
  begin
    if not (Items.Objects[Index] is TNotifyStruct) then
      Exit;

    data := TNotifyStruct(Items.Objects[Index]);

    case data.Flags of
      FLAG_NONE: Canvas.Font.Color := clDefault;

      FLAG_CREATE_PROCESS,
      FLAG_EXIT_PROCESS: Canvas.Font.Color := clGray;

      FLAG_CREATE_THREAD,
      FLAG_EXIT_THREAD: Canvas.Font.Color := clMaroon;

      FLAG_LOADD_DLL,
      FLAG_UNLOAD_DLL: Canvas.Font.Color := clBlue;

      FLAG_DEBUG_PRINT: Canvas.Font.Color := clNavy;

      FLAG_RIP: Canvas.Font.Color := clRed;

      FLAG_EXCEPTION: Canvas.Font.Color := clTeal;
    end;

    Canvas.TextRect(Rect, Rect.Left + 4, Rect.Top, Items[Index]);
  end;
end;

procedure TfrmMain.OnTerminateTracer(Sender: TObject);
begin
  Clear;
end;

procedure TfrmMain.OnTracerNotify(const aNotifyInfo: TNotifyStruct);
begin
  FNotifInfo := aNotifyInfo;
  FTracer.Synchronize(FTracer, PrintNotify);
end;

procedure TfrmMain.PrintNotify;
var
  i, j: Integer;
  b: Boolean;
  objList: TObjectList;
  thrdInfo: TThreadInfoObj;
  moduleInfo: TModuleInfoObj;
  lst: TStringList;
  nextAction: Integer;
begin
  nextAction := 0;
  if FNotifInfo.Flags = FLAG_EXCEPTION then
  begin
    pgcMain.Pages[5].TabVisible := True;
    pgcMain.Pages[4].TabVisible := True;
    pgcMain.Pages[3].TabVisible := True;

    if defAnsw in [0, 1] then
      SetForegroundWindow(Handle);
    // отобразить окно с выбором действия Break/Continue
    TfrmAction.ShowNotify(Self, FNotifInfo.Info, defAnsw, nextAction);
  end;
  case FNotifInfo.NotifyType of
    ntLogEvent:
      begin
        lstEvents.Items.AddObject(FNotifInfo.Info, FNotifInfo);
        lstEvents.ItemIndex := lstEvents.Items.Count - 1;
        // еще и в статусе покажем последнее событие, мда...
        ShowStatusInfo(FNotifInfo.Info);
      end;

    ntThreadsInfo:
      begin
        objList := TObjectList(FNotifInfo.InfoObj);
        lvThreads.Items.BeginUpdate;
        LockWindowUpdate(lvThreads.Handle);
        try
          for i := 0 to Pred(objList.Count) do
          begin
            thrdInfo := TThreadInfoObj(objList[i]);
            b := False;
            for j := 0 to Pred(lvThreads.Items.Count) do
              if lvThreads.Items[j].Caption = thrdInfo.ThreadID then
              begin
                with lvThreads.Items[j].SubItems, thrdInfo do
                begin
                  Clear;
                  Add(KernelTime);
                  Add(UserTime);
                  Add(CreateTime);
                  Add(StartAddress);
                  Add(Priority);
                  Add(BasePriority);
                  Add(ContextSwitches);
                  Add(ThreadState);
                  Add(WaitReason);
                end;

                b := True;
                Break;
              end;

            if not b then
              with lvThreads.Items.Add, thrdInfo do
              begin
                Caption := ThreadID;
                SubItems.Add(KernelTime);
                SubItems.Add(UserTime);
                SubItems.Add(CreateTime);
                SubItems.Add(StartAddress);
                SubItems.Add(Priority);
                SubItems.Add(BasePriority);
                SubItems.Add(ContextSwitches);
                SubItems.Add(ThreadState);
                SubItems.Add(WaitReason);
              end;
          end;

          for i := Pred(lvThreads.Items.Count) downto 0 do
          begin
            b := False;
            for j := 0 to Pred(objList.Count) do
            begin
              thrdInfo := TThreadInfoObj(objList[j]);
              if lvThreads.Items[i].Caption = thrdInfo.ThreadID then
              begin
                b := True;
                Break;
              end;
            end;
            if not b then
              lvThreads.Items.Delete(i);
          end;
        finally
          lvThreads.Items.EndUpdate;
          LockWindowUpdate(0)
        end;
      end;

    ntExceptInfo:
      begin
        mmoExceptInfo.Clear;
        mmoExceptInfo.Lines.Add(FNotifInfo.Info);
      end;

    ntContextInfo:
      begin
        lst := TStringList.Create;
        try
          lstContext.Clear;
          lst.Text := FNotifInfo.Info;
          for i := 0 to Pred(lst.Count) do
            lstContext.Items.Add(lst[i]);
        finally
          lst.Free
        end;
      end;

    ntStackTrace:
      begin
        mmoStackTrace.Clear;
        mmoStackTrace.Lines.Add(FNotifInfo.Info);
      end;

    ntModulesInfo:
      begin
        objList := TObjectList(FNotifInfo.InfoObj);
        lvModules.Items.BeginUpdate;
        LockWindowUpdate(lvModules.Handle);
        try
          for i := 0 to Pred(objList.Count) do
          begin
            moduleInfo := TModuleInfoObj(objList[i]);
            b := False;
            for j := 0 to Pred(lvModules.Items.Count) do
              if lvModules.Items[j].Caption = ExtractFileName(moduleInfo.ImageName) then
              begin
                with lvModules.Items[j].SubItems, moduleInfo do
                begin
                  Clear;
                  Add('$' + IntToHex(Base, 8));
                  Add('$' + IntToHex(Size, 8));
                  Add(IntToHex(Flags, 8));
                  Add(IntToStr(Index));
                  Add('$' + IntToHex(LoadCount, 8));
                  Add(ImageName);
                end;

                b := True;
                Break;
              end;

            if not b then
              with lvModules.Items.Add, moduleInfo do
              begin
                Caption := ExtractFileName(ImageName);
                SubItems.Add('$' + IntToHex(Base, 8));
                SubItems.Add('$' + IntToHex(Size, 8));
                SubItems.Add(IntToHex(Flags, 8));
                SubItems.Add(IntToStr(Index));
                SubItems.Add('$' + IntToHex(LoadCount, 8));
                SubItems.Add(ImageName);
              end;
          end;

          for i := Pred(lvModules.Items.Count) downto 0 do
          begin
            b := False;
            for j := 0 to Pred(objList.Count) do
            begin
              moduleInfo := TModuleInfoObj(objList[j]);
              if lvModules.Items[i].Caption = ExtractFileName(moduleInfo.ImageName) then
              begin
                b := True;
                Break;
              end;
            end;
            if not b then
              lvModules.Items.Delete(i);
          end;
        finally
          lvModules.Items.EndUpdate;
          LockWindowUpdate(0);
        end;
      end;
  end;
  // необходимое действие
  case nextAction of
    0:; // Nothing
    1:; // Break
    2:
      begin
        i := pgcMain.ActivePageIndex;

        pgcMain.Pages[5].TabVisible := False;
        pgcMain.Pages[4].TabVisible := False;
        pgcMain.Pages[3].TabVisible := False;

        if not i in [3..5] then
          pgcMain.ActivePageIndex := i;

        FTracer.NeedStop := False; // Continue
      end;
  end;
end;

procedure TfrmMain.ShowStatusInfo(const AStatusInfo: string);
begin
  statMain.Panels[0].Text := AStatusInfo;
end;

end.
