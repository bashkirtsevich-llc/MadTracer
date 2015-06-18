unit tracer_core_u;

interface

uses
  Windows, Classes, SysUtils, PsAPI, TlHelp32, Contnrs, map_parser_u;

type
  TTimerThread = class(TThread)
  private
    FInterval: Int64;
    FCallback,
    FParam: Pointer;
  protected
    procedure Execute; override;
  public
    property Callback: Pointer read FCallback write FCallback;

    class function CreateTimer(const aInterval: Int64;
      const aCallback, aParam: Pointer): TTimerThread;
  end;

  TTracerFlag = (fAttachProcess, fCreateProcess, fTerminateProcess,
    fDetachProcess, fSuspend, fTerminateTrace);

  TNotifyType = (ntLogEvent, ntThreadsInfo, ntExceptInfo, ntStackTrace,
    ntModulesInfo, ntContextInfo, ntDisasm);

  TNotifyStruct = class
  private
    FNotifyType: TNotifyType;
    FFlags: Cardinal;
    FInfo: string;
    FInfoObj: TObject;
  public
    property NotifyType: TNotifyType read FNotifyType;
    property Flags: Cardinal read FFlags;
    property Info: string read FInfo;
    property InfoObj: TObject read FInfoObj;

    constructor Create(const aNotifyType: TNotifyType; const aFlags: Cardinal;
      const aInfo: string); overload;
    constructor Create(const aNotifyType: TNotifyType; const aFlags: Cardinal;
      const aInfo: TObject); overload;
  end;

  TNotifyProc = procedure (const aNotifyInfo: TNotifyStruct) of object;

  TTracer = class(TThread)
  private
    FFlag: TTracerFlag;

    FTimer: TTimerThread;

    FProcID: Cardinal;
    FFileName,
    FFilePath,
    FParams: string;

    FModulesList: TObjectList;
    FMapList: TObjectList;
    FThreadsList: TObjectList;

    FCanTimer: Boolean;

    FProcHandle: THandle;

    function IsProcessUnderDebugger(const aProcHandle: THandle): Boolean;
    function DetachTracer(const aProcHandle: THandle): Boolean;

    procedure AddModule(const aPID: Cardinal; const aBaseAddress: Pointer);
    procedure DelModule(const aBaseAddress: Pointer);
    function GetModuleBaseAddressByName(const ModuleName: string): Pointer;
    function GetModuleNameByBaseAddress(const aBaseAddress: Pointer): string;

    procedure EnumProcessThreads(const aPID: Cardinal);

    procedure EnumProcessModules(const PID: Cardinal);
    function ProcToModuleName(const hProcess: THandle; const ptr: Pointer;
      const aFullPath: Boolean = True): string;

    function ProcIsBadReadPtr(const hProcess: THandle; const aPtr: Pointer;
      const aCount: Integer; const aFullRead: boolean = True): Boolean;
    function ProcCheckHeuristic(const hProcess: THandle;
      const axret: Cardinal): Boolean;

    function GetMapObj(const aModuleName: string): TLkMapInfo;
  private
    FOnNotify: TNotifyProc;
    FNeedStop: Boolean;

    procedure Notify(const aNotifyTpe: TNotifyType; const aFlags: Cardinal;
      const aInfo: string); overload;
    procedure Notify(const aNotifyTpe: TNotifyType; const aFlags: Cardinal;
      const aInfo: TObject); overload;
  public
    procedure AttachToProcess(const aProcessID: Cardinal);
    procedure StartProcess(const aFileName, aFilePath, aParams: string);
    procedure DetachFromProgramm;

    procedure StartTrace;
    procedure SuspendTrace;
    procedure TerminateTrace;
    procedure TerminateProc;
  public
    property OnNotify: TNotifyProc read FOnNotify write FOnNotify;
    property NeedStop: Boolean read FNeedStop write FNeedStop;
  public
    procedure AfterConstruction; override;
    procedure BeforeDestruction; override;
  protected
    procedure Execute; override;
  public
    class function CreateTracer: TTracer;
  end;

// FLAGS
const
  FLAG_NONE = 0;
  FLAG_CREATE_PROCESS = 1;
  FLAG_EXIT_PROCESS = 2;
  FLAG_CREATE_THREAD = 3;
  FLAG_EXIT_THREAD = 4;
  FLAG_LOADD_DLL = 5;
  FLAG_UNLOAD_DLL = 6;
  FLAG_DEBUG_PRINT = 7;
  FLAG_RIP = 8;
  FLAG_EXCEPTION = 9;

  FLAG_THREADS_LIST = 10;
  FLAG_MODULES_LIST = 11;
  FLAG_ON_EXCEPTION = 12;

implementation

uses
  types_const_u;

var
  LibraryHandle: HMODULE;

  NtQuerySystemInformation: TNtQuerySystemInformation;
  NtQueryInformationProcess: TNtQueryInformationProcess;
  NtRemoveProcessDebug: TNtRemoveProcessDebug;
  NtSetInformationDebugObject: TNtSetInformationDebugObject;
  NtClose: TNtClose;
  NtDelayExecution: TNtDelayExecution;
  //
  RtlCreateQueryDebugBuffer: TFNRtlCreateQueryDebugBuffer;
  RtlQueryProcessDebugInformation: TFNRtlQueryProcessDebugInformation;
  RtlDestroyQueryDebugBuffer: TFNRtlDestroyQueryDebugBuffer;

{ TTracer }

procedure TTracer.AddModule(const aPID: Cardinal; const aBaseAddress: Pointer);
var
  hSnapshoot: THandle;
  me32: TModuleEntry32;
  info: TModuleInfoObj;
begin
  hSnapshoot := CreateToolhelp32Snapshot(TH32CS_SNAPMODULE, aPID);
  if (hSnapshoot = INVALID_HANDLE_VALUE) then
    Exit;
  try
    me32.dwSize := SizeOf(TModuleEntry32);
    if (Module32First(hSnapshoot, me32)) then
      repeat
        if me32.modBaseAddr <> aBaseAddress then
          Continue;

        info := TModuleInfoObj.Create;

        info.Base := Cardinal(me32.modBaseAddr);
        info.Size := me32.modBaseSize;
        info.Flags := 0;
        info.Index := 0;
        info.LoadCount := 0;
        info.ImageName := me32.szExePath;

        FModulesList.Add(info);
      until not Module32Next(hSnapshoot, me32);
  finally
    CloseHandle (hSnapshoot);
  end;
end;

procedure TTracer.AfterConstruction;
begin
  inherited;
  FModulesList := TObjectList.Create(True);
  FMapList := TObjectList.Create(True);
  FThreadsList := TObjectList.Create(True);
end;

procedure TTracer.AttachToProcess(const aProcessID: Cardinal);
begin
  FProcID := aProcessID;
  FFlag := fAttachProcess;
end;

procedure TTracer.BeforeDestruction;
begin
  FModulesList.Free;
  FMapList.Free;
  FThreadsList.Free;

  inherited;
end;

class function TTracer.CreateTracer: TTracer;
begin
  Result := TTracer.Create(True);
  Result.FreeOnTerminate := True;
end;

procedure TTracer.DelModule(const aBaseAddress: Pointer);
var
  i: Integer;
begin
  for i := 0 to Pred(FModulesList.Count) do
    if TModuleInfoObj(FModulesList[i]).Base = Cardinal(aBaseAddress) then
    begin
      FModulesList.Delete(i);
      Exit;
    end;
end;

procedure TTracer.DetachFromProgramm;
begin
  FFlag := fDetachProcess;
end;

function TTracer.DetachTracer(const aProcHandle: THandle): Boolean;
var
  DebugObjectHandle: THandle;
  DebugFlags: ULONG;
begin
  Result := False;
  try
    DebugObjectHandle := 0;
    if NtQueryInformationProcess(aProcHandle, 30, @DebugObjectHandle, SizeOf(THandle), nil) = 0 then
    begin
      try
        DebugFlags := 0;
        NtSetInformationDebugObject(DebugObjectHandle, 2, @DebugFlags, SizeOf(ULONG), nil);

        if NtRemoveProcessDebug(aProcHandle, DebugObjectHandle) = 0 then
          Result := True;
      finally
        if DebugObjectHandle <> 0 then
          NtClose(DebugObjectHandle);
      end;
    end;
  except
  end;
end;

procedure TTracer.EnumProcessThreads(const aPID: Cardinal);
const
  INFO_CLASS: Integer = 5; { Информация о процессах и потоках }
var
  listSize: Integer;
  pprocess, pprocess2: PSYSTEM_PROCESSES;
  PThreads: PSYSTEM_THREADS_ARRAY;
  ret: NTSTATUS;
  length: DWORD;
  NextOffset: ULONG;
  i: Integer;
  info: TThreadInfoObj;
//  hThread: THandle;
{var
  threadSnapshotHandle: THandle;
  threadEntry: tagTHREADENTRY32;
  info: TThreadInfoObj;
  hThread: THandle; }
begin
{  threadSnapshotHandle := CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0);
  try
    threadEntry.dwSize := SizeOf(threadEntry);
    FThreadsList.Clear;
    if Thread32First(threadSnapshotHandle, threadEntry) then
    repeat
      if threadEntry.th32OwnerProcessID = aPID then
      begin
        info := TThreadInfoObj.Create;
        FThreadsList.Add(info);
        info.ThreadID := threadEntry.th32ThreadID;
        info.BasePri := threadEntry.tpBasePri;
        info.DeltaPri := threadEntry.tpDeltaPri;
        info.Flags := threadEntry.dwFlags;

        hThread := OpenThread(threadEntry.th32ThreadID, False, THREAD_ALL_ACCESS);
        if hThread <> INVALID_HANDLE_VALUE then
          try
            GetThreadContext(hThread, info.Context);
          finally
            CloseHandle(hThread);
          end;
      end;
    until not Thread32Next(threadSnapshotHandle, threadEntry);
  finally
    CloseHandle(threadSnapshotHandle);
  end;}
  listSize := $400;

  GetMem(pprocess, listSize);
  pprocess2 := pprocess;

  ret := NtQuerySystemInformation(INFO_CLASS, pprocess, listSize, @length);
  while (ret = STATUS_INFO_LENGTH_MISMATCH) do
  begin
    FreeMem(pprocess);
    listSize := listSize * 2;
    GetMem(pprocess, listSize);
    pprocess2 := pprocess;
    ret := NtQuerySystemInformation(INFO_CLASS, pprocess, listSize, @length);
  end;

  if (ret <> STATUS_SUCCESS) then
  begin
    FreeMem(pprocess);
    Exit;
  end;

  try
    repeat
      if pprocess^.ProcessId <> aPID then
      begin
        NextOffset := pprocess^.NextEntryDelta;
        pprocess := PSYSTEM_PROCESSES(DWORD(pprocess) + NextOffset);
        Continue;
      end;

      PThreads := PSYSTEM_THREADS_ARRAY(DWORD(PProcess) + SizeOf(SYSTEM_PROCESSES));

      FThreadsList.Clear;
      for i := 0 to Pred(Integer(pprocess^.ThreadCount)) do
      begin
        info := TThreadInfoObj.Create;
        FThreadsList.Add(info);

        info.ThreadID         := IntToStr(PThreads^[i].ClientId.UniqueThread);

        info.KernelTime       := FileTimeToTime(PThreads^[i].KernelTime);
        info.UserTime         := FileTimeToTime(PThreads^[i].UserTime);
        info.CreateTime       := FileTimeToDateTime(PThreads^[i].CreateTime);

        info.StartAddress     := '$' + IntToHex(Cardinal(PThreads^[i].StartAddress), 8);
        info.Priority         := IntToStr(PThreads^[i].Priority);
        info.BasePriority     := IntToStr(PThreads^[i].BasePriority);
        info.ContextSwitches  := IntToStr(PThreads^[i].ContextSwitches);
        info.ThreadState      := IntToStr(PThreads^[i].ThreadState);
        info.WaitReason       := WAIT_REASON_STR[_KWAIT_REASON(PThreads^[i].WaitReason)];

//        hThread := OpenThread(PThreads^[i].ClientId.UniqueThread, False, THREAD_ALL_ACCESS);
//        if hThread <> INVALID_HANDLE_VALUE then
//          try
//            GetThreadContext(hThread, info.Context);
//          finally
//            CloseHandle(hThread);
//          end;
      end;
      Break;
    until NextOffset = 0;
  finally
    FreeMem(pprocess2);
  end;
end;

procedure TTracer.Execute;
const
  STRING_START_PROCESS_TEMPLATE = 'Process Start: %s. Base Address: $%s. Process %s (%d)';
  STRING_LOAD_MODULE_TEMPLATE   = 'Module Load: %s. Base Address: $%s. Process %s (%d)';
  STRING_EXIT_PROCESS_TEMPLATE  = 'Process %d terminated';
  STRING_RIP_TEMPLATE           = 'System debugging error %d (%d)';
  STRING_DEBUG_PRINT_TEMPLATE   = 'Debug output: %s Process %s (%d)';
  STRING_LOAD_DLL_TEMPLATE      = 'Module Load: %s. Base Address: $%s. Process %s (%d)';
  STRING_UNLOAD_DLL_TEMPLATE    = 'Module Unload: %s. Process %s (%d)';
  STRING_START_THREAD_TEMPLATE  = 'Thread Start: Thread ID: %d. Process %s (%d)';
  STRING_EXIT_THREAD_TEMPLATE   = 'Thread Exit: Thread ID: %d. Process %s (%d)';
  STRING_EXCEPTION_TEMPLATE     = 'First chance exception at %s. Process %s (%d)';

var
  processBaseAddress: Pointer;
  procInfo: TProcessInformation;

  procedure OnCreateProcessEvent(const aDebugEvent: _DEBUG_EVENT);
  var
    i: Integer;
    procName: string;
  begin
    EnumProcessModules(aDebugEvent.dwProcessId);

    procName := GetModuleNameByBaseAddress(processBaseAddress);

    // главный поток процесса
    Notify(ntLogEvent, FLAG_CREATE_THREAD,
      Format(STRING_START_THREAD_TEMPLATE,
             [aDebugEvent.dwThreadId,
              ExtractFileName(procName),
              aDebugEvent.dwProcessId
              ]
             )
    );

    Notify(ntLogEvent, FLAG_CREATE_PROCESS,
      Format(STRING_START_PROCESS_TEMPLATE,
             [procName,
              IntToHex(Cardinal(processBaseAddress), 8),
              ExtractFileName(procName),
              aDebugEvent.dwProcessId
              ]
             )
    );

    // GetProcessModules вынуждает процесс загрузить все базовые модули без отсыла события отладчику
    // выведем их в лог
    for i := 0 to Pred(FModulesList.Count) do
      Notify(ntLogEvent, FLAG_LOADD_DLL,
        Format(STRING_LOAD_MODULE_TEMPLATE,
               [ExtractFileName(TModuleInfoObj(FModulesList[i]).ImageName),
                IntToHex(TModuleInfoObj(FModulesList[i]).Base, 8),
                ExtractFileName(procName),
                aDebugEvent.dwProcessId
                ]
               )
      );
  end;

  procedure OnTerminateProcessEvent(const aPID: Cardinal);
  begin
    Notify(ntLogEvent, FLAG_EXIT_PROCESS,
      Format(STRING_EXIT_PROCESS_TEMPLATE,
             [aPID]
             )
    );
  end;

  procedure OnDebugPrintEvent(const aDebugEvent: _DEBUG_EVENT);
  var
    data: array of AnsiChar;
    len: Cardinal;
    readed: Cardinal;
  begin
    len := aDebugEvent.DebugString.nDebugStringLength;

    if len = 0 then
      Exit;

    SetLength(data, Integer(len));
    try
      // lpDebugStringData - указатель на строку с дебаг строчкой в АП процесса
      ReadProcessMemory(procInfo.hProcess,
                        aDebugEvent.DebugString.lpDebugStringData,
                        @data[0],
                        len,
                        readed
      );

      if readed = len then
        Notify(ntLogEvent, FLAG_DEBUG_PRINT,
          Format(STRING_DEBUG_PRINT_TEMPLATE,
                 [PAnsiChar(@data[0]),
                  ExtractFileName(GetModuleNameByBaseAddress(processBaseAddress)),
                  aDebugEvent.dwProcessId
                  ]
                 )
        );
    finally
      SetLength(data, 0);
    end;
  end;

  procedure OnCreateThreadEvent(const aDebugEvent: _DEBUG_EVENT);
  begin
    Notify(ntLogEvent, FLAG_CREATE_THREAD,
      Format(STRING_START_THREAD_TEMPLATE,
             [aDebugEvent.dwThreadId,
              ExtractFileName(GetModuleNameByBaseAddress(processBaseAddress)),
              aDebugEvent.dwProcessId
              ]
             )
    );

    Notify(ntThreadsInfo, FLAG_THREADS_LIST, FThreadsList);
  end;

  procedure OnExitThreadEvent(const aDebugEvent: _DEBUG_EVENT);
  begin
    Notify(ntLogEvent, FLAG_EXIT_THREAD,
      Format(STRING_EXIT_THREAD_TEMPLATE,
             [aDebugEvent.dwThreadId,
              ExtractFileName(GetModuleNameByBaseAddress(processBaseAddress)),
              aDebugEvent.dwProcessId
              ]
             )
      );

    Notify(ntThreadsInfo, FLAG_THREADS_LIST, FThreadsList);
  end;

  procedure OnLoadDllEvent(const aDebugEvent: _DEBUG_EVENT);
  begin
    Notify(ntLogEvent, FLAG_LOADD_DLL,
      Format(STRING_LOAD_DLL_TEMPLATE,
             [ExtractFileName(GetModuleNameByBaseAddress(aDebugEvent.LoadDll.lpBaseOfDll)),
              IntToHex(Cardinal(aDebugEvent.LoadDll.lpBaseOfDll), 8),
              ExtractFileName(GetModuleNameByBaseAddress(processBaseAddress)),
              aDebugEvent.dwProcessId
              ]
             )
    );

    Notify(ntModulesInfo, FLAG_MODULES_LIST, FModulesList);
  end;

  procedure OnUnloadDllEvent(const aDebugEvent: _DEBUG_EVENT);
  begin
    Notify(ntLogEvent, FLAG_UNLOAD_DLL,
      Format(STRING_UNLOAD_DLL_TEMPLATE,
             [ExtractFileName(GetModuleNameByBaseAddress(aDebugEvent.UnloadDll.lpBaseOfDll)),
              ExtractFileName(GetModuleNameByBaseAddress(processBaseAddress)),
              aDebugEvent.dwProcessId
              ]
             )
    );

    Notify(ntModulesInfo, FLAG_MODULES_LIST, FModulesList);
  end;

  procedure OnRipEvent(const aDebugEvent: _DEBUG_EVENT);
  begin
    Notify(ntLogEvent, FLAG_RIP,
      Format(STRING_RIP_TEMPLATE,
             [aDebugEvent.RipInfo.dwError,
              aDebugEvent.RipInfo.dwType
              ]
             )
    );
  end;

  procedure OnExceptionEvent(const aEIP: Cardinal; const aDebugEvent: _DEBUG_EVENT);
  begin
    Notify(ntLogEvent, FLAG_EXCEPTION,
      Format(STRING_EXCEPTION_TEMPLATE,
             ['$' + IntToHex(aEIP, 8),
              ExtractFileName(GetModuleNameByBaseAddress(processBaseAddress)),
              aDebugEvent.dwProcessId
             ]
             )
    );
  end;

  procedure OnTimer(aTracer: TTracer);
  begin
    if not aTracer.FCanTimer  then
      Exit;

    aTracer.EnumProcessThreads(aTracer.FProcID);
    aTracer.Notify(ntThreadsInfo, FLAG_THREADS_LIST, aTracer.FThreadsList);

    aTracer.EnumProcessModules(aTracer.FProcID);
    aTracer.Notify(ntModulesInfo, FLAG_MODULES_LIST, aTracer.FModulesList);
  end;

var
  startInfo: TStartupInfo;
  cmdLine: ShortString;
  dbgEvnt: _DEBUG_EVENT;
  cont: _Context;
  dwContinueStatus,
  fs_base,
  readed,
  hthread,
  xret,
  cur_ebp : Cardinal;
  fs_entry: LDT_ENTRY;
  validStackPtr: Boolean;
  mapFile, exceptInfo, stackTrace: string;
  tib: NT_TIB;
  map: TLkMapInfo;
  baseAddress: Pointer;
  dllLoad: Boolean;

label
  contDbg, loadDLL;
begin
  case FFlag of
    fAttachProcess:
    begin
      procInfo.dwProcessId := FProcID;
      procInfo.hProcess := OpenProcess(PROCESS_ALL_ACCESS, False, procInfo.dwProcessId);

      if IsProcessUnderDebugger(procInfo.hProcess) then
      begin
        // show error
      end
      else
        DebugActiveProcess(procInfo.dwProcessId);
    end;

    fCreateProcess:
    begin
      cmdLine := Format('"%s"%s', [FFileName, FParams]);
      FillChar(startInfo, SizeOf(startInfo), 0);

      with startInfo do
      begin
        cb := SizeOf(startInfo);
        dwFlags := STARTF_USESHOWWINDOW;
        wShowWindow := SW_SHOWNORMAL;
      end;

      CreateProcess(nil, PChar(string(cmdLine)), nil, nil, True,
                    DEBUG_PROCESS or DEBUG_ONLY_THIS_PROCESS, nil,
                    PChar(FFilePath), startInfo, procInfo);

      FProcID := procInfo.dwProcessId;
    end;
  end;

  FProcHandle := procInfo.hProcess;

  FCanTimer := False;
  FTimer := TTimerThread.CreateTimer(10000000 {1 sec}, @OnTimer, Self);

  while not Terminated do
  begin
    case FFlag of
      fTerminateTrace:
        begin
          FCanTimer := False; // в принципе бессмысленная строчка
          FTimer.Terminate;
          Break;
        end;

      fTerminateProcess:
        begin
          TerminateProcess(procInfo.hProcess, 0);
          FFlag := fTerminateTrace;
        end;

      fDetachProcess:
        begin
          // if not DetachTracer() then ShowTracerError!!!
          DetachTracer(procInfo.hProcess);
          FFlag := fTerminateTrace;
          Continue;
        end;
    end;

    FNeedStop := True;

    dllLoad := False;

    FCanTimer := True;

    if not WaitForDebugEvent(dbgEvnt, 100) then
    begin
      // для корректного завершения потока
      if GetLastError = ERROR_SEM_TIMEOUT then
        Continue;

      break;
    end;

    FCanTimer := False;

    dwContinueStatus := DBG_EXCEPTION_NOT_HANDLED;
    case dbgEvnt.dwDebugEventCode of
      // информируем о создании процесса
      CREATE_PROCESS_DEBUG_EVENT:
      begin
        processBaseAddress := dbgEvnt.CreateProcessInfo.lpBaseOfImage;
        OnCreateProcessEvent(dbgEvnt);
        FTimer.Resume;
      end;

      EXIT_PROCESS_DEBUG_EVENT:
      begin
        FCanTimer := False;
        FTimer.Terminate;
        if not ContinueDebugEvent(dbgEvnt.dwProcessId, dbgEvnt.dwThreadId, DBG_CONTINUE) then
          Break;

        OnTerminateProcessEvent(dbgEvnt.dwProcessId);
        break;
      end;

      // информируем о создании нового потока
      CREATE_THREAD_DEBUG_EVENT:
      begin
        EnumProcessThreads(dbgEvnt.dwProcessId);
        OnCreateThreadEvent(dbgEvnt);
      end;

      // информируем о завершении потока
      EXIT_THREAD_DEBUG_EVENT:
      begin
        EnumProcessThreads(dbgEvnt.dwProcessId);
        OnExitThreadEvent(dbgEvnt);
      end;

      // информируем о загрузке dll
      LOAD_DLL_DEBUG_EVENT:
      begin
        dllLoad := True;
        goto contDbg;
        loadDLL:;
        AddModule(dbgEvnt.dwProcessId, dbgEvnt.LoadDll.lpBaseOfDll);
        OnLoadDllEvent(dbgEvnt);
        Continue;
      end;

      // информируем о выгрузке dll
      UNLOAD_DLL_DEBUG_EVENT:
      begin
        OnUnloadDllEvent(dbgEvnt);
        DelModule(dbgEvnt.UnloadDll.lpBaseOfDll);
      end;

      OUTPUT_DEBUG_STRING_EVENT:
        OnDebugPrintEvent(dbgEvnt);

      RIP_EVENT:
        OnRipEvent(dbgEvnt);

      EXCEPTION_DEBUG_EVENT:
      begin
        stackTrace := '';
        exceptInfo := '';
        case dbgEvnt.Exception.ExceptionRecord.ExceptionCode of
          EXCEPTION_BREAKPOINT:
          begin
            dwContinueStatus := DBG_CONTINUE;
            // ненужный код, точнее бессмысленный, все равно неправильно работает
//            cont.ContextFlags := CONTEXT_CONTROL;
//
//            GetThreadContext(dbgEvnt.dwThreadId, cont);
//            cont.EFlags := cont.EFlags or $100;
//            cont.ContextFlags := CONTEXT_CONTROL;
//            SetThreadContext(dbgEvnt.dwThreadId, cont);
            // ненужный код
            goto contDbg;
          end;

          EXCEPTION_SINGLE_STEP:
          begin
            dwContinueStatus := DBG_CONTINUE;
            // ненужный код
//            cont.ContextFlags := CONTEXT_CONTROL;
//            GetThreadContext(dbgEvnt.dwThreadId, cont);
//            cont.EFlags := cont.EFlags or $100;
//            cont.ContextFlags := CONTEXT_CONTROL;
//            SetThreadContext(dbgEvnt.dwThreadId, cont);
            // ненужный код
            goto contDbg;
          end;

          EXCEPTION_ACCESS_VIOLATION        : exceptInfo := 'Access Violation';
          EXCEPTION_NONCONTINUABLE_EXCEPTION: exceptInfo := 'Noncontinuable Exception';
          EXCEPTION_DATATYPE_MISALIGNMENT   : exceptInfo := 'Datatype Misalignment';
          EXCEPTION_ARRAY_BOUNDS_EXCEEDED   : exceptInfo := 'Array Bounds Exceeded';
          EXCEPTION_FLT_DENORMAL_OPERAND    : exceptInfo := 'Flt Denormal Operand';
          EXCEPTION_FLT_DIVIDE_BY_ZERO      : exceptInfo := 'Flt Divide By Zero';
          EXCEPTION_FLT_INEXACT_RESULT      : exceptInfo := 'Access Violation';
          EXCEPTION_FLT_INVALID_OPERATION   : exceptInfo := 'Flt Invalid Operation';
          EXCEPTION_FLT_OVERFLOW            : exceptInfo := 'Flt Overflow';
          EXCEPTION_FLT_STACK_CHECK         : exceptInfo := 'Flt Stack Check';
          EXCEPTION_FLT_UNDERFLOW           : exceptInfo := 'Flt Underflow';
          EXCEPTION_INT_DIVIDE_BY_ZERO      : exceptInfo := 'Int Divide By Zero';
          EXCEPTION_INT_OVERFLOW            : exceptInfo := 'Int Overflow';
          EXCEPTION_PRIV_INSTRUCTION        : exceptInfo := 'Priveleged Instruction';
          EXCEPTION_IN_PAGE_ERROR           : exceptInfo := 'In Page Error';
          EXCEPTION_ILLEGAL_INSTRUCTION     : exceptInfo := 'IllegalInstruction';
          EXCEPTION_STACK_OVERFLOW          : exceptInfo := 'Stack Overflow';
          EXCEPTION_INVALID_DISPOSITION     : exceptInfo := 'Invalid Disposition';
          EXCEPTION_GUARD_PAGE              : exceptInfo := 'Guard Page';
          EXCEPTION_INVALID_HANDLE          : exceptInfo := 'Invalid Handle';
        else
          exceptInfo                                     := 'Application Exception';
        end;

        // DE.Exception.ExceptionRecord.ExceptionInformation[1] - там либо код ошибки, либо объект exception
        // поток, в котором произошло исключение
        hthread := OpenThread(THREAD_ALL_ACCESS, False, dbgEvnt.dwThreadId);
        if hthread <> INVALID_HANDLE_VALUE then
          try
            FillChar(fs_entry, sizeof(fs_entry), 0);
            cont.ContextFlags := CONTEXT_FULL;
            GetThreadContext(hthread, cont);
            GetThreadSelectorEntry(hthread, cont.SegFs, fs_entry);
            fs_base := fs_entry.BaseLow or (fs_entry.BaseMid shl 16) or
                                           (fs_entry.BaseHi  shl 24);

            ReadProcessMemory(procInfo.hProcess,
                              pointer(fs_base),
                              @tib,
                              SizeOf(NT_TIB),
                              readed
            );

            EnumProcessThreads(procInfo.dwProcessId);
            EnumProcessModules(procInfo.dwProcessId);

            Notify(ntExceptInfo, FLAG_THREADS_LIST, FThreadsList);
            Notify(ntExceptInfo, FLAG_MODULES_LIST, FModulesList);

            exceptInfo := Format('Exception module <%s>'#13#10+
                                 'Exception address <%s>'#13#10+
                                 'Exception code <%s>'#13#10+
                                 'Exception info: %s'#13#10,
                                [ProcToModuleName(procInfo.hProcess,
                                 dbgEvnt.Exception.ExceptionRecord.ExceptionAddress),
                                 intToHex(cont.Eip, 8),
                                 inttohex(dbgEvnt.Exception.ExceptionRecord.ExceptionCode, 8),
                                 exceptInfo]
            );

            OnExceptionEvent(cont.Eip, dbgEvnt);

            Notify(ntExceptInfo, FLAG_ON_EXCEPTION, exceptInfo);
            Notify(ntContextInfo, FLAG_ON_EXCEPTION, ContextToStr(cont));

            cur_ebp := cont.Ebp;
            while (cur_ebp < Cardinal(tib.StackBase)) do
            begin
              xret := 0;
              ReadProcessMemory(procInfo.hProcess, pointer(cur_ebp), @xret, sizeof(xret), readed);
              validStackPtr := not ProcIsBadReadPtr(procInfo.hProcess, pointer(xret), 1);
              validStackPtr := validStackPtr and
                               ((xret > Cardinal(tib.StackBase)) or
                                (xret < Cardinal(tib.StackLimit)));
              validStackPtr := validStackPtr and ProcCheckHeuristic(procInfo.hProcess, xret);
              if validStackPtr then
              begin
                mapFile := ProcToModuleName(procInfo.hProcess, pointer(xret - 2));

                map := GetMapObj(mapFile);

                if map <> nil then
                begin
                  baseAddress := GetModuleBaseAddressByName(mapFile);

                  stackTrace := stackTrace + Format('%s: %s'#13#10,
                    [ExtractFileName(mapFile),
                     map.GetAddrMapInfo(xret - 2, Cardinal(baseAddress))]
                  );
                end;
              end;
              inc(cur_ebp, 4);
            end;

            Notify(ntStackTrace, FLAG_NONE, stackTrace);
          finally
            CloseHandle(hthread);
          end;

        FFlag := fSuspend;
        if FNeedStop then
        begin
          FTimer.Suspend;
          Suspend;
          FTimer.Resume;
        end;
      end;
    end;
    contDbg:;
    if not ContinueDebugEvent(dbgEvnt.dwProcessId, dbgEvnt.dwThreadId, dwContinueStatus) then
      break;

    if dllLoad then
      goto loadDLL;
  end;

  CloseHandle(procInfo.hProcess);
end;

function TTracer.GetMapObj(const aModuleName: string): TLkMapInfo;
var
  i: integer;
  mapName: string;
begin
  mapName := ChangeFileExt(aModuleName, '.map');
  for i := 0 to Pred(FMapList.Count) do
  begin
    Result := TLkMapInfo(FMapList[i]);
    if Result.MapFileName = mapName then
      Exit;
  end;

  Result := TLkMapInfo.Create(mapName);
  FMapList.Add(Result);
end;

function TTracer.GetModuleBaseAddressByName(const ModuleName: string): Pointer;
var
  i: Integer;
  info: TModuleInfoObj;
  mName: string;
begin
  mName := UpperCase(ModuleName);
  for i := 0 to Pred(FModulesList.Count) do
  begin
    info := TModuleInfoObj(FModulesList[i]);
    if {(info.szExePath = mName) or }(ExtractFileName(UpperCase(info.ImageName)) = ExtractFileName(mName)) then
      Exit(Pointer(info.Base));
  end;
  Result := nil;
end;

function TTracer.GetModuleNameByBaseAddress(
  const aBaseAddress: Pointer): string;
var
  i: Integer;
begin
  for i := 0 to Pred(FModulesList.Count) do
    if TModuleInfoObj(FModulesList[i]).Base = Cardinal(aBaseAddress) then
      Exit(TModuleInfoObj(FModulesList[i]).ImageName);

  Result := 'Unknow';
end;

procedure TTracer.EnumProcessModules(const PID: Cardinal);
var
  DbgBuffer: PDebugBuffer;
  i: Integer;
  info: TModuleInfoObj;

(*  hSnapshoot: THandle;
  me32: TModuleEntry32;*)
begin
(*  if aTLHelp32 then
  begin
    hSnapshoot := CreateToolhelp32Snapshot(TH32CS_SNAPMODULE, PID);
    if (hSnapshoot = INVALID_HANDLE_VALUE) then
      Exit;

    FModulesList.Clear;
    try
      me32.dwSize := SizeOf(TModuleEntry32);
      if (Module32First(hSnapshoot, me32)) then
        repeat
          info := TModuleInfoObj.Create;

          info.Base := Cardinal(me32.modBaseAddr);
          info.Size := me32.modBaseSize;
          info.Flags := 0;
          info.Index := 0;
          info.LoadCount := 0;
          info.ImageName := me32.szExePath;

          FModulesList.Add(info);
        until not Module32Next(hSnapshoot, me32);
    finally
      CloseHandle (hSnapshoot);
    end;
  end else*)
  DbgBuffer := RtlCreateQueryDebugBuffer(0, false);
  if Assigned(DbgBuffer) then
    try
      FModulesList.Clear;
      if (RtlQueryProcessDebugInformation(PID, PDI_MODULES, DbgBuffer^) >= 0) and
         (DbgBuffer.ModuleInformation <> nil) then
        for i := 0 to Pred(Integer(DbgBuffer.ModuleInformation.Count)) do
        begin
          info := TModuleInfoObj.Create;

          info.Base       := DbgBuffer.ModuleInformation.Modules[i].Base;
          info.Size       := DbgBuffer.ModuleInformation.Modules[i].Size;
          info.Flags      := DbgBuffer.ModuleInformation.Modules[i].Flags;
          info.Index      := DbgBuffer.ModuleInformation.Modules[i].Index;
          info.LoadCount  := DbgBuffer.ModuleInformation.Modules[i].LoadCount;
          info.ImageName  := DbgBuffer.ModuleInformation.Modules[i].ImageName;

          FModulesList.Add(info);
        end;
    finally
      RtlDestroyQueryDebugBuffer(DbgBuffer);
    end;
end;

function TTracer.IsProcessUnderDebugger(const aProcHandle: THandle): Boolean;
var
  DebugPort: PVOID;
  TargetProcessHandle: THandle;
begin
  Result := False;
  try
    TargetProcessHandle := 0;
    if DuplicateHandle(GetCurrentProcess(), aProcHandle, GetCurrentProcess(),
                       @TargetProcessHandle, 0, False, DUPLICATE_SAME_ACCESS)
    then
      try
        Result := (NtQueryInformationProcess(TargetProcessHandle, 7, @DebugPort,
                    SizeOf(PVOID), nil ) = 0) and (DebugPort <> nil);
      finally
        if TargetProcessHandle <> 0 then
          CloseHandle(TargetProcessHandle); //NtClose(TargetProcessHandle);
      end;
  except

  end;
end;

procedure TTracer.Notify(const aNotifyTpe: TNotifyType; const aFlags: Cardinal;
  const aInfo: TObject);
var
  notifInfo: TNotifyStruct;
begin
  if not Assigned(FOnNotify) then
    Exit;

  notifInfo := TNotifyStruct.Create(aNotifyTpe, aFlags, aInfo);
  FOnNotify(notifInfo);
end;

procedure TTracer.Notify(const aNotifyTpe: TNotifyType; const aFlags: Cardinal;
  const aInfo: string);
var
  notifInfo: TNotifyStruct;
begin
  if not Assigned(FOnNotify) then
    Exit;

  notifInfo := TNotifyStruct.Create(aNotifyTpe, aFlags, aInfo);
  FOnNotify(notifInfo);
end;

function TTracer.ProcCheckHeuristic(const hProcess: THandle;
  const axret: Cardinal): Boolean;

  function check1(xret: Cardinal): Boolean;
  var
    readed: Cardinal;
    _data: Byte;
  begin
    Result := not ProcIsBadReadPtr(hProcess, pointer(xret - 5), 5);
    if Result then
    begin
      _data := 0;
      ReadProcessMemory(hProcess, Pointer(xret - 5), @_data, 1, readed);
      if readed = 1 then
        Result := _data = $E8
      else
        Result := False;
    end;
  end;

  function check2(xret: Cardinal): Boolean;
  var
    pMasked: pWord;
    iBackLook: Integer;
    readed: Cardinal;
    _data: Byte;
  begin
    Result := false;
    iBackLook := 2;
    while (not Result) and (iBackLook < 8) do
      begin
        pMasked := pointer(xret - iBackLook);
        Result := not ProcIsBadReadPtr(hProcess, pMasked, iBackLook);
        if Result then
        begin
          _data := 0;
          ReadProcessMemory(hProcess, Pointer(pMasked), @_data, 1, readed);
          Result := (_data and $38FF) = $10FF;
        end;
        inc(iBackLook);
      end;
  end;

begin
  Result := check1(axret);
  if not Result then Result := check2(axret);
end;

function TTracer.ProcIsBadReadPtr(const hProcess: THandle; const aPtr: Pointer;
  const aCount: Integer; const aFullRead: boolean): Boolean;
var
  _data: array of Byte;
  _readed: Cardinal;
  memInfo: TMemoryBasicInformation;
begin
  VirtualQueryEx(hProcess, aPtr, memInfo, SizeOf(memInfo));
  Result := memInfo.State <> MEM_COMMIT;

  if result then
    Exit;

  if not aFullRead then
    Exit;

  _readed := 0;
  SetLength(_data, aCount);
  try
    ReadProcessMemory(hProcess, aPtr, @_data[0], aCount, _readed);
    Result := not (_readed = Cardinal(aCount));
  finally
    SetLength(_data, 0);
  end;
end;

function TTracer.ProcToModuleName(const hProcess: THandle;
  const ptr: Pointer; const aFullPath: Boolean = True): string;
var
  memInfo: TMemoryBasicInformation;
  Temp: array[0..MAX_PATH] of Char;
begin
  FillChar(memInfo,  SizeOf(TMemoryBasicInformation), 0);

  if ptr <> nil then
  begin
    VirtualQueryEx(hProcess, ptr, memInfo, SizeOf(memInfo));
    if memInfo.State <> MEM_COMMIT then
      Exit('');
  end;

  if aFullPath then
  begin
    if GetModuleFileNameEx(hProcess, Cardinal(memInfo.AllocationBase), Temp, Length(Temp)) <> 0 then
      Result := Temp;
  end else
  begin
    if GetModuleBaseName(hProcess, Cardinal(memInfo.AllocationBase), Temp, Length(Temp)) <> 0 then
      Result := Temp;
  end;
end;

procedure TTracer.StartProcess(const aFileName, aFilePath, aParams: string);
begin
  FFlag := fCreateProcess;
  FFileName := aFileName;
  FFilePath := aFilePath;
  FParams := aParams;
end;

procedure TTracer.StartTrace;
begin
  Resume;
end;

procedure TTracer.SuspendTrace;
begin
  FFlag := fSuspend;
end;

procedure TTracer.TerminateProc;
begin
  FFlag := fTerminateProcess;
  Resume;
end;

procedure TTracer.TerminateTrace;
begin
  FFlag := fTerminateTrace;
end;

function _AddCurrentProcessPrivileges(PrivilegeName: WideString): Boolean;
var
  TokenHandle: THandle;
  TokenPrivileges: TTokenPrivileges;
  ReturnLength: DWORD;
begin
  Result := False;
  try
    if OpenProcessToken(GetCurrentProcess, TOKEN_ADJUST_PRIVILEGES or TOKEN_QUERY, TokenHandle) then
    begin
      try
        LookupPrivilegeValueW(nil, PWideChar(PrivilegeName), TokenPrivileges.Privileges[0].Luid);
        TokenPrivileges.PrivilegeCount := 1;
        TokenPrivileges.Privileges[0].Attributes := SE_PRIVILEGE_ENABLED;
        if AdjustTokenPrivileges(TokenHandle, False, TokenPrivileges, 0, nil, ReturnLength) then
          Result := True;
      finally
        CloseHandle(TokenHandle);
      end;
    end;
  except
  end;
end;

{ TNotifyStruct }

constructor TNotifyStruct.Create(const aNotifyType: TNotifyType;
  const aFlags: Cardinal; const aInfo: string);
begin
  FFlags := aFlags;
  FNotifyType := aNotifyType;
  FInfo := aInfo;
end;

constructor TNotifyStruct.Create(const aNotifyType: TNotifyType;
  const aFlags: Cardinal; const aInfo: TObject);
begin
  FFlags := aFlags;
  FNotifyType := aNotifyType;
  FInfoObj := aInfo;
end;

{ TTimerThread }

class function TTimerThread.CreateTimer(const aInterval: Int64;
  const aCallback, aParam: Pointer): TTimerThread;
begin
  Result := TTimerThread.Create(True);
  Result.FreeOnTerminate := True;
  Result.FParam := aParam;
  Result.FCallback := aCallback;
  Result.FInterval := - aInterval; // минус, ибо специфика функции
end;

procedure TTimerThread.Execute;
begin
  while not Terminated do
  begin
    NtDelayExecution(False, @FInterval);
    asm
      MOV     EAX, Self
      MOV     EAX, [EAX + FCallBack]
      TEST    EAX, EAX
      JZ      @EXIT
      PUSH    EAX
      // fastcall
      MOV     EAX, Self
      MOV     EAX, [EAX + FParam]
      POP     EDX
      CALL    EDX
      @EXIT:
    end;
  end;
end;

initialization
  _AddCurrentProcessPrivileges('SeDebugPrivilege');

  LibraryHandle := LoadLibrary('ntdll.dll');
  if LibraryHandle <> 0 then
  begin
    NtQuerySystemInformation        := GetProcAddress(LibraryHandle, 'NtQuerySystemInformation');
    NtQueryInformationProcess       := GetProcAddress(LibraryHandle, 'NtQueryInformationProcess');
    NtRemoveProcessDebug            := GetProcAddress(LibraryHandle, 'NtRemoveProcessDebug');
    NtSetInformationDebugObject     := GetProcAddress(LibraryHandle, 'NtSetInformationDebugObject');
    NtClose                         := GetProcAddress(LibraryHandle, 'NtClose');
    NtDelayExecution                := GetProcAddress(LibraryHandle, 'NtDelayExecution');

    RtlCreateQueryDebugBuffer       := GetProcAddress(LibraryHandle, 'RtlCreateQueryDebugBuffer');
    RtlQueryProcessDebugInformation := GetProcAddress(LibraryHandle, 'RtlQueryProcessDebugInformation');
    RtlDestroyQueryDebugBuffer      := GetProcAddress(LibraryHandle, 'RtlDestroyQueryDebugBuffer');
  end;

finalization
  FreeLibrary(LibraryHandle);

end.
