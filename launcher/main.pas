//Delphi launcher by serega6531

unit main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.Imaging.pngimage, md5, IdBaseComponent, IdComponent, Vcl.OleCtrls, IdHTTP, IdIcmpClient,
  System.Classes, IdRawBase, IdRawClient, shellapi, system.UITypes,
  Vcl.Menus, Math, AuthManager, PerimeterUnicode, sSkinManager, sButton,
  sComboBox, sEdit, sLabel, sCheckBox, registry;

type
  TForm1 = class(TForm)
    LogoImg: TImage;
    sSkinManager1: TsSkinManager;
    ExitBtn: TsButton;
    SiteBtn: TsButton;
    ServersDropdownList: TsComboBox;
    LoginEdit: TsEdit;
    PasswordEdit: TsEdit;
    LoginLabel: TsLabel;
    PasswordLabel: TsLabel;
    ServerLabel: TsLabel;
    UpdateCheckbox: TsCheckBox;
    RememberCheckbox: TsCheckBox;
    SettingsBtn: TsButton;
    LoginBtn: TsButton;
    procedure Button4Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure SiteBtnClick(Sender: TObject);
    procedure ExitBtnClick(Sender: TObject);
    procedure SettingsBtnClick(Sender: TObject);
    procedure LoginBtnClick(Sender: TObject);

  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;
  Login:string;
  password:string;
  token:string;
  auth:TAuthManager;
  pingtime:cardinal;
  reg:TRegIniFile;



implementation

{$R *.dfm}

uses settings, update, enter, IdHashMessageDigest, ServerList, ServerData;

function IsConnectedToInternet: Boolean;
begin
  //later
  result := true;
end;

procedure TForm1.SiteBtnClick(Sender: TObject);
begin
  ShellExecute(Handle, nil, 'http://www.happyminers.ru', nil, nil, SW_SHOW);
end;

procedure TForm1.SettingsBtnClick(Sender: TObject);
begin
  Form2.ShowModal;
end;

function CheckJava:boolean;
begin
  //later
  result := true;
end;

procedure closeLauncher; forward;



procedure TForm1.Button3Click(Sender: TObject);
begin
  Form2.ShowModal;
end;

procedure TForm1.Button4Click(Sender: TObject);
begin
  ShellExecute(Handle, nil, 'http://www.happyminers.ru', nil, nil, SW_SHOW);
end;



procedure TForm1.ExitBtnClick(Sender: TObject);
begin
  closeLauncher();
end;

procedure CloseLauncher;
begin
  Auth.Destroy;
  Servers.Destroy;
  reg.Destroy;
  StopPerimeter;
  ExitProcess(0);
end;

procedure initServerList;
var
  i:integer;
begin
  i := 0;
  Form2.initServers();
  servers := settings.servers;
  while i < servers.getServersCount do
  begin
    Form1.ServersDropdownList.Items.Add(servers.getServer(i).getName);
    Inc(i);
  end;
  Form1.ServersDropdownList.ItemIndex := 0;
end;

procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  CloseLauncher();
end;

function _auth(login, password:string):boolean;
begin
  result := auth.isAuth(login, password);
  if result = true then
  begin
    reg.WriteString('Auth','Login',login);
    reg.WriteString('Auth','Password',password);
  end;
end;

function needUpdate():boolean;
var
  _http:TIdHTTP;
begin
  _http := TidHTTP.Create(nil);
  if _http.Get('http://www.happyminers.ru/MineCraft/launcherver.php') = settings.LauncherVer then result := false else result := true;
end;

procedure TForm1.FormCreate(Sender: TObject);
var
  PerimeterInputData: TPerimeterInputData;
begin
  PerimeterInputData.ResistanceType := 0;
  PerimeterInputData.CheckingsType := 700;
  PerimeterInputData.ExternalType := 2;
  PerimeterInputData.MainFormHandle := Form1.Handle;
  PerimeterInputData.Interval := 20;
  PerimeterInputData.ExtProcOnEliminating := @closeLauncher;
  //InitPerimeter(PerimeterInputData);      //Will activate later
  if not IsConnectedToInternet then
  begin
    ShowMessage('��� ���������� � ����������.');
    Application.Terminate;
  end;
  auth := TAuthManager.Create();
  initServerList();
  Reg := TRegIniFile.Create('Software\happyminers');
  if (reg.ReadString('Auth', 'Login', 'def') <> 'def') AND (reg.ReadString('Auth', 'Password', 'def') <> 'def') then
  begin
    if MessageDlg('���������� ������ ������� �����������? ������������ ��?', mtConfirmation, [mbYes, mbNo], 0) = mrYes then
    begin
      self.LoginEdit.Text := reg.ReadString('Auth', 'Login', 'def');
      self.PasswordEdit.Text := reg.ReadString('Auth', 'Password', 'def');
    end else begin
      reg.WriteString('Auth', 'Login', 'def'); reg.WriteString('Auth', 'Password', 'def');
    end;
  end;
  if needUpdate() then
  begin
    MessageDlg('���������� �������� �������!', mtError, [mbOk], 0);
    ShellExecute(Handle, nil, 'http://www.happyminers.ru/?mode=start', nil, nil, SW_SHOW);
    closeLauncher();
  end;
end;

procedure TForm1.LoginBtnClick(Sender: TObject);
begin
  if CheckJava then
  begin
    Login := LoginEdit.Text;              {�����}
    Password := PasswordEdit.Text;           {������}
    if (Length(Login) in [4..14]) AND (Length(Password) in [4..14]) AND _auth(login, password) then   //DISABLE AUTH FOR DEBUG
    begin {�������� ������, ����� ������,   ����� ������,                    �������� ������������}
      Form3.processUpdate((UpdateCheckbox.Checked = true), settings.servers.getServerByName(serversDropdownList.Items[serversDropdownList.ItemIndex]));        {�������� ������}
    end else
      //ShowMessage('������������ ����� ��� ������');
      MessageDlg('������������ ����� ��� ������',mtError, [mbOK], 0);
  end;
end;

end.
