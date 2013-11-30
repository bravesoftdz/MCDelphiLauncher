﻿unit settings;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, main, SHFolder, ServerList, ServerData,
  sSkinProvider, sEdit, sLabel, sButton, Registry;

type
  TForm2 = class(TForm)
    sSkinProvider1: TsSkinProvider;
    sEdit1: TsEdit;
    sEdit2: TsEdit;
    VersionLabel: TsLabel;
    XmsLabel: TsLabel;
    XmxLabel: TsLabel;
    SaveBtn: TsButton;
    BackBtn: TsButton;
    procedure initServers();
    procedure FormCreate(Sender: TObject);
    procedure SaveBtnClick(Sender: TObject);
    procedure BackBtnClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

const
  LauncherVer:string = '1';
  RootDir:string = '.happyminers';

var
  Form2: TForm2;
  MinMem, MaxMem:string;
  appdata:string;
  MinecraftDir:string;
  servers:TServerList;
  reg:TRegIniFile;

implementation

{$R *.dfm}

function GetSpecialFolderPath(folder : integer) : string;    {Полуаем системные пути}
const
  SHGFP_TYPE_CURRENT = 0;
var
  path: array [0..MAX_PATH] of char;
begin
  if SUCCEEDED(SHGetFolderPath(0,folder,0,SHGFP_TYPE_CURRENT,@path[0])) then
    Result := path
  else
    Raise Exception.Create('Can''t find AppData dir');
end;

procedure TForm2.BackBtnClick(Sender: TObject);
begin
  Form2.Close;
end;

procedure TForm2.FormCreate(Sender: TObject);
begin
  VersionLabel.Caption:='Версия лаунчера: '+ LauncherVer;   {вывод версии}
  appdata:=GetSpecialFolderPath(CSIDL_APPDATA);      {получаем appdata/roaming}
  MinecraftDir:=appdata + '\' + RootDir + '\';
  Reg := TRegIniFile.Create('Software\happyminers');
  if (reg.ReadInteger('Settings', 'MinMem', -1) = -1) OR (reg.ReadInteger('Settings', 'MaxMem', -1) = -1) Then
  begin
    reg.WriteInteger('Settings', 'MinMem', 256);
    MinMem := '256';
    sEdit1.Text := MinMem;
    MaxMem := '512';
    sEdit2.Text := MaxMem;
    reg.WriteInteger('Settings', 'MaxMem', 512);
  end else begin
    MinMem := IntToStr(reg.ReadInteger('Settings', 'MinMem', -1));
    sEdit1.Text := MinMem;
    MaxMem := IntToStr(reg.ReadInteger('Settings', 'MaxMem', -1));
    sEdit2.Text := MaxMem;
  end;
end;

procedure TForm2.initServers();
begin
  servers:=TServerList.Create;
  servers.addServer(TServerData.Create('Classic', '127.0.0.1'), 0);
  //servers.addServer(TServerData.Create('Test Server 2', '127.0.0.2'), 1);
end;

procedure TForm2.SaveBtnClick(Sender: TObject);
begin
    if (StrToInt(sEdit1.Text) >= 126) AND (StrToInt(sEdit2.Text) >= StrToInt(sEdit1.text)) then       {проверка правильности данных}
  begin
    reg.WriteInteger('Settings', 'MinMem', StrToInt(sEdit1.Text));
    reg.WriteInteger('Settings', 'MinMem', StrToInt(sEdit2.Text));
    self.Close;
  end else
    ShowMessage('Ошибка! Проверьте правильность введённых данных');
end;

end.
