unit settings;

interface

uses
  Windows, SysUtils, Forms,
  sSkinProvider, StdCtrls, sLabel, sEdit, sButton, Registry, ServersUtils, SHFolder,
  Controls, Classes, InternetHTTP, JSON;

type
  TSettingsForm = class(TForm)
    TitleLabel: TsLabel;
    SkinProvider: TsSkinProvider;
    MemoryEdit: TsEdit;
    MemoryLabel: TsLabel;
    SaveButton: TsButton;
    CancelButton: TsButton;
    VersionLabel: TsLabel;
    procedure CancelButtonClick(Sender: TObject);
    procedure SaveButtonClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  end;

procedure InitServers;
procedure CheckFolder(Dir: string; Pattern: string);

const
  LauncherVer: string = '1';
  RootDir: string = '.happyminers';

var
  SettingsForm: TSettingsForm;
  Reg: TRegIniFile;
  MinecraftDir: string;
  GameMemory: string;
  AppData: string;
  tCP:string;

implementation

{$R *.dfm}

procedure TSettingsForm.CancelButtonClick(Sender: TObject);
begin
  Self.Close;
end;

procedure CheckFolder(Dir: string; Pattern: string);
var
  SearchRec: TSearchRec;
begin
  if FindFirst(Dir + '*', faDirectory, SearchRec) = 0 then
  begin
    repeat
      if (SearchRec.Name <> '.') and (SearchRec.Name <> '..') then
      begin
        CheckFolder(Dir + SearchRec.Name + '\', Pattern);
      end;
    until FindNext(SearchRec) <> 0;
  end;
  FindClose(SearchRec);
  if FindFirst(Dir + Pattern, faAnyFile xor faDirectory, SearchRec) = 0 then
  begin
    repeat
     tCP := tCP + Dir + SearchRec.Name + ';';
    until FindNext(SearchRec) <> 0;
  end;
  FindClose(SearchRec);
end;

function GetSpecialFolderPath(folder : integer) : string;    {������� ��������� ����}
const
  SHGFP_TYPE_CURRENT = 0;
var
  Path: array [0..MAX_PATH] of char;
begin
  if SUCCEEDED(SHGetFolderPath(0,folder,0,SHGFP_TYPE_CURRENT,@Path[0])) then
    Result := Path
  else
    Raise Exception.Create('Can''t find AppData dir');
end;

procedure TSettingsForm.FormCreate(Sender: TObject);
begin
  Reg := TRegIniFile.Create('Software\happyminers.ru');
  VersionLabel.Caption := '������ ��������: ' + LauncherVer;
  AppData := GetSpecialFolderPath(CSIDL_APPDATA);
  MinecraftDir := AppData + '\' + RootDir + '\';
  GameMemory := IntToStr(Reg.ReadInteger('Settings', 'Memory', 512));
  MemoryEdit.Text := GameMemory;
end;

procedure InitServers;
var
  Size: LongWord;
  Data: pointer;
  Response, CountResponse: string;
  I: Integer;
  server: TServerData;
  count: integer;
const
  countNames: string = 'abcdefgh';
begin
  {ServersUtils.AddServer('Classic', 'localhost');
  ServersUtils.AddServer('Another Server', '127.0.0.1');}
  Size := 0;
  AddPOSTField(Data, Size, 'count', '1');
  CountResponse := HTTPPost('http://www.happyminers.ru/go/servers', Data, Size);
  count := getJsonInt('count', CountResponse);
  if count > 0 then
  begin
    for I := 1 to count do
    begin
      Size := 0;
      AddPOSTField(Data, Size, 'server', IntToStr(getJsonInt(countNames[i], CountResponse)));
      Response := HTTPPost('http://www.happyminers.ru/go/servers', Data, Size);
      with server do
      begin
        id := getJsonInt('id', Response);
        name := getJsonStr('name', Response);
        adress := getJsonStr('adress', Response);
        status := getJsonBool('status', Response);
        players := getJsonInt('players', Response);
        slots := getJsonInt('slots', Response);
      end;
      ServersUtils.AddServer(server);
    end;
  end else begin
    MessageBox(Application.Handle, '��� ��������!', '��� ��������!', Error);
  end;

end;

procedure TSettingsForm.SaveButtonClick(Sender: TObject);
begin
  Reg.WriteInteger('Settings', 'Memory', StrToInt(MemoryEdit.Text));
  Reg.CloseKey;
  Self.Close;
end;

end.
