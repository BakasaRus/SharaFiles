unit Unit2;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, IniFiles, Vcl.WinXCtrls, System.Internal.VarHlpr;

type
  TForm2 = class(TForm)
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    { Private declarations }
  public
    Procedure ReadIni;
    Procedure SaveIni;
  end;

var
  Form2: TForm2;
  Settings: TIniFile;

  IgnoreDateInSettings: TDateTime;
  CurDomain: Integer;
  ThreadsCount: Integer;

  // Тут танцы с бубном нужны, чтобы точно знать, когда инфа считается
  AllowToWriteLog: Boolean;

  F: TFormatSettings;

implementation

Uses Unit1;

{$R *.dfm}

Procedure TForm2.ReadIni;
Var StringDT: String;
Begin
  Settings:=TIniFile.Create(ExtractFilePath(Application.ExeName) + 'Config.ini');
  PathToSave:=Settings.ReadString('Settings', 'PathToSave', ExtractFilePath(Application.ExeName) + 'Files\');
  Form1.ThreadsCountTB.Position:=Settings.ReadInteger('Settings', 'ThreadsCount', 1);
  StringDT:=Settings.ReadString('Settings', 'IgnoreDate', '');
  If StringDT = ''
    Then Form1.IgnoreDatePicker.DateTime:=Now
    Else Form1.IgnoreDatePicker.DateTime:=VarToDateTime(StringDT);
  Form1.IgnoreDTCb.Checked:=Settings.ReadBool('Settings', 'EnableIgnoreDate', True);
  Form1.IgnoreDTCbClick(Application);
  If PathToSave = '' Then PathToSave:=ExtractFilePath(Application.ExeName) + 'Files\';
  Settings.Destroy;
End;

Procedure TForm2.SaveIni;
begin
  Settings:=TIniFile.Create(ExtractFilePath(Application.ExeName) + 'Config.ini');
  Settings.WriteString('Settings', 'PathToSave', PathToSave);
  Settings.WriteInteger('Settings', 'ThreadsCount', Form1.ThreadsCountTB.Position);
  Settings.WriteDateTime('Settings', 'IgnoreDate', Form1.IgnoreDatePicker.DateTime);
  Settings.WriteBool('Settings', 'EnableIgnoreDate', Form1.IgnoreDTCb.Checked);
  Settings.Destroy;
end;

procedure TForm2.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  SaveIni;
end;

procedure TForm2.FormCreate(Sender: TObject);
begin
  GetLocaleFormatSettings(0, F);
  F.ShortDateFormat := 'dd.MM.yyyy';
  F.ShortTimeFormat := 'HH:mm:ss';
  F.DateSeparator := '.';
  F.TimeSeparator := ':';
  ReadIni;
  Form1.IgnoreDTCbClick(Application);
  Form1.Log.Lines.Add('Файлы будут грузиться в папку ' + PathToSave);
end;

end.
