unit TListViewIconsCacheDemoForm;

{$mode Delphi}{$H+}

interface

uses
   Classes,
   SysUtils,
   Windows,
   ShellAPI,
   Forms,
   Controls,
   Graphics,
   Dialogs,
   ComCtrls;

type
   TOnIconCacheGetNextEvent = procedure(var AFilename: string) of object;
   TOnIconCacheReceiveIconStreamEvent = procedure(AFilename: string; AStream: TStream) of object;

   { TListViewIconCacheThread }

   TListViewIconCacheThread = class(TThread)
   private
      FOnGetNext: TOnIconCacheGetNextEvent;
      FOnReceiveIconStream: TOnIconCacheReceiveIconStreamEvent;
      FSyncFilename: string;
      FSyncStream: TMemoryStream;
      procedure SyncGetNextFilename;
      procedure SyncSendReceiveIconStream;
      function GetNextFilename(out AFilename: string): boolean;
      procedure SendReceiveIconStream(AFilename: string);
   protected
      procedure Execute; override;
   public
      property OnGetNext: TOnIconCacheGetNextEvent read FOnGetNext write FOnGetNext;
      property OnReceiveIconStream: TOnIconCacheReceiveIconStreamEvent read FOnReceiveIconStream write FOnReceiveIconStream;
   end;

   { TListViewIconsCacheDemoFormMain }

   TListViewIconsCacheDemoFormMain = class(TForm)
      ilIcons: TImageList;
      lvFiles: TListView;
      procedure FormCreate(Sender: TObject);
      procedure FormDestroy(Sender: TObject);
      procedure FormShow(Sender: TObject);
   private
      FPath: string;
      FIconCacheThread: TListViewIconCacheThread;
      procedure DoIconCacheGetNext(var AFilename: string);
      procedure DoIconCacheReceiveIconStream(AFilename: string; AStream: TStream);
   public
      procedure ShowFolderContents(AFolder: string);
   end;

var
   ListViewIconsCacheDemoFormMain: TListViewIconsCacheDemoFormMain;

implementation

{$R *.lfm}

const
   IconCacheNoIconLoaded = 0;
   IconCacheNoIconAvailable = -1;
   IconCacheIconPending = -2;

{ TListViewIconCacheThread }

procedure TListViewIconCacheThread.SyncGetNextFilename;
begin
   if Assigned(FOnGetNext) then begin
      FOnGetNext(FSyncFilename);
   end;
end;

procedure TListViewIconCacheThread.SyncSendReceiveIconStream;
begin
   if Assigned(FOnReceiveIconStream) then begin
      FOnReceiveIconStream(FSyncFilename, FSyncStream);
   end;
end;

function TListViewIconCacheThread.GetNextFilename(out AFilename: string): boolean;
begin
   Result := Assigned(FOnGetNext);
   if Result then begin
      FSyncFilename := '';
      Synchronize(SyncGetNextFilename);
      AFilename := FSyncFilename;
      Result := Length(AFilename) > 0;
   end;
end;

procedure TListViewIconCacheThread.SendReceiveIconStream(AFilename: string);
begin
   FSyncFilename := AFilename;
   if Assigned(FOnReceiveIconStream) then begin
      Synchronize(SyncSendReceiveIconStream);
   end;
end;

procedure TListViewIconCacheThread.Execute;
var
   sFilename: string;
   i: TIcon;
   iconIndex: DWord = 0;
begin
   FSyncStream := TMemoryStream.Create;
   try
      while not Terminated do begin
         if GetNextFilename(sFilename) then begin
            OutputDebugString(PChar(sFilename));
            FSyncStream.SetSize(0);
            i := TIcon.Create;
            try
               i.Transparent := True;
               i.Handle := ExtractAssociatedIcon(hInstance, PChar(sFilename), @iconIndex);
               i.SaveToStream(FSyncStream);
               DestroyIcon(i.Handle);
               FSyncStream.Seek(0, soFromBeginning);
               //FSyncStream.SaveToFile(sFilename + '.ico');
               SendReceiveIconStream(sFilename);
            finally
               i.Free;
            end;
         end else begin
            Sleep(100);
         end;
      end;
   finally
      FSyncStream.Free;
   end;
end;

{ TListViewIconsCacheDemoFormMain }

procedure TListViewIconsCacheDemoFormMain.FormShow(Sender: TObject);
begin
   // TODO : pick own path; network folders work best to demonstrate since icons load slow
   ShowFolderContents('t:\people\patrick\');
end;

procedure TListViewIconsCacheDemoFormMain.DoIconCacheGetNext(var AFilename: string);
var
   liFirst: TListItem;
   iFirst: integer;
begin
   AFilename := '';
   if lvFiles.Items.Count = 0 then begin
      Exit;
   end;
   liFirst := lvFiles.TopItem;
   if not Assigned(liFirst) then begin
      liFirst := lvFiles.Items[0];
   end;
   iFirst := liFirst.Index;
   while (iFirst < lvFiles.Items.Count) do begin
      if lvFiles.Items[iFirst].ImageIndex = IconCacheNoIconLoaded then begin
         AFilename := FPath + lvFiles.Items[iFirst].Caption;
         lvFiles.Items[iFirst].ImageIndex := IconCacheIconPending;
         Exit;
      end;
      Inc(iFirst);
   end;
end;

procedure TListViewIconsCacheDemoFormMain.DoIconCacheReceiveIconStream(AFilename: string; AStream: TStream);
var
   li: TListItem;
   i: TIcon;
begin
   li := lvFiles.Items.FindCaption(0, ExtractFileName(AFilename), False, True, False);
   if not Assigned(li) then begin
      Exit;
   end;
   i := TIcon.Create;
   try
      i.LoadFromStream(AStream);
      li.ImageIndex := ilIcons.AddIcon(i);
   finally
      i.Free;
   end;
end;

procedure TListViewIconsCacheDemoFormMain.FormCreate(Sender: TObject);
begin
   FIconCacheThread := TListViewIconCacheThread.Create(True);
   FIconCacheThread.OnGetNext := DoIconCacheGetNext;
   FIconCacheThread.OnReceiveIconStream := DoIconCacheReceiveIconStream;
   FIconCacheThread.Resume;
end;

procedure TListViewIconsCacheDemoFormMain.FormDestroy(Sender: TObject);
begin
   FIconCacheThread.Terminate;
   FIconCacheThread.WaitFor;
   FIconCacheThread.Free;
end;

procedure TListViewIconsCacheDemoFormMain.ShowFolderContents(AFolder: string);
var
   sr: TSearchRec;
   i: integer;
   li: TListItem;
begin
   FPath := AFolder;
   AFolder := IncludeTrailingPathDelimiter(AFolder);
   lvFiles.Items.BeginUpdate;
   try
      lvFiles.Items.Clear;
      i := FindFirst(AFolder + '*.*', faAnyFile, sr);
      try
         while i = 0 do begin
            if (sr.Name <> '.') and (sr.Name <> '..') then begin
               li := lvFiles.Items.Add;
               li.ImageIndex := IconCacheNoIconLoaded;
               li.Caption := sr.Name;
            end;
            i := FindNext(sr);
         end;
      finally
         SysUtils.FindClose(sr);
      end;
   finally
      lvFiles.Items.EndUpdate;
   end;
end;

end.
