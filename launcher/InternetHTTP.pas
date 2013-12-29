unit InternetHTTP;

interface

uses Windows;

type
  TDownloadStatus = record
    SizeOfFile: LongWord;
    DownloadSpeed: single;
    ReceivedBytes: LongWord;
    RemainingTime: single;

    // ��������� �� ���� � ������ (���� ������� �������� � ������)
    FilePtr: pointer;

    // �� 1 ����:
    CurrentReceivedBytes: LongWord;
    CurrentElapsedTime: single;
  end;

procedure HTTPDownload(URL, Destination: string; SaveInMemory: boolean; MainHandle: Cardinal; Msg: LongWord);
{
  ��������� ���� �� ������ � URL � ��������� ������� � Destination.
  ����������� � ��������� ������, ������� ���������� � �������� �
  ��������� TDownloadStatus.

  ���������:
    URL - ����� ����� � ����
    Destination - ���� � �����, � ������� ���� ��������� ������
    SaveInMemory - ���� TRUE, �� �������� ������������ � ����������� ������,
                   Destination �� ������������
    MainHandle - �����, �������� ����� ���������� ��������� � ������� ��������
    Msg - �����, ��� ������� ������ ����� ���������� ���������

  TDownloadStatus:
    SizeOfFile - ������ ������������ �����
    DownloadSpeed - �������� ��������
    ReceivedBytes - ��������� ����
    RemainingTime - �������� ������� �� ��������� ��������
    FilePointer - ��������� �� ������ ������, ���� �������� ���� (�����������)

  ����� ������ ������������ ������ ������ ���������
  �������� ��������� � ������� Msg ������ � MainHandle,
  � wParam ���������� ��������� �� ��������� TDownloadThread.

  �� ��������� �������� ������ ���������� ���������
  � �������, ��������� � Msg, � ������� � wParam = $FFFF
}

function HTTPGet(ScriptAddress: string): string;
{
  ��������� GET-������ � ������� � ScriptAddress. ����� ���������� � ������.
}

function HTTPPost(ScriptAddress: string; Data: pointer; Size: LongWord): string;
procedure AddPOSTField(var Data: pointer; var Size: LongWord; Param, Value: string);
procedure AddPOSTFile(var Data: pointer; var Size: LongWord; Param, Value, FilePath, ContentType: string);
{
  HTTPPost ��������� POST-������ � �������, ���������� � ScriptAddress.
  Data - ��������� �� ������� ������ � ����������� �������.
  Size - ������ ���� ������� ������.

  ����� ���������� � ������.

  AddPOSTField - ��������� ���� �������:
    Data - ����������, � ������� ����� ������� ���������
           �� ������� ������ � �����������.

    Size - ����������, � ������� ����� ������� ������ ������������ ������
           !!!��������!!! ����� ����������� ���������� ������� Size = 0.

    Param - �������� ����.
    Value - �������� ����.

  AddPOSTFile - ��������� � ������ ����:
    �� �� �����, ��� � � AddPOSTField

    FilePath - ���� � �����.
    ContentType - ��� �����: ��������, 'image/png'

  ������:

  var
    Size: LongWord;
    Data: pointer;
    Response: string;
  begin
    Size := 0; // ������ �����������!

    // ��������� ������ ��� �������
    AddPOSTField(Data, Size, 'user', 'Stepashka');
    AddPOSTField(Data, Size, 'password', '12345');
    AddPOSTFile(Data, Size, 'file', 'NewImage', 'C:\Photo-Stepashka.png', 'image/png');

    // ���������� ������:
    Response := HTTPPost('http://site.ru/folder/script.php', Data, Size);

    // ������� ����� �� �������:
    MessageBoxA(0, PAnsiChar(Response), '����� �� �������', MB_ICONASTERISK);
  end;
}


procedure CreatePath(EndDir: string);
{
  ������ �������� ��������� �� ��������� �������� ������������.
  ����������� �����������: "\" � "/"
}

function ExtractFileDir(Path: string): string;
{
  ��������� ���� � �����. ����������� �����������: "\" � "/"
}

function ExtractFileName(Path: string): string;
{
  ��������� ��� �����. ����������� �����������: "\" � "/"
}

function ExtractHost(Path: string): string;
{
  ��������� ��� ����� �� �������� ������.
  http://site.ru/folder/script.php  -->  site.ru
}

function ExtractObject(Path: string): string;
{
  ��������� ��� ������� �� �������� ������:
  http://site.ru/folder/script.php  -->  folder/script.php
}

implementation

//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH
//                            Windows.pas
//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH
type
  PLPSTR = ^PAnsiChar;

  POverlapped = ^TOverlapped;
  _OVERLAPPED = record
    Internal: LongWord;
    InternalHigh: LongWord;
    Offset: LongWord;
    OffsetHigh: LongWord;
    hEvent: THandle;
  end;

  TOverlapped = _OVERLAPPED;

  PSecurityAttributes = ^TSecurityAttributes;
  _SECURITY_ATTRIBUTES = record
    nLength: LongWord;
    lpSecurityDescriptor: Pointer;
    bInheritHandle: LongBool;
  end;

  TSecurityAttributes = _SECURITY_ATTRIBUTES;

const
  advapi32  = 'advapi32.dll';
  kernel32  = 'kernel32.dll';
  user32    = 'user32.dll';

  GENERIC_READ = LongWord($80000000);
  GENERIC_WRITE = $40000000;
  CREATE_ALWAYS = 2;
  FILE_ATTRIBUTE_NORMAL = $00000080;
  MB_ICONERROR = $00000010;
  OPEN_EXISTING = 3;

function CreateDirectory(lpPathName: PChar;
  lpSecurityAttributes: PSecurityAttributes): LongBool; stdcall; external kernel32 name 'CreateDirectoryA';

function CreateFile(lpFileName: PChar; dwDesiredAccess, dwShareMode: LongWord;
  lpSecurityAttributes: PSecurityAttributes; dwCreationDisposition, dwFlagsAndAttributes: LongWord;
  hTemplateFile: THandle): THandle; stdcall; external kernel32 name 'CreateFileA';

function QueryPerformanceFrequency(var lpFrequency: Int64): LongBool; stdcall; external kernel32 name 'QueryPerformanceFrequency';

function QueryPerformanceCounter(var lpPerformanceCount: Int64): LongBool; stdcall; external kernel32 name 'QueryPerformanceCounter';

function MessageBoxA(Handle: THandle; lpText, lpCaption: PAnsiChar; uType: LongWord): Integer; stdcall; external user32 name 'MessageBoxA';

function SendMessage(Handle: THandle; Msg: LongWord; wParam: LongInt; lParam: LongInt): LongInt; stdcall; external user32 name 'SendMessageA';
function PostMessage(Handle: THandle; Msg: LongWord; wParam: LongInt; lParam: LongInt): LongInt; stdcall; external user32 name 'PostMessageA';


function CloseHandle(hObject: THandle): LongBool; stdcall; external kernel32 name 'CloseHandle';

procedure Sleep(dwMilliseconds: LongWord); stdcall; external kernel32 name 'Sleep';

function WriteFile(hFile: THandle; const Buffer; nNumberOfBytesToWrite: LongWord;
  var lpNumberOfBytesWritten: LongWord; lpOverlapped: POverlapped): LongBool; stdcall; external kernel32 name 'WriteFile';

function ReadFile(hFile: THandle; var Buffer; nNumberOfBytesToRead: LongWord;
  var lpNumberOfBytesRead: LongWord; lpOverlapped: POverlapped): LongBool; stdcall; external kernel32 name 'ReadFile';

function GetFileSize(hFile: THandle; lpFileSizeHigh: Pointer): LongWord; stdcall; external kernel32 name 'GetFileSize';


//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH
//                            WinInet.pas
//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH


type
  hInternet = pointer;
  INTERNET_PORT = Word;

const
  HTTP_QUERY_CONTENT_LENGTH: LongWord = 5;
  HTTP_QUERY_FLAG_NUMBER: LongWord = $20000000;
  WinInetDLL = 'wininet.dll';

function InternetOpen(lpszAgent: PChar; dwAccessType: LongWord;
  lpszProxy, lpszProxyBypass: PChar; dwFlags: LongWord): HINTERNET; stdcall; external WinInetDLL name 'InternetOpenA';

function InternetOpenUrl(hInet: HINTERNET; lpszUrl: PChar;
  lpszHeaders: PChar; dwHeadersLength: LongWord; dwFlags: LongWord;
  dwContext: LongWord): HINTERNET; stdcall; external WinInetDLL name 'InternetOpenUrlA';

function InternetReadFile(hFile: HINTERNET; lpBuffer: Pointer;
  dwNumberOfBytesToRead: LongWord; var lpdwNumberOfBytesRead: LongWord): LongBool; stdcall; external WinInetDLL name 'InternetReadFile';

function InternetConnect(hInet: HINTERNET; lpszServerName: PChar;
  nServerPort: INTERNET_PORT; lpszUsername: PChar; lpszPassword: PChar;
  dwService: LongWord; dwFlags: LongWord; dwContext: LongWord): HINTERNET; stdcall; external WinInetDLL name 'InternetConnectA';

function HttpOpenRequest(hConnect: HINTERNET; lpszVerb: PChar;
  lpszObjectName: PChar; lpszVersion: PChar; lpszReferrer: PChar;
  lplpszAcceptTypes: PLPSTR; dwFlags: LongWord;
  dwContext: LongWord): HINTERNET; stdcall; external WinInetDLL name 'HttpOpenRequestA';

function InternetCloseHandle(hInet: HINTERNET): LongBool; stdcall; external WinInetDLL name 'InternetCloseHandle';

function HttpSendRequest(hRequest: HINTERNET; lpszHeaders: PChar;
  dwHeadersLength: LongWord; lpOptional: Pointer;
  dwOptionalLength: LongWord): LongBool; stdcall; external WinInetDLL name 'HttpSendRequestA';

function HttpQueryInfo(hRequest: HINTERNET; dwInfoLevel: LongWord;
  lpvBuffer: Pointer; var lpdwBufferLength: LongWord;
  var lpdwReserved: LongWord): LongBool; stdcall; external WinInetDLL name 'HttpQueryInfoA';

//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH

const
  AgentName: PAnsiChar = 'Launcher';
  lpPOST: PAnsiChar = 'POST';
  lpGET: PAnsiChar = 'GET';
  HTTPVer: PAnsiChar = 'HTTP/1.1';
  Boundary: string = 'ThisIsUniqueBoundary4POSTRequest';

//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

// ��������� ������ � �������� �������� � ��������:
// ����������� ����������� "\" � "/"

// ������ �������� ����� �� �������� ��������� ����� ������������:
procedure CreatePath(EndDir: string);
var
  I: LongWord;
  PathLen: LongWord;
  TempPath: string;
begin
  PathLen := Length(EndDir);
  if (EndDir[PathLen] = '\') or (EndDir[PathLen] = '/') then Dec(PathLen);
  TempPath := Copy(EndDir, 0, 3);
  for I := 4 to PathLen do
  begin
    if (EndDir[I] = '\') or (EndDir[I] = '/') then CreateDirectory(PAnsiChar(TempPath), nil);
    TempPath := TempPath + EndDir[I];
  end;
  CreateDirectory(PAnsiChar(TempPath), nil);
end;

//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

// �������� �������, � ������� ����� ����:
function ExtractFileDir(Path: string): string;
var
  I: LongWord;
  PathLen: LongWord;
begin
  PathLen := Length(Path);
  I := PathLen;
  while (I <> 0) and (Path[I] <> '\') and (Path[I] <> '/') do Dec(I);
  Result := Copy(Path, 0, I);
end;

//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

// �������� ��� �����:
function ExtractFileName(Path: string): string;
var
  I: LongWord;
  PathLen: LongWord;
begin
  PathLen := Length(Path);
  I := PathLen;
  while (Path[I] <> '\') and (Path[I] <> '/') and (I <> 0) do Dec(I);
  Result := Copy(Path, I + 1, PathLen - I);
end;

//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

// ��������� ��� �����:
// http://site.ru/folder/script.php  -->  site.ru
function ExtractHost(Path: string): string;
var
  I: LongWord;
  PathLen: LongWord;
begin
  PathLen := Length(Path);
  I := 8; // ����� "http://"
  while (I <= PathLen) and (Path[I] <> '\') and (Path[I] <> '/') do Inc(I);
  Result := Copy(Path, 8, I - 8);
end;

//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

// ��������� ��� �������:
// http://site.ru/folder/script.php  -->  folder/script.php
function ExtractObject(Path: string): string;
var
  I: LongWord;
  PathLen: LongWord;
begin
  PathLen := Length(Path);
  I := 8;
  while (I <= PathLen) and (Path[I] <> '\') and (Path[I] <> '/') do Inc(I);
  Result := Copy(Path, I + 1, PathLen - I);
end;


//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH
//                               HTTP-Download
//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH

type
  THTTPDownloadParams = record
    URL: string;
    Destination: string;
    SaveInMemory: boolean;
    MainHandle: THandle;
    Msg: LongWord;
  end;

procedure HTTPDownload(URL, Destination: string; SaveInMemory: boolean; MainHandle: Cardinal; Msg: LongWord);
  procedure Download(Parameter: pointer);
  var
    hInet, hURL: hInternet;
    hFile: THandle;
    rSize: LongWord;
    rIndex: LongWord;

    Receiver: pointer;

    ReceivedBytes: LongWord;
    WriteBytes: LongWord;

    HTTPDownloadParams: THTTPDownloadParams;

    DownloadStatus: TDownloadStatus;
    iCounterPerSec: Int64;
    T1, T2: Int64;
    ElapsedTime: single;

    FilePtr: pointer;
  const
    Header: PAnsiChar = 'Content-Type: application/x-www-form-urlencoded';
    ReceiverSize: LongWord = 131072;
  begin
    HTTPDownloadParams := THTTPDownloadParams(Parameter^);

    // ������������� ����������:
    hInet := InternetOpen(@AgentName[1], 0, nil, nil, 0);
    hURL := InternetOpenURL(hInet, PAnsiChar(HTTPDownloadParams.URL), nil, 0,  $4000000 + $100 + $80000000 + $800, 0);

    // �������� ������ �����:
    rSize := 4;
    rIndex := 0;
    HTTPQueryInfo(
                   hURL,
                   HTTP_QUERY_CONTENT_LENGTH or HTTP_QUERY_FLAG_NUMBER,
                   @DownloadStatus.SizeOfFile,
                   rSize,
                   rIndex
                  );

    asm
      xor eax, eax
      mov FilePtr, eax
      mov DownloadStatus.FilePtr, eax
      mov hFile, eax
    end;

    if HTTPDownloadParams.SaveInMemory then
    begin
    // �������� ������ ��� �����:
      GetMem(FilePtr, DownloadStatus.SizeOfFile);
      DownloadStatus.FilePtr := FilePtr;
    end
    else
    begin
    // ������ ����:
      CreatePath(ExtractFileDir(HTTPDownloadParams.Destination));
      hFile := CreateFile(
                           PAnsiChar(HTTPDownloadParams.Destination),
                           GENERIC_READ + GENERIC_WRITE,
                           0,
                           nil,
                           CREATE_ALWAYS,
                           FILE_ATTRIBUTE_NORMAL,
                           0
                          );
    end;

    DownloadStatus.ReceivedBytes := 0;
    GetMem(Receiver, ReceiverSize);

    repeat
      QueryPerformanceFrequency(iCounterPerSec);
      QueryPerformanceCounter(T1);

      InternetReadFile(hURL, Receiver, ReceiverSize, ReceivedBytes);

      QueryPerformanceCounter(T2);
      ElapsedTime := (T2 - T1) / iCounterPerSec;

      if ReceivedBytes <> 0 then
      begin
        if HTTPDownloadParams.SaveInMemory = false then
          try
            WriteFile(hFile, Receiver^, ReceivedBytes, WriteBytes, nil);
          except
            MessageBoxA(HTTPDownloadParams.MainHandle, '�� ������� �������� ������ � ����!'+#13+'��������, ���� ������� �� ������!', '������!', MB_ICONERROR);
            Break;
          end
        else
        begin
          if FilePtr = nil then
          begin
            MessageBoxA(HTTPDownloadParams.MainHandle, '�� ������� �������� ������ � ������!'+#13+'��������, �� ������� ������!', '������!', MB_ICONERROR);
            Break;
          end;
          Move(Receiver^, FilePtr^, ReceivedBytes);
          FilePtr := Pointer(LongWord(FilePtr) + ReceivedBytes);
        end;

        DownloadStatus.CurrentReceivedBytes := ReceivedBytes;
        DownloadStatus.CurrentElapsedTime := ElapsedTime;

        DownloadStatus.DownloadSpeed := ReceivedBytes / ElapsedTime;
        DownloadStatus.ReceivedBytes := DownloadStatus.ReceivedBytes + ReceivedBytes;
        DownloadStatus.RemainingTime := (DownloadStatus.SizeOfFile - DownloadStatus.ReceivedBytes) / DownloadStatus.DownloadSpeed;

        SendMessage(HTTPDownloadParams.MainHandle, HTTPDownloadParams.Msg, 0, LongWord(@DownloadStatus));
      end;
    until ReceivedBytes = 0;

    FreeMem(Receiver);

    CloseHandle(hFile);
    InternetCloseHandle(hURL);
    InternetCloseHandle(hInet);

    SendMessage(HTTPDownloadParams.MainHandle, HTTPDownloadParams.Msg, $FFFF, LongWord(@DownloadStatus));

    EndThread(0);
  end;

var
  ThreadID: Cardinal;
  Params: THTTPDownloadParams;
begin
  Params.URL := URL;
  Params.Destination := Destination;
  Params.MainHandle := MainHandle;
  Params.Msg := Msg;
  Params.SaveInMemory := SaveInMemory;
  CloseHandle(BeginThread(nil, 0, @Download, @Params, 0, ThreadID));
  Sleep(50); // �����������, ��� ������ ������� ��������� � �����
end;

//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH
//                                POST-Request
//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH

// ��������� � ������ ��������� ����:
procedure AddPOSTField(var Data: pointer; var Size: LongWord; Param, Value: string);
var
  NewMemSize: LongWord;
  NewPtr: pointer;
  StrData: string;
  DataLen: LongWord;
begin
  StrData := '';
  if Size <> 0 then StrData := StrData + #13#10;
  StrData := StrData + '--' + Boundary + #13#10;
  StrData := StrData + 'Content-Disposition: form-data; name="' + Param + '"' + #13#10;
  StrData := StrData + #13#10;
  StrData := StrData + Value;

  DataLen := Length(StrData);
  NewMemSize := Size + DataLen;

  if Size = 0 then
    GetMem(Data, NewMemSize)
  else
    ReallocMem(Data, NewMemSize);

// ���������� ��������� �� ����� ������� ����� � �������� ������:
  NewPtr := Pointer(LongWord(Data) + Size);
  Move((@StrData[1])^, NewPtr^, DataLen);

  Size := NewMemSize;
end;

// ��������� � ������ ����:
procedure AddPOSTFile(var Data: pointer; var Size: LongWord; Param, Value, FilePath, ContentType: string);
var
  hFile: THandle;
  FileSize, ReadBytes: LongWord;
  Buffer: pointer;

  NewMemSize: LongWord;
  NewPtr: pointer;
  StrData: string;
  DataLen: LongWord;
begin
  hFile := CreateFile(PAnsiChar(FilePath), GENERIC_READ, 0, nil, OPEN_EXISTING, 128, 0);
  FileSize := GetFileSize(hFile, nil);
  GetMem(Buffer, FileSize);

  ReadFile(hFile, Buffer^, FileSize, ReadBytes, nil);
  CloseHandle(hFile);

  StrData := '';
  if Size <> 0 then StrData := StrData + #13#10;
  StrData := StrData + '--' + Boundary + #13#10;
  StrData := StrData + 'Content-Disposition: form-data; name="' + Param + '"; filename="' + Value + '"' + #13#10;
  StrData := StrData + 'Content-Type: ' + ContentType + #13#10;
  StrData := StrData + #13#10;
  DataLen := Length(StrData);

  NewMemSize := Size + DataLen + ReadBytes;

  if Size = 0 then
    GetMem(Data, NewMemSize)
  else
    ReallocMem(Data, NewMemSize);

// ���������� ��������� �� ����� ������� ����� � �������� ������:
  NewPtr := Pointer(LongWord(Data) + Size);
  Move((@StrData[1])^, NewPtr^, DataLen);

  NewPtr := Pointer(LongWord(NewPtr) + DataLen);
  Move(Buffer^, NewPtr^, ReadBytes);

  FreeMem(Buffer);
  Size := NewMemSize;
end;

// ���������� �������:
function HTTPPost(ScriptAddress: string; Data: pointer; Size: LongWord): string;
var
  hInet, hConnect, hRequest: hInternet;
  ReceivedBytes: LongWord;
  Buffer: pointer;
  Response: string;
  Host: PAnsiChar;
  ScriptName: PAnsiChar;

  StrData: string;
  NewPtr: pointer;
  NewMemSize: LongWord;
  DataLen: LongWord;
const
  Header: string = 'Content-Type: multipart/form-data; boundary=';
  ReceiverSize: LongWord = 512;
begin
  Host := PAnsiChar(ExtractHost(ScriptAddress));
  ScriptName := PAnsiChar(ExtractObject(ScriptAddress));

  // ������������� ����������:
  hInet := InternetOpen(@AgentName[1], 0, nil, nil, 0);
  hConnect := InternetConnect(hInet, Host, 80, nil, nil, 3, 0, 0);
  hRequest := HTTPOpenRequest(hConnect, lpPOST, ScriptName, HTTPVer, nil, nil, $4000000 + $100 + $80000000 + $800, 0);

  // �������� ������:
  if Size = 0 then
  begin
    Result := 'Error at sending request: send data not present!';
    Exit;
  end;

  StrData := #13#10 + '--' + Boundary + '--'; // ��������� Boundary �� ���� "--boundary--"

  DataLen := LongWord(Length(StrData));
  NewMemSize := DataLen + Size;
  ReallocMem(Data, NewMemSize);
  NewPtr := Pointer(LongWord(Data) + Size);
  Move((@StrData[1])^, NewPtr^, DataLen);

  HTTPSendRequest(hRequest, PAnsiChar(Header + Boundary), Length(Header + Boundary), Data, NewMemSize);
  FreeMem(Data);

  // �������� �����:
  GetMem(Buffer, ReceiverSize);

  Response := '';

  repeat
    InternetReadFile(hRequest, Buffer, ReceiverSize, ReceivedBytes);
    if ReceivedBytes <> 0 then Response := Response + Copy(PAnsiChar(Buffer), 0, ReceivedBytes);
  until ReceivedBytes = 0;

  FreeMem(Buffer);

  InternetCloseHandle(hRequest);
  InternetCloseHandle(hConnect);
  InternetCloseHandle(hInet);

  Result := Response;
end;

//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH
//                                  GET-Request
//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH

function HTTPGet(ScriptAddress: string): string;
var
  hInet, hConnect, hRequest: hInternet;
  ReceivedBytes: LongWord;
  
  Response: string;
  Host: PAnsiChar;
  ScriptName: PAnsiChar;

  Buffer: pointer;
const
  ReceiverSize: LongWord = 512;
begin
  Host := PAnsiChar(ExtractHost(ScriptAddress));
  ScriptName := PAnsiChar(ExtractObject(ScriptAddress));

  // ������������� ����������:
  hInet := InternetOpen(@AgentName[1], 0, nil, nil, 0);
  hConnect := InternetConnect(hInet, Host, 80, nil, nil, 3, 0, 0);
  hRequest := HTTPOpenRequest(hConnect, lpGET, ScriptName, HTTPVer, nil, nil, $4000000 + $100 + $80000000 + $800, 0);

  // �������� ������:
  HTTPSendRequest(hRequest, nil, 0, nil, 0);

  // �������� �����:
  GetMem(Buffer, ReceiverSize);
  Response := '';
  repeat
    InternetReadFile(hRequest, Buffer, ReceiverSize, ReceivedBytes);
    Response := Response + Copy(PAnsiChar(Buffer), 0, ReceivedBytes);
  until ReceivedBytes = 0;

  FreeMem(Buffer);

  InternetCloseHandle(hRequest);
  InternetCloseHandle(hConnect);
  InternetCloseHandle(hInet);

  Result := Response;
end;


end.
