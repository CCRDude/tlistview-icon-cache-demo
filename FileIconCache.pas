{
   @author(Patrick Michael Kolla-ten Venne [pk] <patrick@kolla-tenvenne.de>)
   @abstract(Maintains an icon cache in the background.)

   @preformatted(
// *****************************************************************************
// Copyright: © 2018 Patrick Michael Kolla-ten Venne. All rights reserved.
// *****************************************************************************
// Changelog (new entries first):
// ---------------------------------------
// 2018-11-14  pk  ---  [CCD] Updated unit header.
// *****************************************************************************
   )
}

unit FileIconCache;

{$IFDEF FPC}
{$mode Delphi}{$H+}
{$ENDIF FPC}

interface

uses
   Classes,
   {$IFDEF MSWindows}
   Windows,
   {$ENDIF MSWindows}
   Graphics,
   Controls,
   {$IFDEF FPC}
   fgl,
   {$ELSE FPC}
   Generics.Collections,
   {$ENDIF FPC}
   SysUtils;

type
   TOnIconCacheGetNextEvent = procedure(var AFilename: string) of object;
   TOnIconCacheReceiveIconStreamEvent = procedure(AFilename: string; AStream: TMemoryStream) of object;
   TOnIconCacheReceiveIconIndexEvent = procedure(AFilename: string; AIconIndex: integer) of object;

   { TListViewIconCacheThread }

   TListViewIconCacheThread = class(TThread)
   private
      FOnGetNext: TOnIconCacheGetNextEvent;
      FOnReceiveIconStream: TOnIconCacheReceiveIconStreamEvent;
      FSyncFilename: string;
      FSyncStream: TMemoryStream;
      {$IFDEF MSWindows}
      procedure ExtractIconWindows(const sFilename: string);
      {$ENDIF MSWindows}
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

   TListViewIconCacheMap = TFPGMap<string, integer>;
   TListViewIconHashesMap = TFPGMap<string, integer>;

   { TFileIconCache }

   TFileIconCache = class
   private
      FIconCacheMap: TListViewIconCacheMap;
      FIconHashes: TListViewIconHashesMap;
      FIconCacheThread: TListViewIconCacheThread;
      FImageList: TImageList;
      FOnGetNext: TOnIconCacheGetNextEvent;
      FOnReceiveIconIndex: TOnIconCacheReceiveIconIndexEvent;
      procedure DoIconCacheGetNext(var AFilename: string);
      procedure DoIconCacheReceiveIconStream(AFilename: string; AStream: TMemoryStream);
   public
      constructor Create;
      destructor Destroy; override;
      function GetFileIcon(AFilename: string): integer;
      property OnGetNext: TOnIconCacheGetNextEvent read FOnGetNext write FOnGetNext;
      property OnReceiveIconIndex: TOnIconCacheReceiveIconIndexEvent read FOnReceiveIconIndex write FOnReceiveIconIndex;
      property ImageList: TImageList read FImageList write FImageList;
   end;


const
   IconCacheNoIconLoaded = 0;
   IconCacheNoIconAvailable = -1;
   IconCacheIconPending = -2;

implementation

uses
   sha1,
   ShellAPI;

{ TFileIconCache }

procedure TFileIconCache.DoIconCacheGetNext(var AFilename: string);
begin
   AFilename := '';
   if Assigned(FOnGetNext) then begin
      FOnGetNext(AFilename);
   end;
end;

procedure TFileIconCache.DoIconCacheReceiveIconStream(AFilename: string; AStream: TMemoryStream);
var
   i: TIcon;
   iHashIndex: integer;
   iIndex: integer;
   sHash: string;
begin
   if not Assigned(FImageList) then begin
      Exit;
   end;
   if AStream.Size = 0 then begin
      iIndex := IconCacheNoIconAvailable;
   end else begin
      i := TIcon.Create;
      try
         AStream.Seek(0, soFromBeginning);
         sHash := LowerCase(SHA1Print(SHA1Buffer(AStream.Memory^, AStream.Size)));
         iHashIndex := FIconHashes.IndexOf(sHash);
         if iHashIndex > -1 then begin
            iIndex := FIconHashes.Data[iHashIndex];
         end else begin
            i.LoadFromStream(AStream);
            iIndex := FImageList.AddIcon(i);
            FIconHashes.Add(sHash, iIndex);
         end;
      finally
         i.Free;
      end;
   end;
   FIconCacheMap.Add(AFilename, iIndex);
   if Assigned(FOnReceiveIconIndex) then begin
      FOnReceiveIconIndex(AFilename, iIndex);
   end;
end;

constructor TFileIconCache.Create;
begin
   FIconCacheMap := TListViewIconCacheMap.Create;
   FIconHashes := TListViewIconHashesMap.Create;
   FIconCacheThread := TListViewIconCacheThread.Create(True);
   FIconCacheThread.OnGetNext := DoIconCacheGetNext;
   FIconCacheThread.OnReceiveIconStream := DoIconCacheReceiveIconStream;
   FIconCacheThread.Resume;
end;

destructor TFileIconCache.Destroy;
begin
   FIconCacheThread.Terminate;
   FIconCacheThread.WaitFor;
   FIconCacheThread.Free;
   FIconHashes.Free;
   FIconCacheMap.Free;
   inherited Destroy;
end;

function TFileIconCache.GetFileIcon(AFilename: string): integer;
var
   iIndex: integer;
begin
   iIndex := FIconCacheMap.IndexOf(AFilename);
   if iIndex > -1 then begin
      Result := FIconCacheMap.Data[iIndex];
   end else begin
      Result := IconCacheNoIconLoaded;
   end;
end;

{ TListViewIconCacheThread }

procedure TListViewIconCacheThread.SyncGetNextFilename;
begin
   if Assigned(FOnGetNext) then begin
      FOnGetNext(FSyncFilename);
   end;
end;

{$IFDEF MSWindows}
procedure TListViewIconCacheThread.ExtractIconWindows(const sFilename: string);
var
   iconIndex: DWord;
   i: TIcon;
begin
   iconIndex := 0;
   try
      i := TIcon.Create;
      try
         i.Transparent := True;
         i.Handle := ExtractAssociatedIcon(hInstance, PChar(sFilename), @iconIndex);
         i.SaveToStream(FSyncStream);
         DestroyIcon(i.Handle);
         FSyncStream.Seek(0, soFromBeginning);
         SendReceiveIconStream(sFilename);
      finally
         i.Free;
      end;
   except
      on E: Exception do begin
         FSyncStream.Setsize(0);
         SendReceiveIconStream(sFilename);
      end;
   end;
end;
{$ENDIF MSWindows}

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
begin
   FSyncStream := TMemoryStream.Create;
   try
      while not Terminated do begin
         if GetNextFilename(sFilename) then begin
            OutputDebugString(PChar(sFilename));
            FSyncStream.SetSize(0);
            {$IF DEFINED(MSWindows)}
            ExtractIconWindows(sFilename);
            {$IFEND}
         end else begin
            Sleep(100);
         end;
      end;
   finally
      FSyncStream.Free;
   end;
end;

end.
