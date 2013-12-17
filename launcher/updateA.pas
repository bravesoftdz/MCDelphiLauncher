unit updateA;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ComCtrls, acProgressBar, StdCtrls, sLabel, Registry, settings,
  sButton, AbUnzper, AbArcTyp;

type
  TUpdateForm = class(TForm)
    TitleLabel: TsLabel;
    ProgressBar: TsProgressBar;
    StatusLabel: TsLabel;
    CancelButton: TsButton;
    SizeLabel: TsLabel;
    procedure CancelButtonClick(Sender: TObject);
    procedure Messenger(var Message: TMessage); message $FFE;
  end;


procedure _Update(Server: string; IsForceUpdate: Boolean);

const
  UpdateDir: string = 'http://www.happyminers.ru/MineCraft/MinecraftDownload/';


var
  UpdateForm: TUpdateForm;

implementation

uses Main, InternetHTTP, Launch, Auth, unMD5;

{$R *.dfm}


var
  ServerName, DownloadingFile: string;
  DownloadStatus: TDownloadStatus;
  NeedDownloadClient: boolean;


function BToMb(Bytes: integer; CharsAfterComma:integer): string;
var
  Mask: string;
  I: Integer;
begin
 if CharsAfterComma = 0 then
    Result := FloatToStr(Round(Bytes / 1048576))    //1048576 is 1024*1024
 else
 begin
  mask := '0.';
  for I := 0 to CharsAfterComma do
  begin
    Mask := Mask + '0';
  end;
  Result := FormatFloat(Mask, Bytes / 1048576);
 end;
end;

procedure FindFiles(Dir: string; Pattern: string; var FileList: TStringList);
var
  SearchRec: TSearchRec;
begin
  if FindFirst(Dir + '*', faDirectory, SearchRec) = 0 then
  begin
    repeat
      if (SearchRec.Name <> '.') and (SearchRec.Name <> '..') then
      begin
        FindFiles(Dir + SearchRec.Name + '\', Pattern, FileList);
      end;
    until FindNext(SearchRec) <> 0;
  end;
  FindClose(SearchRec);
  if FindFirst(Dir + Pattern, faAnyFile xor faDirectory, SearchRec) = 0 then
  begin
    repeat
      FileList.Add(Dir + SearchRec.Name);
    until FindNext(SearchRec) <> 0;
  end;
  FindClose(SearchRec);
end;

procedure RemoveAll(Path: string);
var
  SearchRec: TSearchRec;
begin
  if FindFirst(Path + '\*.jar', faAnyFile, SearchRec) = 0 then
  begin
    repeat
      if SearchRec.Attr and faDirectory = 0 then
      begin
        DeleteFile(Path + '\' + SearchRec.name);
      end
      else
      begin
        if Pos('.', SearchRec.name) <= 0 then
          RemoveAll(Path + '\' + SearchRec.name);
      end;
    until
      FindNext(SearchRec) <> 0;
  end;
  FindClose(SearchRec);
  //RemoveDir(PChar(Path));
end;

function CheckFiles(ServerName :string): Boolean;
var
  Files: TStringList;
  ClientHash, ServerHash: string;
  I: Integer;
begin
  Files := TStringList.Create;
  Files.Add(MinecraftDir + 'dists\' + ServerName + '\' + ServerName + '.jar');
  FindFiles(Settings.MinecraftDir+'mods\', '*.jar', Files);
  ClientHash := '';
  for I := 0 to Files.Count - 1 do
  begin
    ClientHash := ClientHash + md5_file(Files.Strings[i]);
  end;
  Files.Free;
  ServerHash := HTTPGet(UpdateDir + ServerName + '.md5');
  if ClientHash = ServerHash then Result := true else Result := false;
end;

procedure unpackFiles(FileName: string);
var
  Unpacker: TAbUnZipper;
begin
  Unpacker := TAbUnZipper.Create(nil);
  Unpacker.FileName := FileName;
  Unpacker.BaseDirectory := MinecraftDir;
  Unpacker.ExtractOptions := [eoCreateDirs, eoRestorePath];
  Unpacker.ExtractFiles('*.*');
  Unpacker.Free;
  DeleteFile(FileName);
end;

procedure DownloadFile(FileName: string);
begin
  UpdateForm.SizeLabel.Visible := true;
  DownloadingFile := FileName;
  HTTPDownload(UpdateDir + FileName, MinecraftDir + FileName, false, UpdateForm.Handle, $FFE);
end;

procedure TUpdateForm.CancelButtonClick(Sender: TObject);
begin
  ExitProcess(0);
end;

function CheckBase(IsForceUpdate: Boolean): boolean;
begin
  Result := ((FileExists(MinecraftDir + 'BaseFile')) OR (IsForceUpdate = false));
end;

function CheckServer(ServerName: string): boolean;
var
  Reg: TRegIniFile;
  Ver: string;
begin
  Reg := TRegIniFile.Create('Software\happyminers.ru');
  Reg.RootKey := HKEY_CURRENT_USER;
  Ver := HTTPGet('http://www.happyminers.ru/MineCraft/MinecraftDownload/'+ServerName+'.ver');
  Result := (((FileExists(MinecraftDir + 'dists\' + ServerName + '\BaseFile')) AND (Reg.ReadInteger('Version', ServerName, -1) = StrToInt(Ver)) AND (checkFiles(ServerName))));
  if not Result then
  begin
    Reg.WriteInteger('Version', ServerName, StrToInt(Ver));
  end;
end;

procedure _Update(Server: string; IsForceUpdate: Boolean);
begin
  MainForm.Hide;
  UpdateForm.Show;
  ServerName := Server;
  NeedDownloadClient := false;
  if not DirectoryExists(MinecraftDir) then
    CreateDir(MinecraftDir);
  if not CheckBase(isForceUpdate) then
  begin
    RemoveAll(MinecraftDir);
    NeedDownloadClient := true;
    DownloadFile('base.zip');
    Reg.WriteInteger('Version', Server, -1)
  end;
  if not CheckServer(Server) AND not NeedDownloadClient then
  begin
    DownloadFile(ServerName + '.zip');
  end;
  Reg.CloseKey;
  Reg.Free;
  Launch.PlayMinecraft(ServerName, Auth.Authdata);
end;

procedure TUpdateForm.Messenger(var Message: TMessage);
begin
  if (Message.wParam = $FFFF) then
  begin
  UnpackFiles(MinecraftDir + DownloadingFile);
    if NeedDownloadClient then
    begin
      NeedDownloadClient := false;
      DownloadFile(ServerName + '.zip');
    end;
    Exit;
  end;
  DownloadStatus := TDownloadStatus(Pointer(Message.wParam)^);
  StatusLabel.Caption := '��������... (' + FloatToStr(Round(DownloadStatus.DownloadSpeed)) + ' ����/���.)';
  SizeLabel.Caption := BToMb(DownloadStatus.ReceivedBytes, 0) + ' ��/' + BToMb(DownloadStatus.SizeOfFile, 0) + ' ��';
  SizeLabel.Left := Round(UpdateForm.Width / 2) - SizeLabel.Width;     //MAGIC!
  ProgressBar.Max := DownloadStatus.SizeOfFile;
  ProgressBar.Position := DownloadStatus.ReceivedBytes;
end;

end.
