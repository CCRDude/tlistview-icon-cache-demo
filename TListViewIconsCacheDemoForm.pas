{
   @author(Patrick Michael Kolla-ten Venne [pk] <patrick@kolla-tenvenne.de>)
   @abstract(Demonstrates icon loading and caching in a background thread.)

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

unit TListViewIconsCacheDemoForm;

{$IFDEF FPC}
{$mode Delphi}{$H+}
{$ENDIF FPC}

interface

uses
   Classes,
   SysUtils,
   Forms,
   Controls,
   Graphics,
   Dialogs,
   ComCtrls,
   StdCtrls,
   FileIconCache;

type
   TDemoListItem = class(TFileIconListItem);

   { TListViewIconsCacheDemoFormMain }

   TListViewIconsCacheDemoFormMain = class(TForm)
      bnRefresh: TButton;
      ilIcons: TImageList;
      lvFiles: TListView;
      procedure bnRefreshClick(Sender: TObject);
      procedure FormCreate(Sender: TObject);
      procedure FormDestroy(Sender: TObject);
      procedure FormShow(Sender: TObject);
      procedure lvFilesCreateItemClass(Sender: TCustomListView;
        var ItemClass: TListItemClass);
   private
      FPath: string;
      FFileIconCache: TFileIconCache;
      procedure DoIconCacheGetNext(var AFilename: string);
      procedure DoIconCacheReceiveIconIndex(AFilename: string; AIconIndex: integer);
   public
      procedure ShowFolderContents(AFolder: string);
   end;

var
   ListViewIconsCacheDemoFormMain: TListViewIconsCacheDemoFormMain;

implementation

{$R *.lfm}

{ TListViewIconsCacheDemoFormMain }

procedure TListViewIconsCacheDemoFormMain.FormShow(Sender: TObject);
begin
   bnRefresh.Click;
end;

procedure TListViewIconsCacheDemoFormMain.lvFilesCreateItemClass(
  Sender: TCustomListView; var ItemClass: TListItemClass);
begin
   ItemClass := TDemoListItem;
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

procedure TListViewIconsCacheDemoFormMain.DoIconCacheReceiveIconIndex(AFilename: string; AIconIndex: integer);
var
   li: TListItem;
begin
   li := lvFiles.Items.FindCaption(0, ExtractFileName(AFilename), False, True, False);
   if not Assigned(li) then begin
      Exit;
   end;
   li.ImageIndex := AIconIndex;
end;

procedure TListViewIconsCacheDemoFormMain.FormCreate(Sender: TObject);
begin
   FFileIconCache := TFileIconCache.Create;
   FFileIconCache.ListView := lvFiles;
   FFileIconCache.OnGetNext := DoIconCacheGetNext;
end;

procedure TListViewIconsCacheDemoFormMain.bnRefreshClick(Sender: TObject);
begin
   // TODO : pick own path; network folders work best to demonstrate since icons load slow
   ShowFolderContents('t:\people\patrick\');
end;

procedure TListViewIconsCacheDemoFormMain.FormDestroy(Sender: TObject);
begin
   FFileIconCache.Free;
end;

procedure TListViewIconsCacheDemoFormMain.ShowFolderContents(AFolder: string);
var
   sr: TSearchRec;
   i: integer;
   li: TFileIconListItem;
   iIndex: integer;
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
               li := TFileIconListItem(lvFiles.Items.Add);
               li.Filename := AFolder + sr.Name;
               li.Caption := sr.Name;
               li.ImageIndex := FFileIconCache.GetFileIcon(AFolder + sr.Name);
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
