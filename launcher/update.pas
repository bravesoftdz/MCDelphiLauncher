unit update;

interface

uses
  Winapi.Windows, System.SysUtils,
   Vcl.Forms, Vcl.StdCtrls,
 Vcl.Imaging.pngimage,  main, ComCtrls, Vcl.Controls, System.Classes, settings,
  IdComponent, IdTCPConnection, IdTCPClient, IdHTTP, IdBaseComponent,
  IdAntiFreezeBase, Vcl.IdAntiFreeze;

type
  TForm3 = class(TForm)
    Label1: TLabel;
    Label2: TLabel;
    ProgressBar1: TProgressBar;
    IdAntiFreeze1: TIdAntiFreeze;
    IdHTTP1: TIdHTTP;
    procedure FormActivate(Sender: TObject);
    procedure IdHttp1work(ASender: TObject; AWorkMode: TWorkMode;
  AWorkCount: Int64);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form3: TForm3;
  DoOnce:boolean = false;
  FileSize:integer;

const
    updateDir:string = 'http://happyminers.ru/MineCraft/MinecraftDownload/';        {����� ��� ���������� �� �������}

implementation

{$R *.dfm}

uses enter, FWZipReader;

function GetInetFileSize(const FileUrl:string): integer;         {��������� ������� �����}
var
  idHTTP: TidHTTP;
begin
  Result:=0;
  idHTTP:=TIdHTTP.Create(nil);
  idHTTP.Head(FileUrl);
  Result:=idHTTP.Response.ContentLength;
  IdHTTP.Free;
end;

function BToMb(bytes:integer):real;
begin
  result:=bytes/(1024*1024);
end;

procedure UnpackArchive(arpath, expath:string);
var
DataStream:TMemoryStream;
FZIPStream:TStream;
Read: TFWZipReader;
i:integer;
begin
DataStream:=TMemoryStream.Create;
DataStream.LoadFromFile(arpath);
DataStream.Read(i,SizeOf(i));
Read := TFWZipReader.Create;
Read.LoadFromStream(DataStream);
Read.ExtractAll(expath);
end;

procedure TForm3.FormActivate(Sender: TObject);
var
HTTP:TIdHTTP;
LoadStream: TMemoryStream;
begin
if DoOnce = false then
begin
form3.ProgressBar1.Position:=0;
HTTP:=TIdHTTP.Create(nil);
HTTP.OnWork:=IdHTTP1Work;
FileSize:=GetInetFileSize(UpdateDir + 'minecraft.zip');
form3.ProgressBar1.max:=FileSize;//������ �����
Label2.Caption:='��������... (0/' + IntToStr(FileSize) + ' ���� (~' + FloatToStr(Round(BToMb(FileSize))) + ' ��))';
 LoadStream := TMemoryStream.Create;
  HTTP.Get(updateDir + 'minecraft.zip', LoadStream);     {�������� �����}
  LoadStream.SaveToFile(appdata + '/' + rootdir + '/minecraft.zip');
LoadStream.Free;      {����������� �����}
HTTP.Free;
UnpackArchive(appdata + '/' + rootdir + '/minecraft.zip', appdata + '/' + rootdir);    {������������� ��������� ����� � �������� �����}
DeleteFile(appdata + '/' + rootdir + '/minecraft.zip');    {������� ������������ �����}
Form1.Hide;
Form3.Hide;
form4.Show;
DoOnce:=true;
end;
end;

procedure TForm3.IdHTTP1Work(ASender: TObject; AWorkMode: TWorkMode;
  AWorkCount: Int64);
begin
form3.ProgressBar1.Position:=AWorkCount;//���������� ��������� �� ������ ������
Label2.Caption:='��������... (' + IntToStr(AWorkCount) + '/' + IntToStr(FileSize) + ' ���� (~' + FloatToStr(Round(BToMb(FileSize))) + ' ��))';
end;

end.
