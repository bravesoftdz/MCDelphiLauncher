unit main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.Imaging.pngimage, md5, IdBaseComponent, IdComponent,
  IdTCPConnection, IdTCPClient, Vcl.OleCtrls, SHDocVw, IdHTTP,
  System.Classes, IdIcmpClient, IdRawBase, IdRawClient, wininet, shellapi, system.UITypes;

type
  TForm1 = class(TForm)
    Label1: TLabel;
    Edit2: TEdit;
    Label2: TLabel;
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    CheckBox1: TCheckBox;
    IdHTTP1: TIdHTTP;
    Image1: TImage;
    Memo1: TMemo;
    Edit1: TEdit;
    CheckBox2: TCheckBox;
    Button4: TButton;
    procedure Button2Click(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;
  Login:string;
  password:string;
  Files:Array[1..14] of string;
  FilesFullPatch:Array[1..14] of string;
  RootDir:string;
  appdata:string;
  MinMem, MaxMem:string;
  LaunchParams:string;
  onlineMode:boolean;



implementation

{$R *.dfm}

uses settings, update, enter, IdHashMessageDigest;

function md5(SourceString: string): string;
var
md5: TIdHashMessageDigest5;
begin
// �������� md5-��� ��� ������
Result := '';
md5 := TIdHashMessageDigest5.Create;
try
Result := AnsiLowerCase(md5.HashStringAsHex(SourceString));
finally
FreeAndNil(md5);
end;
end;


function CheckUser(login, password, version:string):boolean;   {�������� ������������}
var
passHash, res:string;
PostData:TStringList;
begin
passHash:= md5(password);
PostData:= TStringList.Create;
PostData.add('user=' + Login);
PostData.add('password=' + PassHash);          {���� ���� - ������������, ������, ������}
PostData.add('version=' + version);
res:=main.Form1.IdHTTP1.Post('http://www.happyminers.ru/MineCraft/auth.php', PostData);   {��������� ������}
if (res = 'Bad login') then       {�������� �� ������}
result:=false
else
begin
LaunchParams:=res;
result:=true;                    {�������� ������}
end;
main.Form1.Memo1.Lines.Text:=res;
main.Form1.Memo1.Lines.Add('http://www.happyminers.ru/MineCraft/auth.php');     {!!!��������� ����!!!}
main.Form1.Memo1.Lines.AddStrings(PostData);
end;

function CheckMd5():boolean;                      {�������� md5}
var
FileMd5, md5Return:string;
resulttmp:boolean;
begin
Try
FileMd5:=(MD5DigestToStr(MD5File(appdata + '\' + RootDir + '\' + files[1])));   {��������� md5 � ������ � fileMd5}
Except
resulttmp:=true;
end;
if resulttmp <> true then
begin
md5Return:=main.Form1.IdHTTP1.Get(UpdateDir + 'md5.php?md5=' + FileMd5);
if md5Return = 'true' then
result:=false
else if (md5Return = 'false') then
result:=true
else
begin
  ShowMessage('��� �������� md5 �������� �������. ��������� ����������� � ���������. ���� �������� �� ������� - ����������e offline mode.');
  result:=false;
end;
end
else
result:=false;
end;

function IsSetFiles():boolean;
var count:integer;
begin
result:=false;
count:=1;
if not (DirectoryExists(appdata + '/' + rootdir)) then          {���� ���� �����}
begin
CreateDir(appdata + '/' + rootdir);                  {������ �����}
end;
  While (count < 15) do
  begin
    if FileExists(FilesFullPatch[count]) then                  {���� ���� ����(1-14)}
      begin
    Count:=count + 1;
      end
    else
      begin;
    result:=true;                                                {true ���� ����� ���}
    Break;
  end;
  end;
end;

function withoutSpecialChars(Login,Password:string):boolean;    {�������� ����������� �������� (����������� �������� � ��)}
var b,i:integer;
result1,result2:boolean;
begin
b:=1;
for i:= 1 to Length(Login) do
case Login[i] of
'a'..'z','A'..'Z': inc(b);
end;
if i = b then result1:=true else result1:=false;

b:=1;
for i:= 1 to Length(Password) do
case Password[i] of
'a'..'z','A'..'Z': inc(b);
end;
if i = b then result2:=true else result2:=false;

if result1 = true AND result2 = true then
result:=true
else
result:=false;
end;

procedure DownloadFiles();            {�������� ������}
begin
update.Form3.ShowModal;                {��� ������� � ����� update}
end;

function IsConnectedToInternet: Boolean;
var
  dwConnectionTypes : DWORD;
begin
  dwConnectionTypes := INTERNET_CONNECTION_MODEM + INTERNET_CONNECTION_LAN + INTERNET_CONNECTION_PROXY;
  Result := InternetGetConnectedState (@dwConnectionTypes, 0);
end;

procedure TForm1.Button1Click(Sender: TObject);         {������ OFFLINE}
begin
if not (edit1.Text = '') then
begin
Login:=Edit1.Text;              {�����}
onlineMode:=false;
enter.login:=login;
form1.Hide;
form4.Show;
end
else
ShowMessage('������� �����');
end;

function CheckJava:boolean;
var
dialog:integer;
begin
  if not ShellExecute(0,'open','java',nil,nil,0) = 42 then begin
   result:=false;
   dialog:= MessageDlg('Java �� �������! �������?',mtError,[mbYes,mbNo], 0);
if dialog = mrYes then ShellExecute(0, 'open', 'http://www.java.com/ru/', nil, nil, SW_SHOW);
  end
  else
  result:=true;
end;

procedure TForm1.Button2Click(Sender: TObject);         {������ ������}
begin
if CheckJava then
begin
Login:=Edit1.Text;              {�����}
Password:=Edit2.Text;           {������}
if (Login <> '') AND (Length(Login) > 4) AND (Password <> '') AND (Length(Password) > 4) AND (Length(Login) < 14) AND (Length(Password) < 14) AND (withoutSpecialChars(Login,Password)) {AND CheckUser(login, password, launcherVer)} then
begin {�������� ������, ����� ������,          ������,              ����� ������,              ����� ������ 2,          ����� ������ 2,                �������� ����������� ��������,       �������� ������������}
if (IsSetFiles()) OR (CheckMd5()) OR (CheckBox1.Checked = true) then     {���� ������ ��� ��� ������ ������ ��� �������� force update}
begin
  DownloadFiles();        {�������� ������}
end;
form1.Hide;                                         {������ ����������� ����}
enter.Form4.ShowModal;
end
else
ShowMessage('������������ ����� ��� ������');        {��� �� ������}
end;
end;

procedure TForm1.Button4Click(Sender: TObject);
begin
ShellExecute(Handle, nil, 'http://www.happyminers.ru', nil, nil, SW_SHOW);
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
if not IsConnectedToInternet then
begin
  ShowMessage('��� ���������� � ����������. ����� ������ � �������� :-).');
  edit2.Enabled:=false;
  button2.Enabled:=false;
end;

end;

end.
