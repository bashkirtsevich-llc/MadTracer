unit types_const_u;

interface

uses
  Windows, Classes, SysUtils;

type
  NTSTATUS = UINT;

  USHORT = Word;
  LONG = Longint;
  PVOID = Pointer;
  ULONGLONG = UInt64;
  ULONG_PTR = NativeUInt;
  SIZE_T = ULONG_PTR;

  UNICODE_STRING = packed record
    Length: USHORT;
    MaximumLength: USHORT;
    Buffer: PWideChar;
  end;

  PUNICODE_STRING = ^UNICODE_STRING;

  KPRIORITY = LONG;

  CLIENT_ID = packed record
    UniqueProcess: THandle;
    UniqueThread: THandle;
  end;

  _KWAIT_REASON = (
    Executive,
    FreePage,
    PageIn,
    PoolAllocation,
    DelayExecution,
    Suspended,
    UserRequest,
    WrExecutive,
    WrFreePage,
    WrPageIn,
    WrPoolAllocation,
    WrDelayExecution,
    WrSuspended,
    WrUserRequest,
    WrEventPair,
    WrQueue,
    WrLpcReceive,
    WrLpcReply,
    WrVirtualMemory,
    WrPageOut,
    WrRendezvous,
    WrKeyedEvent,
    WrTerminated,
    WrProcessInSwap,
    WrCpuRateControl,
    WrCalloutStack,
    WrKernel,
    WrResource,
    WrPushLock,
    WrMutex,
    WrQuantumEnd,
    WrDispatchInt,
    WrPreempted,
    WrYieldExecution,
    WrFastMutex,
    WrGuardedMutex,
    WrRundown,
    MaximumWaitReason
  );

  KWAIT_REASON = UINT;

  SYSTEM_THREADS = packed record
    KernelTime: FILETIME;
    UserTime: FILETIME;
    CreateTime: FILETIME;
    WaitTime: ULONG;
    StartAddress: PVOID;
    ClientId: CLIENT_ID;
    Priority: KPRIORITY;
    BasePriority: LONG;
    ContextSwitches: ULONG;
    ThreadState: ULONG;
    WaitReason: KWAIT_REASON;
    Reserved: ULONG;
  end;

  SYSTEM_THREADS_ARRAY = array[0..1024] of SYSTEM_THREADS;
  PSYSTEM_THREADS_ARRAY = ^SYSTEM_THREADS_ARRAY;

  SYSTEM_PROCESS_INFORMATION = packed record
    NextEntryOffset: ULONG;
    NumberOfThreads: ULONG;
    WorkingSetPrivateSize: LARGE_INTEGER;
    HardFaultCount: ULONG;
    NumberOfThreadsHighWatermark: ULONG;
    CycleTime: ULONGLONG;
    CreateTime: FILETIME;
    UserTime: FILETIME;
    KernelTime: FILETIME;
    ImageName: UNICODE_STRING;
    BasePriority: KPRIORITY;
    ProcessId: THandle;
    InheritedFromProcessId: THandle;
    HandleCount: ULONG;
    SessionId: ULONG;
    UniqueProcessKey: ULONG_PTR;
    PeakVirtualSize: SIZE_T;
    VirtualSize: SIZE_T;
    PageFaultCount: ULONG;
    PeakWorkingSetSize: SIZE_T;
    WorkingSetSize: SIZE_T;
    QuotaPeakPagedPoolUsage: SIZE_T;
    QuotaPagedPoolUsage: SIZE_T;
    QuotaPeakNonPagedPoolUsage: SIZE_T;
    QuotaNonPagedPoolUsage: SIZE_T;
    PageFileUsage: SIZE_T;
    PeakPageFileUsage: SIZE_T;
    PrivatePageCount: SIZE_T;
    ReadOperationCount: Int64;
    WriteOperationCount: Int64;
    OtherOperationCount: Int64;
    ReadTransferCount: Int64;
    WriteTransferCount: Int64;
    OtherTransferCount: Int64;
//    Threads: array [0 .. 0] of SYSTEM_THREADS;
  end;

  PSYSTEM_PROCESS_INFORMATION = ^SYSTEM_PROCESS_INFORMATION;

  PDebugModule = ^TDebugModule;
  TDebugModule = packed record
    Reserved: array [0..1] of Cardinal;
    Base: Cardinal;
    Size: Cardinal;
    Flags: Cardinal;
    Index: Word;
    Unknown: Word;
    LoadCount: Word;
    ModuleNameOffset: Word;
    ImageName: array [0..$FF] of AnsiChar;
  end;

  PDebugModuleInformation = ^TDebugModuleInformation;
  TDebugModuleInformation = {packed?} record
    Count: Cardinal;
    Modules: array [0..0] of TDebugModule;
  end;

  PDebugBuffer = ^TDebugBuffer;
  TDebugBuffer = {packed?} record
    SectionHandle: THandle;
    SectionBase: Pointer;
    RemoteSectionBase: Pointer;
    SectionBaseDelta: Cardinal;
    EventPairHandle: THandle;
    Unknown: array [0..1] of Cardinal;
    RemoteThreadHandle: THandle;
    InfoClassMask: Cardinal;
    SizeOfInfo: Cardinal;
    AllocatedSize: Cardinal;
    SectionSize: Cardinal;
    ModuleInformation: PDebugModuleInformation;
    BackTraceInformation: Pointer;
    HeapInformation: Pointer;
    LockInformation: Pointer;
    Reserved: array [0..7] of Pointer;
  end;

  TNtQuerySystemInformation = function(
    SystemInformationClass: ULONG;
    SystemInformation: PVOID;
    SystemInformationLength: ULONG;
    ReturnLength: PULONG
    ): NTSTATUS; stdcall;

  TNtQueryInformationProcess = function(
    ProcessHandle: THandle;
    ProcessInformationClass: ULONG;
    ProcessInformation: PVOID;
    ProcessInformationLength: ULONG;
    ReturnLength: PULONG
    ): NTSTATUS; stdcall;

  TNtRemoveProcessDebug = function(
    ProcessHandle: THandle;
    DebugObjectHandle: THandle
    ): NTSTATUS; stdcall;

  TNtSetInformationDebugObject = function(
    DebugObjectHandle: THandle;
    DebugObjectInformationClass: ULONG;
    DebugInformation: PVOID;
    DebugInformationLength: ULONG;
    ReturnLength: PULONG
    ): NTSTATUS; stdcall;

  TNtClose = function(
    Handle: THandle
    ): NTSTATUS; stdcall;

  TFNRtlCreateQueryDebugBuffer = function(
    Size: Cardinal;
    EventPair: Boolean
    ): PDebugBuffer; stdcall;

  TFNRtlQueryProcessDebugInformation = function(
    ProcessId,
    DebugInfoClassMask: Cardinal;
    var DebugBuffer: TDebugBuffer
    ): NTSTATUS; stdcall;

  TFNRtlDestroyQueryDebugBuffer = function(
    DebugBuffer: PDebugBuffer
    ): NTSTATUS; stdcall;

  TNtDelayExecution = procedure(
    Alertable: boolean;
    Interval: PInt64
  ); stdcall;

  PNT_TIB = ^NT_TIB;
  NT_TIB = packed record
    ExceptionList: Pointer;
    StackBase: Pointer;
    StackLimit: Pointer;
    SubSystemTib: Pointer;
    FiberData: Pointer;
    ArbitraryUserPointer: Pointer;
    Self: PNT_TIB;
  end;

  VM_COUNTERS = packed record
    PeakVirtualSize : ULONG;
    VirtualSize : ULONG;
    PageFaultCount : ULONG;
    PeakWorkingSetSize : ULONG;
    WorkingSetSize : ULONG;
    QuotaPeakPagedPoolUsage : ULONG;
    QuotaPagedPoolUsage : ULONG;
    QuotaPeakNonPagedPoolUsage : ULONG;
    QuotaNonPagedPoolUsage : ULONG;
    PageFileUsage : ULONG;
    PeakPageFileUsage : ULONG;
  end;

  IO_COUNTERS = packed record
    ReadOperationCount : LARGE_INTEGER;
    WriteOperationCount : LARGE_INTEGER;
    OtherOperationCount : LARGE_INTEGER;
    ReadTransferCount : LARGE_INTEGER;
    WriteTransferCount : LARGE_INTEGER;
    OtherTransferCount : LARGE_INTEGER;
  end;

  SYSTEM_PROCESSES = packed record
    NextEntryDelta : ULONG;
    ThreadCount : ULONG;
    Reserved1 : array[0..5] of ULONG;
    CreateTime : LARGE_INTEGER;
    UserTime : LARGE_INTEGER;
    KernelTime : LARGE_INTEGER;
    ProcessName : UNICODE_STRING;
    BasePriority : KPRIORITY;
    ProcessId : ULONG;
    InheritedFromProcessId : ULONG;
    HandleCount : ULONG;
    Reserved2 : array[0..1] of ULONG;
    VmCounters : VM_COUNTERS;
    PrivatePageCount : ULONG;
    //
    IoCounters : IO_COUNTERS;
  end;
  PSYSTEM_PROCESSES = ^SYSTEM_PROCESSES;

  TModuleInfoObj = class
  public
    Base: Cardinal;
    Size: Cardinal;
    Flags: Cardinal;
    Index: Word;
    LoadCount: Word;
    ImageName: string;
//    th32ModuleID: Cardinal;
//    th32ProcessID: Cardinal;
//    GlblcntUsage: Cardinal;
//    ProccntUsage: Cardinal;
//    modBaseAddr: Pointer;
//    modBaseSize: Cardinal;
//    hModule: Cardinal;
//    szModule: string;
//    szExePath: string;
  end;

  TThreadInfoObj = class
  public
    ThreadID: string;
//    BasePri: Cardinal;
//    DeltaPri: Cardinal;
//    Flags: Cardinal;
    KernelTime: string;
    UserTime: string;
    CreateTime: string;
    StartAddress: string;
    Priority: string;
    BasePriority: string;
    ContextSwitches: string;
    ThreadState: string;
    WaitReason: string;
    Context: _CONTEXT;
  end;

const
  STATUS_SUCCESS = NTSTATUS($00000000);
  STATUS_INFO_LENGTH_MISMATCH = NTSTATUS($C0000004);

  PDI_MODULES = $01;

  THREAD_ALL_ACCESS = $1F03FF;

  WAIT_REASON_STR: array [_KWAIT_REASON] of string = (
    'Executive',
    'Free Page',
    'Page In',
    'Pool Allocation',
    'Delay Execution',
    'Suspended',
    'User Request',
    'Executive',
    'FreePage',
    'Page In',
    'Pool Allocation',
    'Delay Execution',
    'Suspended',
    'User Request',
    'Event Pair',
    'Queue',
    'Lpc Receive',
    'Lpc Reply',
    'Virtual Memory',
    'Page Out',
    'Rendezvous',
    'Keyed Event',
    'Terminated',
    'Process In Swap',
    'Cpu Rate Control',
    'Callout Stack',
    'Kernel',
    'Resource',
    'Push Lock',
    'Mutex',
    'Quantum End',
    'Dispatch Int',
    'Preempted',
    'Yield Execution',
    'Fast Mutex',
    'Guarded Mutex',
    'Rundown',
    'Maximum Wait Reason'
  );

function OpenThread(dwDesiredAccess: cardinal; bInheritHandle: boolean;
  dwThreadId: cardinal): cardinal; stdcall; external 'kernel32.dll';

function FileTimeToDateTime(const AFileTime: TFileTime): string;
function FileTimeToTime(const AFileTime: TFileTime): string;
function ContextToStr(const AContext: _CONTEXT): string;

implementation

const
  TIME_FORMAT_STR: string = '%d:%d:%d.%d';

function FileTimeToDateTime(const AFileTime: TFileTime): string;
var
 ModifiedTime: TFileTime;
 SystemTime: TSystemTime;
begin
  if (AFileTime.dwLowDateTime = 0) and (AFileTime.dwHighDateTime = 0) then
    Exit;

  FileTimeToLocalFileTime(AFileTime, ModifiedTime);
  FileTimeToSystemTime(ModifiedTime, SystemTime);

  Result := Format(TIME_FORMAT_STR, [SystemTime.wHour,
                                     SystemTime.wMinute,
                                     SystemTime.wSecond,
                                     SystemTime.wMilliseconds
                                     ]
  );
end;

function FileTimeToTime(const AFileTime: TFileTime): string;
var
  local: TSystemTime;
begin
  FileTimeToSystemTime(AFileTime, local);

  Result := Format(TIME_FORMAT_STR, [local.wHour,
                                     local.wMinute,
                                     local.wSecond,
                                     local.wMilliseconds
                                     ]
  );
end;

function ContextToStr(const AContext: _CONTEXT): string;
begin
  Result := Format('DR0: %x'#13#10+
                   'DR1: %x'#13#10+
                   'DR2: %x'#13#10+
                   'DR3: %x'#13#10+
                   'DR6: %x'#13#10+
                   'DR7: %x'#13#10#13#10+
                   'GS: %x'#13#10+
                   'FS: %x'#13#10+
                   'ES: %x'#13#10+
                   'DS: %x'#13#10#13#10+
                   'EDI: %x'#13#10+
                   'ESI: %x'#13#10+
                   'EBX: %x'#13#10+
                   'EDX: %x'#13#10+
                   'ECX: %x'#13#10+
                   'EAX: %x'#13#10#13#10+
                   'EBP: %x'#13#10+
                   'EIP: %x'#13#10+
                   'CS: %x'#13#10+
                   'FLAGS: %x'#13#10+
                   'ESP: %x'#13#10+
                   'SS: %x',
                  [AContext.Dr0,
                   AContext.Dr1,
                   AContext.Dr2,
                   AContext.Dr3,
                   AContext.Dr6,
                   AContext.Dr7,
                   AContext.SegGs,
                   AContext.SegFs,
                   AContext.SegEs,
                   AContext.SegDs,
                   AContext.Edi,
                   AContext.Esi,
                   AContext.Ebx,
                   AContext.Edx,
                   AContext.Ecx,
                   AContext.Eax,
                   AContext.Ebp,
                   AContext.Eip,
                   AContext.SegCs,
                   AContext.EFlags,
                   AContext.Esp,
                   AContext.SegSs
                   ]);
end;

end.

//uses SysConst, JwaNative, JwaWinType, JwaNtStatus;
//
//function NtErrorMessage(Code: NTSTATUS): String;
//var
//  hMod: Cardinal;
//  Buffer: array[0..255] of Char;
//  Len: Integer;
//begin
//  hMod:=GetModuleHandle(ntdll);
//  Len := FormatMessage(FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_IGNORE_INSERTS or
//    FORMAT_MESSAGE_ARGUMENT_ARRAY or FORMAT_MESSAGE_FROM_HMODULE, Pointer(hMod), Code, 0, Buffer,
//    SizeOf(Buffer), nil);
//  while (Len > 0) and (Buffer[Len - 1] in [#0..#32, '.']) do Dec(Len);
//  SetString(Result, Buffer, Len);
//end;
//
//function NtSuccess(Code: NTSTATUS): Boolean;
//begin
//  Result:=Code >= 0;
//end;
//
//procedure NtCheck(Code: NTSTATUS);
//begin
//  if not NtSuccess(Code) then begin
//    raise EOSError.CreateResFmt(@SOSError, [Code,NtErrorMessage(Code)]);
//  end;
//end;
//
//function GetSystemInfoTable(ASystemInformationClass: SYSTEM_INFORMATION_CLASS;
//  out Info: Pointer; out Size: Cardinal): NTSTATUS;
//var
//  SystemInfo: TSystemInfo;
//  ReturnSize: Cardinal;
//  ContinueFlag: Boolean;
//begin
//  GetSystemInfo(SystemInfo);
//  Size:=SystemInfo.dwPageSize;
//  repeat
//    Info:=VirtualAlloc(nil,Size,MEM_COMMIT or MEM_RESERVE,PAGE_READWRITE);
//    if Info = nil then
//      RaiseLastOSError;
//    Result:=NtQuerySystemInformation(ASystemInformationClass,Info,Size,@ReturnSize);
//    ContinueFlag:=Result = STATUS_INFO_LENGTH_MISMATCH;
//    if ContinueFlag then begin
//      Win32Check(VirtualFree(Info,0,MEM_RELEASE));
//      if ReturnSize = 0 then
//        Size:=Size + SystemInfo.dwPageSize
//      else
//        Size:=ReturnSize;
//    end;
//  until not ContinueFlag;
//end;
//
//function GetThreadIdByHandle(Handle: THandle): Cardinal;
//var
//  Info: _THREAD_BASIC_INFORMATION;
//begin
//  NtCheck(NtQueryInformationThread(Handle,ThreadBasicInformation,@Info,
//    SizeOf(_THREAD_BASIC_INFORMATION),nil));
//  Result:=Info.ClientId.UniqueThread;
//end;
//
//function IsThreadSuspended(ThreadID: Cardinal): Boolean;
//var
//  Info, Entry: Pointer;
//  Size, i: Cardinal;
//  ContinueFlag: Boolean;
//begin
//  Result:=false;
//  NtCheck(GetSystemInfoTable(SystemProcessesAndThreadsInformation,Info,Size));
//  try
//    Entry:=Info;
//    ContinueFlag:=true;
//    while ContinueFlag do begin
//      for i:=0 to PSYSTEM_PROCESSES(Entry)^.ThreadCount - 1 do begin
//        if PSYSTEM_PROCESSES(Entry)^.Threads[i].ClientId.UniqueThread = ThreadID
//        then begin
//          Result:=PSYSTEM_PROCESSES(Entry)^.Threads[i].WaitReason = Suspended;
//          ContinueFlag:=false;
//          Break;
//        end;
//      end;
//      if (PSYSTEM_PROCESSES(Entry)^.NextEntryDelta <> 0) then
//        Cardinal(Entry):=Cardinal(Entry) + PSYSTEM_PROCESSES(Entry)^.NextEntryDelta
//      else
//        ContinueFlag:=false;
//    end;
//  finally
//    VirtualFree(Info,0,MEM_RELEASE);
//  end;
//end;
