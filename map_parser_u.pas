unit map_parser_u;

interface

uses
  windows,
  sysutils,
  classes;

const
  MaxFilteredOutExceptions = 30;
  MAX_NFO_COUNT = 20; // max depth of stack tracing

type
  TLkMapElement = class
  private
    FRVA: Cardinal;
    FLineNumber: Integer;
    FAddrInfo: string;
    FFinRVA: Cardinal;
    procedure SetAddrInfo(const Value: string);
    procedure SetLineNumber(const Value: Integer);
    procedure SetRVA(const Value: Cardinal);
    procedure SetFinRVA(const Value: Cardinal);

  public
    property AddrInfo: string read FAddrInfo write SetAddrInfo;
    property RVA: Cardinal read FRVA write SetRVA;
    property FinRVA: Cardinal read FFinRVA write SetFinRVA;
    property LineNumber: Integer read FLineNumber write
      SetLineNumber;
  end;

  TLkMapElements = class(TList)
  private
    FMaxRVA: Cardinal;
    function GetItems(idx: Cardinal): TLkMapElement;
    procedure SetItems(idx: Cardinal; const Value: TLkMapElement);
    procedure SetMaxRVA(const Value: Cardinal);
  protected
    procedure Notify(Ptr: Pointer; Action: TListNotification);
      override;
  public
    property Items_[idx: Cardinal]: TLkMapElement read GetItems write SetItems;
    function MakeElement: TLkMapElement;
    property MaxRVA: Cardinal read FMaxRVA write SetMaxRVA;
    constructor Create;
    function LookVA(eip, va: Cardinal): Integer;
  end;

  TLkMapInfo = class
  private
    FFunctions: TLkMapElements;
    FLines: TLkMapElements;
    FIsLoaded: Boolean;
    FFileName: string;
  public
    property IsLoaded: Boolean read FIsLoaded;
    property Functions: TLkMapElements read FFunctions;
    property Lines: TLkMapElements read FLines;
    property MapFileName: string read FFileName;

    constructor Create(FileName: string);
    destructor Destroy; override;

    function GetAddrMapInfo(eip, va: Cardinal): string;

    procedure Clear;
    function LoadMapFile(FileName: string): Boolean;

    class function Global: TLkMapInfo;
  end;

implementation

uses
  strutils,
  math;

// ver 0.13+

//const
//  TrcsMax = 200;
//
//var
//  TrcMutex: Cardinal = 0;
//  TrcsLen: Integer = 0;
//  Trcs: array[0..TrcsMax] of Cardinal;
//
//function IndexOfThread(thid: Cardinal): Integer;
//var
//  l, r, m: Integer;
//begin
//  result := -1;
//  if WaitForSingleObject(TrcMutex, 1000) = WAIT_OBJECT_0 then
//  begin
//    try
//      l := 0;
//      r := TrcsLen - 1;
//      if TrcsLen = 0 then exit;
//      if Trcs[r] < thid then exit;
//// else search thread
//      while l <= r do
//        begin
//          m := (l + r) shr 1;
//          if Trcs[m] = thid then
//          begin
//            result := m;
//            break;
//          end
//          else
//          if Trcs[m] < thid then
//            l := m + 1
//          else
//            r := m;
//        end;
//      if result = -1 then result := r;
//    finally
//      ReleaseMutex(TrcMutex);
//    end;
//  end;
//end;

//function SetThreadExceptionsTracing(DoEnable: Boolean; ThId: Cardinal
//  = 0): Boolean;
//var
//  idx, i{, j}: Integer;
//begin
//  result := false;
//  if WaitForSingleObject(TrcMutex, 1000) = WAIT_OBJECT_0 then
//  begin
//    try
//      if ThId = 0 then ThId := GetCurrentThreadId;
//      idx := IndexOfThread(ThId);
//      if DoEnable then
//        begin
//          if (idx = -1) or (Trcs[idx] <> ThId) then exit;
//          for i := (idx + 1) to (TrcsLen - 1) do
//            trcs[i - 1] := trcs[i];
//          dec(TrcsLen);
//          result := true;
//        end
//      else
//        begin
//          result := (idx <> -1) and (Trcs[idx] = ThId);
//          if result then exit;
//          if TrcsLen = TrcsMax then exit;
//          if idx = -1 then Trcs[TrcsLen] := ThId
//          else
//          begin
//            for i := TrcsLen downto (idx + 1) do
//              trcs[i] := trcs[i - 1];
//            Trcs[idx] := ThId;
//          end;
//          inc(TrcsLen);
//          result := true;
//        end;
//    finally
//      ReleaseMutex(TrcMutex);
//    end;
//  end;
//end;

//

const
  CodeSectionNumber = '0001';
  CodeSectionVA = $1000;

  cnstSectionsDetails = 'Detailed map of segments';
  cnstPublicNames = 'Address Publics by Value';
  cnstLinesNumbers = 'Line numbers for ';

//type
//  TLzssBytez = array[0..(MaxInt - 1)] of byte;

{ TLkMapElement }

procedure TLkMapElement.SetAddrInfo(const Value: string);
begin
  FAddrInfo := Value;
end;

procedure TLkMapElement.SetFinRVA(const Value: Cardinal);
begin
  FFinRVA := Value;
end;

procedure TLkMapElement.SetLineNumber(const Value: Integer);
begin
  FLineNumber := Value;
end;

procedure TLkMapElement.SetRVA(const Value: Cardinal);
begin
  FRVA := Value;
end;

{ TLkMapElements }

constructor TLkMapElements.Create;
begin
  inherited;
  MaxRVA := $FFFFFFFF;
end;

function TLkMapElements.GetItems(idx: Cardinal): TLkMapElement;
begin
  result := TLkMapElement(Get(idx));
end;

function TLkMapElements.LookVA(eip, va: Cardinal): Integer;

  function chk_in(z: Integer): Integer;
  begin
    if Items_[z].FRVA > eip then
      result := -1
    else if Items_[z].FFinRVA < eip then
      result := 1
    else
      result := 0;
  end;

var
  i: Integer;
  ok: Boolean;
  gl, gh, gt: Integer;
begin
  result := -1;
  eip := eip - va;
//// version 0.09rc1+
//  if Count < 32 then
//    begin
//{$IFDEF PROFILING}
//      hpt.TimeStart;
//{$ENDIF PROFILING}
//// for small lists - linear search
//      for i := 0 to pred(Count) do
//        begin
//          ok := Items[i].RVA <= eip;
//          ok := ok and (Items[i].FinRVA >= eip);
//          if ok then
//            begin
//              result := i;
//              break;
//            end;
//        end;
//{$IFDEF PROFILING}
//      writeln(erroutput, '(linear) looking in map:', hpt.TimePeriod);
//{$ENDIF PROFILING}
//    end
//  else
//    begin
//// for a large array - binary search
{$IFDEF PROFILING}
      hpt.TimeStart;
{$ENDIF PROFILING}
      gl := 0;
      gh := pred(Count);
      if gl > gh then exit;
      if chk_in(gl) < 0 then exit;
      if chk_in(gh) > 0 then exit;
      repeat
        gt := (gl + gh) shr 1;
//      if chk_in(gl) = 0 then result := gl
//      else if chk_in(gh) = 0 then result := gh
//      else
//        begin
//          i := chk_in(gt);
//          if i = 0 then result := gt
//          else if i < 0 then gh := gt
//          else gl := gt;
//        end;
        i := chk_in(gt);
        if i = 0 then
          result := gt
        else
        if i < 0 then
          gh := gt - 1
        else
          gl := gt + 1;
        ok := (result <> -1) or (gl > gh);
      until ok;
{$IFDEF PROFILING}
      writeln(erroutput, '(binary) looking in map:', hpt.TimePeriod);
{$ENDIF PROFILING}
//    end;
end;

function TLkMapElements.MakeElement: TLkMapElement;
begin
  result := TLkMapElement.Create;
  Add(Result);
end;

procedure TLkMapElements.Notify(Ptr: Pointer; Action:
  TListNotification);
begin
  if (ptr <> nil) and (Action = lnDeleted) then
    TLkMapElement(ptr).Free;
end;

procedure TLkMapElements.SetItems(idx: Cardinal;
  const Value: TLkMapElement);
begin
  Put(idx, Value);
end;

procedure TLkMapElements.SetMaxRVA(const Value: Cardinal);
begin
  FMaxRVA := Value;
end;

{ TLkMapInfo }

procedure TLkMapInfo.Clear;
begin
  FIsLoaded := false;
  FLines.Clear;
  FFunctions.Clear;
end;

constructor TLkMapInfo.Create(FileName: string);
begin
  inherited Create;
  FFunctions := TLkMapElements.Create;
  FLines := TLkMapElements.Create;
  Clear;
  if trim(FileName) <> '' then LoadMapFile(FileName);
  FFileName := FileName;
end;

destructor TLkMapInfo.Destroy;
begin
  FLines.Free;
  FFunctions.Free;
  inherited;
end;

function cmpEl(p1, p2: Pointer): Integer;
var
  e1, e2: TLkMapElement;
begin
  try
    e1 := TLkMapElement(p1);
    e2 := TLkMapElement(p2);
    if (e1 = e2) or (e1.RVA = e2.RVA) then
    begin
      result := 0;
    end
    else if e1.RVA < e2.RVA then
    begin
      result := -1;
    end
    else
    begin
      result := 1;
    end;
  except
    result := 0;
  end;
end;

function TLkMapInfo.GetAddrMapInfo(eip, va: Cardinal): string;
var
  n1, n2: Integer;
begin
  result := '';
  n1 := Lines.LookVA(eip, va);
  if n1 <> -1 then
    result := format('[module %s; line %d] ', [lines.Items_[n1].AddrInfo,
                                               Lines.Items_[n1].LineNumber]);

  n2 := Functions.LookVA(eip, va);
  if n2 <> -1 then
    result := result + Functions.Items_[n2].AddrInfo;

  if result = '' then
    result := format('Address <%x> unknown', [eip]);
end;

var
  glb: TLkMapInfo = nil;

class function TLkMapInfo.Global: TLkMapInfo;
begin
  if glb = nil then
    glb := TLkMapInfo.Create(ChangeFileExt(ParamStr(0), '.map'));
  result := glb;
end;

function TLkMapInfo.LoadMapFile(FileName: string): Boolean;
var
  inf: TStream;
  {unp_size, cur_pos: Cardinal;}

  function inf_eof: Boolean;
  begin
    result := not (inf.Position < inf.Size)
  end;

  function ReadLine: string;
  var
    ws: ansistring;
    ch: ansichar;
    i, j{, k}: Integer;
  begin
    result := '';
    if inf_eof then exit;
//
    setlength(ws, 200);
    i := 0;
    j := 0;
    repeat
      inf.Read(ch, 1);
      if (ord(ch) > 32) or (j = 1) then
        begin
          if ord(ch) <= 32 then
            begin
              inc(i);
              ws[i] := ' ';
            end
          else
            begin
              inc(i);
              ws[i] := ch;
            end;
          j := 1;
        end;
    until (i > 190) or (ch = #13) or (inf_eof);
    if ch = #13 then
      begin
        inc(i);
        inf.Read(ws[i], 1);
      end;
    while (i > 0) and (ord(ws[i]) < 33) do dec(i);
    setlength(ws, i);
//
//    result := trim(ws);
    result := ws;
    repeat
      i := pos('  ', result);
      if i > 0 then delete(result, i, 1);
    until i = 0;
  end;

  function xcmp(s1, s2: string): Boolean;
  begin
    result := SameText(copy(s1, 1, length(s2)), s2);
  end;

  function IsSectionsDetails(ws: string): Boolean;
  begin
    result := xcmp(ws, cnstSectionsDetails);
  end;

  function SkipEmptyLines: string;
  begin
    repeat
      result := ReadLine;
    until (result <> '') or (inf_eof);
  end;

  function IsCodeAddr(ws: string): Boolean;
  begin
    result := xcmp(ws, CodeSectionNumber);
  end;

  function GetSectionDetails: Cardinal;
  var
    n1, n2: Cardinal;
    s1, s2, s3: string;
  begin
    result := $FFFFFFFF;
    s1 := SkipEmptyLines;
    while s1 <> '' do
      begin
        if IsCodeAddr(s1) then
          begin
            n1 := pos(' ', s1);
            n2 := posex(' ', s1, n1 + 1);
            if (n1 > 0) and (n2 > 0) then
              begin
                s2 := '$' + copy(s1, 6, n1 - 6);
                s3 := '$' + copy(s1, n1 + 1, n2 - n1 - 1);
                try
                  n1 := StrToInt(s2);
                  n2 := StrToInt(s3);
                  result := CodeSectionVA + n1 + n2;
                except
                end;
              end;
          end;
        s1 := ReadLine;
      end;
  end;

  function IsPublicsNames(ws: string): Boolean;
  begin
    result := xcmp(ws, cnstPublicNames);
  end;

  procedure GetPublicsNames;
  var
    n1, n2: Cardinal;
    s1, s2, s3: string;
  begin
    s1 := SkipEmptyLines;
    while s1 <> '' do
      begin
        if IsCodeAddr(s1) then
          begin
            try
              n1 := pos(' ', s1);
              s2 := '$' + copy(s1, 6, n1 - 6);
              n2 := strtoint(s2);
              s3 := trim(copy(s1, n1, 999));
              with Functions.MakeElement do
                begin
                  AddrInfo := s3;
                  RVA := CodeSectionVA + n2;
                  FinRVA := 0;
                  LineNumber := 0;
                end;
            except
            end;
          end;
        s1 := ReadLine;
      end;
  end;

  function IsLineNumbers(ws: string): Boolean;
  begin
    result := xcmp(ws, cnstLinesNumbers);
  end;

  procedure GetLineNumbers(ws: string);
  var
    n1, n2: Integer;
    s1, s2, s3, s4: string;
  begin
    s4 := copy(ws, length(cnstLinesNumbers) + 1, 999);
    n1 := pos(')', s4);
    if n1 = 0 then n1 := pos(' ', s4) - 1;
    if n1 = -1 then n1 := length(s4);
    delete(s4, n1 + 1, 999);
    s4 := trim(s4);
//
    s1 := SkipEmptyLines;
    while s1 <> '' do
      begin
        while s1 <> '' do
          begin
            n1 := pos(' ', s1);
            n2 := posex(' ', s1, n1 + 1);
            if n2 = 0 then n2 := length(s1) + 1;
            s2 := copy(s1, 1, n1 - 1);
            s3 := '$' + copy(s1, n1 + 6, n2 - n1 - 6);
            delete(s1, 1, n2);
            try
              n1 := strtoint(s2);
              n2 := strtoint(s3);
              with Lines.MakeElement do
                begin
                  RVA := CodeSectionVA + n2;
                  AddrInfo := s4;
                  LineNumber := n1;
                  FinRVA := 0;
                end;
            except
            end;
          end;
        s1 := ReadLine;
      end;
  end;

  procedure FinListFill(xlst: TLkMapElements; mxrva: Cardinal);
  var
    n1: Integer;
  begin
    xlst.MaxRVA := mxrva;
    xlst.Sort(cmpEl);
    for n1 := 0 to pred(xlst.Count) do
      if n1 = pred(xlst.Count) then
        xlst.Items_[n1].FinRVA := mxrva
      else
        xlst.Items_[n1].FinRVA := xlst.Items_[n1 + 1].RVA - 1;
  end;

var
  s1: string;
  mxrva: Cardinal;
  fst: TFileStream;
begin
  result := false;
  if not FileExists(FileName) then exit;
//---
  Clear;
  mxrva := $FFFFFFFF;
  try
    inf := TMemoryStream.Create;
    fst := TFileStream.Create(FileName, fmOpenRead);
    try
      inf.CopyFrom(fst, fst.Size);
    finally
      fst.Free;
    end;
    inf.Position := 0;
    while not inf_eof do
      begin
        s1 := ReadLine;
        if s1 <> '' then
        begin
          if IsSectionsDetails(s1) then
          begin
            mxrva := GetSectionDetails;
          end
          else
          if IsPublicsNames(s1) then
          begin
            GetPublicsNames;
          end
          else
          if IsLineNumbers(s1) then
          begin
            GetLineNumbers(s1);
          end;
        end;
      end;
    FinListFill(Lines, mxrva);
    FinListFill(Functions, mxrva);
    FIsLoaded := true;
  finally
    if Assigned(inf) then FreeAndNil(inf);
  end;
end;

//// heuristic call check
//function check_heuristic(xret: Cardinal): Boolean;
//
//  function check1(xret: Cardinal): Boolean;
//  begin
//    result := not IsBadReadPtr(pointer(xret - 5), 5);
//    if result then result := pbyte(xret - 5)^ = $E8;
//  end;
//
//  function check2(xret: Cardinal): Boolean;
//  var
//    pMasked: pWord;
//    iBackLook: Integer;
//  begin
//    result := false;
//    iBackLook := 2;
//    while (not result) and (iBackLook < 8) do
//      begin
//        pMasked := pointer(xret - iBackLook);
//        result := not IsBadReadPtr(pMasked, iBackLook);
//        if result then result := (pMasked^ and $38FF) = $10FF;
//        inc(iBackLook);
//      end;
//  end;
//
//begin
//  result := false;
//  if not result then result := check1(xret);
//  if not result then result := check2(xret);
//end;

end.
