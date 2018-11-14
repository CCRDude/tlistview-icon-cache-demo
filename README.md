These files demonstrate how to read and cache icon indizes for a TListView in the background.

# TODO

* Some kind of cleanup could be helpful for long term use.

# Delphi Users

To use this in Delphi, unit fgl would need to be replaced with Generics.Collections (I simply prefer fgl).

# OnReceiveIconIndex event

If you use a custom TListItem class based on TFileIconListItem, you do not need
to specify the OnReceiveIconIndex index. If not, you need to use it to find the
list item to assign the image index, like for example:

```procedure TListViewIconsCacheDemoFormMain.DoIconCacheReceiveIconIndex(AFilename: string; AIconIndex: integer);
var
   li: TListItem;
begin
   li := lvFiles.Items.FindCaption(0, ExtractFileName(AFilename), False, True, False);
   if not Assigned(li) then begin
      Exit;
   end;
   li.ImageIndex := AIconIndex;
end;
```
