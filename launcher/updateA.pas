﻿unit updateA;

interface

uses
  Windows, Messages, SysUtils, Classes, Forms, acProgressBar, sLabel, Registry, settings,
  sButton, AbUnzper, AbArcTyp, StdCtrls, Controls, ComCtrls, ServersUtils;

type
  TUpdateForm = class(TForm)
    TitleLabel: TsLabel;
    ProgressBar: TsProgressBar;
    StatusLabel: TsLabel;
    CancelButton: TsButton;
    SizeLabel: TsLabel;
    procedure CancelButtonClick(Sender: TObject);
    procedure Messenger(var Message: TMessage); message $FFE;
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  end;


procedure _Update(Server: TServerData; IsForceUpdate: Boolean);

const
  UpdateDir: string = 'http://www.happyminers.ru/MineCraft/MinecraftDownload/';


var
  UpdateForm: TUpdateForm;
  ClientHash: string;

implementation

uses Main, InternetHTTP, Launch, Auth, Hash;

{$R *.dfm}


var
  ServerName, DownloadingFile: string;
  Server: TServerData;
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

procedure FindFiles(Dir: string; Pattern: string);
var
  SearchRec: TSearchRec;
begin
  if FindFirst(Dir + '*', faDirectory, SearchRec) = 0 then
  begin
    repeat
      if (SearchRec.Name <> '.') and (SearchRec.Name <> '..') then
      begin
        FindFiles(Dir + SearchRec.Name + '\', Pattern);
      end;
    until FindNext(SearchRec) <> 0;
  end;
  FindClose(SearchRec);
  if FindFirst(Dir + Pattern, faAnyFile xor faDirectory, SearchRec) = 0 then
  begin
    repeat
      ClientHash := ClientHash + HashFile(Dir + SearchRec.Name, MD5, MD5_SIZE);
    until FindNext(SearchRec) <> 0;
  end;
  FindClose(SearchRec);
end;

procedure RemoveAll(Path: string);
var
  SearchRec: TSearchRec;
begin
  if FindFirst(Path + '*.*', faAnyFile, SearchRec) = 0 then
  begin
    repeat
      if SearchRec.Attr and faDirectory = 0 then
      begin
        DeleteFile(Path + SearchRec.name);
      end
      else
      begin
        if Pos('.', SearchRec.name) <= 0 then
          RemoveAll(Path + SearchRec.name);
      end;
    until
      FindNext(SearchRec) <> 0;
  end;
  FindClose(SearchRec);
  //RemoveDir(PChar(Path));
end;

function CheckFiles(ServerName :string): Boolean;
var
  ServerHash: string;
begin
  ClientHash := '';
  FindFiles(Settings.MinecraftDir+'mods\', '*.zip');
  FindFiles(Settings.MinecraftDir+'coremods\', '*.jar');
  ClientHash := ClientHash + HashFile(MinecraftDir + 'dists\' + ServerName + '\' + ServerName + '.jar', MD5, MD5_SIZE);
  ServerHash := HTTPGet(UpdateDir + ServerName + '.md5');
  //if ClientHash = ServerHash then
    Result := true
  //else
  //  Result := false;
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
  Result := ((FileExists(MinecraftDir + 'BaseFile')) AND not IsForceUpdate);
end;

function CheckServer(ServerName: string): boolean;
var
  Reg: TRegIniFile;
  Ver: string;
begin
  Reg := TRegIniFile.Create('Software\happyminers.ru');
  Reg.RootKey := HKEY_CURRENT_USER;
  Ver := HTTPGet('http://www.happyminers.ru/MineCraft/MinecraftDownload/'+ServerName+'.ver');
  Result := ((FileExists(MinecraftDir + 'dists\' + ServerName + '\BaseFile')) AND (Reg.ReadInteger('Version', ServerName, -1) = StrToInt(Ver)) AND (checkFiles(ServerName)));
  if not Result then
  begin
    Reg.WriteInteger('Version', ServerName, StrToInt(Ver));
  end;
  Reg.CloseKey;
  Reg.Free;
end;

procedure _Update(Server: TServerData; IsForceUpdate: Boolean);
begin
  with MainForm do
  begin
    LoginBtn.Enabled := false;
    SettingsBtn.Enabled := false;
    SiteBtn.Enabled := false;
    ExitBtn.Enabled := false;
  end;
  UpdateForm.Show;
  updateA.Server := Server;
  ServerName := Server.name;
  NeedDownloadClient := false;
  if not DirectoryExists(MinecraftDir) then
    CreateDir(MinecraftDir);
  if not CheckBase(IsForceUpdate) then
  begin
    RemoveAll(MinecraftDir);
    NeedDownloadClient := true;
    Reg.WriteInteger('Version', ServerName, -1);
    Reg.CloseKey;
    Reg.Free;
    DownloadFile('base.zip');
    Exit;
  end;
  if not CheckServer(ServerName) AND not NeedDownloadClient then
  begin
    DownloadFile(ServerName + '.zip');
    Exit;
  end;
  Launch.PlayMinecraft(Server, Auth.Authdata);
end;


procedure TUpdateForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  ExitProcess(0);
end;

procedure TUpdateForm.Messenger(var Message: TMessage);
begin
  if (Message.wParam = $FFFF) then
  begin
  UnpackFiles(MinecraftDir + DownloadingFile);
    if NeedDownloadClient then
    begin
      NeedDownloadClient := false;
      CheckServer(ServerName);
      DownloadFile(ServerName + '.zip');
    end else
      Launch.PlayMinecraft(Server, Auth.Authdata);
    Exit;
  end;
  DownloadStatus := TDownloadStatus(Pointer(Message.lParam)^);
  StatusLabel.Caption := 'Загрузка... (' + BToMb(Round(DownloadStatus.DownloadSpeed), 0) + ' Мб/сек.)';
  SizeLabel.Caption := BToMb(DownloadStatus.ReceivedBytes, 0) + ' Мб/' + BToMb(DownloadStatus.SizeOfFile, 0) + ' Мб';
  SizeLabel.Left := Round((UpdateForm.Width / 2) - (SizeLabel.Width / 2));
  ProgressBar.Max := DownloadStatus.SizeOfFile;
  ProgressBar.Position := DownloadStatus.ReceivedBytes;
end;

end.
