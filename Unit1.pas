unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.StdCtrls,
  Vcl.Imaging.pngimage, System.Actions, Vcl.ActnList, Vcl.Touch.GestureMgr,
  Vcl.WinXCtrls, Vcl.CategoryButtons, Vcl.Buttons, System.ImageList, Vcl.ImgList,
  IdBaseComponent, IdComponent, IdTCPConnection, IdTCPClient, IdHTTP,
  Vcl.ComCtrls, FileCtrl, SharaUtils, SynaCode, SynaUtil, System.Threading, SyncObjs,
  System.Win.TaskbarCore, Vcl.Taskbar, System.Notification, ShellApi,
  IdIOHandler, IdIOHandlerSocket, IdIOHandlerStack;

type
  TForm1 = class(TForm)
    AppBar: TPanel;
    CloseButton: TImage;
    ActionList1: TActionList;
    Action1: TAction;
    GestureManager1: TGestureManager;
    Log: TMemo;
    SettingsSplit: TSplitView;
    CategoryButtons1: TCategoryButtons;
    AdsPanel: TPanel;
    SplitOpenClose: TImage;
    MainPanel: TPanel;
    ImageList1: TImageList;
    Label1: TLabel;
    Label2: TLabel;
    ProgramServer: TIdHTTP;
    ThreadsCountTB: TTrackBar;
    ThreadsCountLabel: TLabel;
    IgnoreDatePicker: TDateTimePicker;
    CheckedFilesLabel: TLabel;
    SettingsPanel: TPanel;
    DownloadedCountLabel: TLabel;
    ElapsedTimeLabel: TLabel;
    FilesCountLabel: TLabel;
    CurrentCountEdit: TEdit;
    DownloadedCountEdit: TEdit;
    ElapsedTimeEdit: TEdit;
    IgnoreDTCb: TCheckBox;
    NotificationCenter1: TNotificationCenter;
    Taskbar1: TTaskbar;
    procedure CloseButtonClick(Sender: TObject);
    procedure Action1Execute(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormGesture(Sender: TObject; const EventInfo: TGestureEventInfo;
      var Handled: Boolean);
    procedure SplitOpenCloseClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure StartWorkButtonClick(Sender: TObject);
    procedure ThreadsCountTBChange(Sender: TObject);
    procedure StopWorkButtonClick(Sender: TObject);
    procedure CategoryButtons1Categories0Items0Click(Sender: TObject);
    procedure CategoryButtons1Categories0Items2Click(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure SettingsSplitOpened(Sender: TObject);
    procedure SettingsSplitClosing(Sender: TObject);
    Procedure AddToDebug(S: String);
    Procedure MyHandleException(Sender: TObject; E: Exception);
    procedure FormDestroy(Sender: TObject);
    procedure IgnoreDTCbClick(Sender: TObject);
    Function GetAdsCaption: String;
    procedure AdsPanelClick(Sender: TObject);
    Procedure SendNotification(Title, Body: String);
    Procedure _SendNotif;
    procedure Label1Click(Sender: TObject);
    procedure Label2Click(Sender: TObject);
    Function ShowMsgBox(Caption, Msg: String; Flags: Integer): Integer;
    Procedure OpenURL(URL: String);
    procedure CategoryButtons1Categories0Items3Click(Sender: TObject);
    procedure CategoryButtons1Click(Sender: TObject);
  private
    { Private declarations }
    procedure AppBarResize;
    procedure AppBarShow(mode: integer);
  public
    { Public declarations }
  end;

  TResThread = Class (TThread)
  Public

  Private

  Protected
    Procedure Execute; Override;
    Procedure SetResParams(Code: Integer = 0);
    Procedure ParseResFile;
  End;

  TDownloadTask = Class
    Procedure Execute;
    Procedure WriteDownloadStatus;
    Function DownloadFile: Integer;
    Function GetNonExistingFileName: String;
    Procedure WorkWithForm;
    Constructor Create;
    Destructor Destroy;
    Var HTTP: TIdHTTP;
        FileName, FileLink, FullPath,
        LastExistingVersion, StatusMessage: String;
        Status, StartFrom, ThreadID: Integer;
        Task: ITask;
  End;

  ITaskArray = Array Of ITask;

  TDownloadControlThread = Class (TThread)
  Public
    Procedure SuspendDownload;
    Procedure AbortDownload;
    Procedure ResumeDownload;
    Function IsFinished: Boolean;
    Function GetTasks: ITaskArray;
    Function BeginningOfTheWork: Boolean;
    Procedure EndingOfTheWork;
    Var ThreadsCount: Integer;
        IgnoreDate: TDateTime;
        WorkTasks: Array Of TDownloadTask;
        DownloadLog: TStringList;
        StartTime: TDateTime;
  Private

  Protected
    Procedure Execute; Override;
  End;

Const
  ProgramSite = 'https://bakasarus.github.io/sharafiles';
  ErrorWhileDownloading = -1;
  OlderThanIgnoreDate = 0;
  Downloaded = 1;
  AlreadyExists = 2;
  NotFound = 404;
  ShowMsgInfo = MB_ICONINFORMATION + MB_OK + MB_DEFBUTTON1;
  ShowMsgAsk = MB_ICONQUESTION + MB_YESNO + MB_DEFBUTTON1;
  ShowMsgWarn = MB_ICONWARNING + MB_OK + MB_DEFBUTTON1;
  ShowMsgError = MB_ICONERROR + MB_OK + MB_DEFBUTTON1;

var
  Form1: TForm1;
  PathToSave: String;
  CurrentRes: String = 'Resources.txt';
  ResSWF: String = 'http://sharaball.ru/fs/3p897j5lf4e0j.swf';
  ResLink: String;
  LinksPrefix: String = 'http://sharaball.ru/fs/';
  Links: Array Of String;
  LinksCount: Integer;
  CurrentCount: Integer = 0;
  DownloadedCount: Integer = 0;
  ResThread: TResThread;
  ControlThread: TDownloadControlThread;
  IsLimited: Boolean;
  DebugCritSect: TCriticalSection;
  MyNotification: TNotification;
  FormatSettings: TFormatSettings;


implementation

Uses Unit2;

{$R *.dfm}

const
  AppBarHeight = 75;

Function TForm1.ShowMsgBox(Caption, Msg: String; Flags: Integer): Integer;
Begin
  Result:=Application.MessageBox(PWideChar(Msg), PWideChar(Caption), Flags);
End;

function GetMyVersion:string;
type
  TVerInfo=packed record
    Nevazhno: array[0..47] of byte; // ненужные нам 48 байт
    Minor,Major,Build,Release: word; // а тут версия
  end;
var
  s:TResourceStream;
  v:TVerInfo;
begin
  result:='';
  try
    s:=TResourceStream.Create(HInstance,'#1',RT_VERSION); // достаём ресурс
    if s.Size>0 then begin
      s.Read(v,SizeOf(v)); // читаем нужные нам байты
      result:=Format('%d.%d.%d.%d', [v.Major, v.Minor, v.Release, v.Build]);
    end;
  s.Free;
  except; end;
end;

Procedure TForm1.OpenURL(URL: string);
begin
  ShellExecute(0, 'open', PWideChar(URL), nil, nil, SW_SHOW);
end;

procedure TForm1.AppBarResize;
begin
  AppBar.SetBounds(0, AppBar.Parent.Height - AppBarHeight,
    AppBar.Parent.Width, AppBarHeight);
end;

procedure TForm1.AppBarShow(mode: integer);
begin
  if mode = -1 then // Toggle
    mode := integer(not AppBar.Visible );

  if mode = 0 then
    AppBar.Visible := False
  else
  begin
    AppBar.Visible := True;
    AppBar.BringToFront;
  end;
end;

procedure TForm1.Action1Execute(Sender: TObject);
begin
  AppBarShow(-1);
end;

procedure TForm1.CategoryButtons1Categories0Items0Click(Sender: TObject);
begin
  If SelectDirectory('Выбери путь для загрузки', '', PathToSave)
    Then Log.Lines.Add('Выбранный путь для загрузки: ' + PathToSave);
end;

procedure TForm1.CategoryButtons1Categories0Items2Click(Sender: TObject);
begin
  Log.Clear;
end;

procedure TForm1.CategoryButtons1Categories0Items3Click(Sender: TObject);
begin
  OpenURL(ProgramSite + '#faq');
end;

procedure TForm1.CategoryButtons1Click(Sender: TObject);
begin
  CategoryButtons1.SelectedItem:=CategoryButtons1.Categories[0].Items[0];
end;

procedure TForm1.CloseButtonClick(Sender: TObject);
begin
  Application.Terminate;
end;

Procedure TForm1.AddToDebug(S: string);
begin
  DebugCritSect.Enter;
  AssignFile(ErrOutput, 'Debug.txt');
  Try
    Append(ErrOutput);
  Except
    Rewrite(ErrOutput);
  End;
  Writeln(ErrOutput, '[', DateTimeToStr(Now), '] ', S);
  CloseFile(ErrOutput);
  DebugCritSect.Leave;
end;

procedure TForm1.AdsPanelClick(Sender: TObject);
begin
  AdsPanel.Caption:=GetAdsCaption;
end;

Procedure TResThread.SetResParams(Code: Integer = 0);
Begin
  Case Code of
    0: Begin
         CurrentRes:='Resources.txt';
         ResSWF:='http://sharaball.ru/fs/3p897j5lf4e0j.swf';
         LinksPrefix:='http://sharaball.ru/fs/';
       End;
    1: Begin
         CurrentRes:='ResourcesRPL.txt';
         ResSWF:='http://www.rolypolyland.com/game/fs/l26zj34ilx22.swf?1';
         LinksPrefix:='http://www.rolypolyland.com/game/fs/';
       End;
  end;
End;

Procedure TResThread.ParseResFile;
Var CurStr: String;
    LinksList: TStringList;
Begin
   AssignFile(Input, CurrentRes);
  Reset(Input);
  Links:=Nil;
  LinksCount:=0;
  LinksList:=TStringList.Create;
  Repeat
    Readln(CurStr);
  Until (CurStr = 'var mr = {};');
  While (CurStr <> 'var tr = {};') Do
    Begin
      Readln(CurStr);
      If (CurStr = 'var tr = {};') Then Break;
      Inc(LinksCount);
      SetLength(Links, LinksCount);
      Delete(CurStr, 1, Pos('"', CurStr));
      Links[LinksCount - 1]:=Copy(CurStr, 1, Pos('"', CurStr) - 1);
      LinksList.Add(Links[LinksCount - 1]);
    End;
  //Form1.Log.Lines.Text:=LinksList.Text;
  LinksList.Destroy;
  Close(Input);
End;

//Проверяем наличие нового ресурсника, качаем и парсим его
Procedure TResThread.Execute;
begin
  Form1.AddToDebug('Настроили программу для получения ресурсного файла');
  if not FileExists(CurrentRes)
    Then Begin
      Form1.Log.Lines.Add('Ресурсный файл отсутствует. Создайте его сами по инструкции на сайте');
      Exit;
    End;
  ParseResFile;
  Form1.AddToDebug('Парсим ' + CurrentRes);
  Form1.FilesCountLabel.Caption:='из ' + IntToStr(LinksCount);
end;

procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Form2.FormClose(Sender, Action);
end;

Procedure TForm1.MyHandleException(Sender: TObject; E: Exception);
begin
  AddToDebug('Ошибка! ' + E.ClassName + ': ' + E.Message);
end;

Function TForm1.GetAdsCaption: String;
begin
  Case Random(8) Of
    0: Result:='Кликни по шестерёнке, чтобы открыть панель действий и настроек';
    1: Result:='Теперь файлы скачиваются БЕЗ создания папки FS, нужно учитывать это';
    2: Result:='Ошибка в программе? Сообщи об этом автору, и он обязательно исправит её';
    3: Result:='Если количество потоков равно нулю, то ничего скачиваться не будет';
    4: Result:='Воврмя продлевай срок действия лицензии, чтобы не потерять доступ к свежим файлам';
    5: Result:='Чтобы посмотреть другие советы, просто кликни по надписи';
    6: Result:='Есть вопросы? Загляни на сайт. Там нет ответа? Напиши автору, и он ответит';
    7: Result:='Не нарушай правила пользования, иначе твоя учётная запись будет деактивирована';
  end;
end;

procedure TForm1.FormCreate(Sender: TObject);
Var LocalVersion: String;
Begin
  Application.OnException:=MyHandleException;
  DebugCritSect:=TCriticalSection.Create;
  Log.Lines.Add('Приветствую, хозяин!');
  LocalVersion:=GetMyVersion;
  Label1.Caption:='ШараФайлы ' + LocalVersion;
  ResThread:=TResThread.Create;
  ResThread.Priority:=tpLowest;
  ResThread.FreeOnTerminate:=True;
  AdsPanel.Caption:=GetAdsCaption;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  DebugCritSect.Destroy;
end;

procedure TForm1.FormGesture(Sender: TObject;
  const EventInfo: TGestureEventInfo; var Handled: Boolean);
begin
  AppBarShow(0);
end;

procedure TForm1.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Key = VK_ESCAPE then
    AppBarShow(-1)
  else
    AppBarShow(0);
end;

procedure TForm1.FormResize(Sender: TObject);
begin
  AppBarResize;
end;

procedure TForm1.IgnoreDTCbClick(Sender: TObject);
begin
  IgnoreDatePicker.Visible:=IgnoreDTCb.Checked;
end;

procedure TForm1.Label1Click(Sender: TObject);
begin
  OpenURL(ProgramSite);
end;

procedure TForm1.Label2Click(Sender: TObject);
begin
  OpenURL('http://vk.com/id73991663');
end;

procedure TForm1.SettingsSplitClosing(Sender: TObject);
begin
  SettingsPanel.Visible:=False;
end;

procedure TForm1.SettingsSplitOpened(Sender: TObject);
begin
  SettingsPanel.Visible:=True;
end;

procedure TForm1.SplitOpenCloseClick(Sender: TObject);
begin
  If SettingsSplit.Opened
    Then SettingsSplit.Close
    Else SettingsSplit.Open;
end;

Function TDownloadTask.DownloadFile: Integer;
Var ServerDate, LocalDate: TDateTime;
    FileStream: TMemoryStream;
Begin
  Result:=ErrorWhileDownloading;
  Try
    HTTP.Head(FileLink);
  Except
    If (HTTP.ResponseCode <> 200)
      Then Begin
        Result:=HTTP.ResponseCode;
        Exit;
      End;
  End;
  ServerDate:=HTTP.Response.LastModified;
  If ServerDate >= ControlThread.IgnoreDate
  Then Begin
      FileStream:=TMemoryStream.Create;
      Try
        FileAge(LastExistingVersion, LocalDate);
        If ServerDate <= LocalDate
          Then Begin
            Result:=AlreadyExists;
            Exit;
          End;
        HTTP.Get(FileLink, FileStream);
        FileStream.SaveToFile(FullPath);
        FileSetDate(FullPath, DateTimeToFileDate(ServerDate));
        Result:=Downloaded;
      Finally
        If (FileStream <> Nil) Then FileStream.Destroy;
      End;
    End
  Else Result:=OlderThanIgnoreDate;
End;

Function TDownloadTask.GetNonExistingFileName;
Var Counter: Integer;
    OriginalFileName: String;
Begin
  Counter:=0;
  Result:=PathToSave + '\' + FileName;
  OriginalFileName:=Result;
  LastExistingVersion:='';
  If FileExists(Result) = True Then
    Repeat
      LastExistingVersion:=Result;
      Result:=OriginalFileName;
      Inc(Counter);
      Insert('['+IntToStr(Counter)+']', Result, Length(Result) - 3);
    Until FileExists(Result) = False;
End;

Procedure TDownloadTask.WriteDownloadStatus;
Begin
  Case Status of
    ErrorWhileDownloading: StatusMessage:=FileName + ': произошла критическая ошибка при скачивании';
    OlderThanIgnoreDate: StatusMessage:=FileName + ': последняя версия файла старее установленной даты';
    Downloaded: StatusMessage:=FileName + ': успешно скачан';
    AlreadyExists: StatusMessage:=FileName + ': уже существует';
    NotFound: StatusMessage:=FileName + ': файл отсутствует';
    Else StatusMessage:=FileName + ': неизвестная ошибка, код ' + IntToStr(Status);
  End;
  TThread.Synchronize(Nil, WorkWithForm);
End;

Procedure TDownloadTask.WorkWithForm;
begin
  If Status = Downloaded
    Then Begin
      Inc(DownloadedCount);
      Form1.DownloadedCountEdit.Text:=IntToStr(DownloadedCount);
      Form1.Log.Lines.Add(FileName);
    End;
  Form1.ElapsedTimeEdit.Text:=FormatDateTime('nn:ss', Now - ControlThread.StartTime);
  ControlThread.DownloadLog.Add(StatusMessage);
  Inc(CurrentCount);
  Form1.Taskbar1.ProgressValue:=CurrentCount;
  Form1.CurrentCountEdit.Text:=IntToStr(CurrentCount);
  Application.ProcessMessages;
end;

Procedure TDownloadTask.Execute;
Var CurLink: Integer;
    TotalLinks: Integer;
begin
  Form1.AddToDebug('Запустили рабочий поток ' + IntToStr(ThreadID));
  HTTP.Request.UserAgent:=Form1.ProgramServer.Request.UserAgent;
  CurLink:=StartFrom;
  TotalLinks:=LinksCount;
  While CurLink < TotalLinks Do
    Begin
      If Task.Status = TTaskStatus.Canceled
        Then Break;
      FileName:=Links[CurLink];
      FileLink:=LinksPrefix + FileName;
      FullPath:=GetNonExistingFileName;
      Status:=DownloadFile;
      WriteDownloadStatus;
      Inc(CurLink, ControlThread.ThreadsCount);
    End;
  If Task.Status = TTaskStatus.Canceled
    Then Form1.AddToDebug('Принудительно завершили рабочий поток ' + IntToStr(ThreadID))
    Else Form1.AddToDebug('Завершили рабочий поток ' + IntToStr(ThreadID));
end;

Constructor TDownloadTask.Create;
begin
  Task:=TTask.Create(Execute);
  HTTP:=TIdHTTP.Create(Application);
  inherited;
end;

Destructor TDownloadTask.Destroy;
begin
  HTTP.Destroy;
  inherited;
end;

Procedure TForm1._SendNotif;
Begin
  Form1.NotificationCenter1.PresentNotification(MyNotification);
End;

Procedure TForm1.SendNotification(Title: string; Body: string);
begin
  MyNotification:=NotificationCenter1.CreateNotification;
  MyNotification.Title:=Title;
  MyNotification.AlertBody:=Body;
  TThread.Synchronize(Nil, _SendNotif);
  MyNotification.Free;
end;

Function TDownloadControlThread.BeginningOfTheWork: Boolean;
begin
  Result:=True;
  DownloadLog:=TStringList.Create;
  CurrentCount:=0;
  DownloadedCount:=0;
  StartTime:=Now;
  Form1.Taskbar1.ProgressMaxValue:=LinksCount;
  If Form1.IgnoreDTCb.Checked
    Then IgnoreDate:=Form1.IgnoreDatePicker.DateTime
    Else IgnoreDate:=VarToDateTime('01.01.1900 00:00:00');
  ThreadsCount:=Form1.ThreadsCountTB.Position;
  DownloadLog.Add('Начали ведение лога в ' + DateTimeToStr(Now));
  Form1.Log.Lines.Add('Начали скачивать файлы');
  Form1.Log.Lines.Add('Список скачанных файлов:');
end;

Procedure TDownloadControlThread.EndingOfTheWork;
Var I: Integer;
begin
  For I:=0 To ThreadsCount - 1 Do
    WorkTasks[I].Destroy;
  If DownloadedCount = 0
    Then Form1.Log.Lines.Add('Скачанных файлов нет');
  Form1.Taskbar1.ProgressValue:=0;
  Form1.SendNotification('ШараФайлы', 'Файлы скачаны');
  Form1.Log.Lines.Add('Готово!');
  DownloadLog.Add('Закончили ведение лога в ' + DateTimeToStr(Now));
  DownloadLog.SaveToFile(ExtractFilePath(Application.ExeName) + 'Log.txt');
  DownloadLog.Destroy;
end;

Procedure TDownloadControlThread.Execute;
Var I: Integer;
begin
  If BeginningOfTheWork
    Then Begin
      Form1.AddToDebug('Запустили управляющий поток');
      SetLength(WorkTasks, ThreadsCount);
      For I:=0 To ThreadsCount - 1 Do
        Begin
          WorkTasks[I]:=TDownloadTask.Create;
          WorkTasks[I].StartFrom:=I;
          WorkTasks[I].ThreadID:=I + 1;
          WorkTasks[I].Task.Start;
        End;
      TTask.WaitForAll(GetTasks);
    End;
  EndingOfTheWork;
end;

Procedure TDownloadControlThread.SuspendDownload;
Var I: Integer;
begin
  For I:=0 To High(WorkTasks) Do
    WorkTasks[I].Task.Wait;
end;

Procedure TDownloadControlThread.ResumeDownload;
Var I: Integer;
begin
  For I:=0 To High(WorkTasks) Do
    WorkTasks[I].Task.Start;
end;

Procedure TDownloadControlThread.AbortDownload;
Var I: Integer;
begin
  if Self = Nil then
    Exit;
  For I:=0 To High(WorkTasks) Do
    WorkTasks[I].Task.Cancel;
  EndingOfTheWork;
end;

Function TDownloadControlThread.IsFinished: Boolean;
Var I: Integer;
    IsCompleted: Boolean;
begin
  Result:=True;
  For I:=0 To High(WorkTasks) Do
    Begin
      IsCompleted:=(WorkTasks[I].Task.Status = TTaskStatus.Completed);
      Result:=Result And IsCompleted;
    End;
end;

Function TDownloadControlThread.GetTasks: ITaskArray;
Var I: Integer;
Begin
  SetLength(Result, Length(WorkTasks));
  For I:=0 To High(WorkTasks) Do
    Result[I]:=WorkTasks[I].Task;
End;

procedure TForm1.StartWorkButtonClick(Sender: TObject);
begin
  System.SysUtils.ForceDirectories(PathToSave);
  ControlThread:=TDownloadControlThread.Create;
  ControlThread.Priority:=tpLowest;
  ControlThread.FreeOnTerminate:=True;
end;

procedure TForm1.StopWorkButtonClick(Sender: TObject);
begin
  ControlThread.AbortDownload;
end;

procedure TForm1.ThreadsCountTBChange(Sender: TObject);
begin
  ThreadsCountLabel.Caption:='Количество потоков: ' +
                             IntToStr(ThreadsCountTB.Position);
end;

end.
