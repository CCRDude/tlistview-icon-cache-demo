{
   @author(Patrick Michael Kolla-ten Venne [pk] <patrick@kolla-tenvenne.de>)
   @abstract(Test project file TListView file icons.)

   @preformatted(
// *****************************************************************************
// Copyright: © 2018 Patrick Michael Kolla-ten Venne. All rights reserved.
// *****************************************************************************
// Changelog (new entries first):
// ---------------------------------------
// 2018-11-14  --  ---  Renamed from ram TListViewIconsCacheDemo to TListViewIconsCacheDemo
// 2018-11-14  pk  ---  [CCD] Updated unit header.
// *****************************************************************************
   )
}

program TListViewIconsCacheDemo;

{$IFDEF FPC}
{$mode objfpc}{$H+}
{$ENDIF FPC}

uses {$IFDEF UNIX} {$IFDEF UseCThreads}
   cthreads, {$ENDIF} {$ENDIF}
   Interfaces, // this includes the LCL widgetset
   Forms,
   TListViewIconsCacheDemoForm;

{$R *.res}

begin
   RequireDerivedFormResource := True;
   Application.Scaled := True;
   Application.Initialize;
   Application.CreateForm(TListViewIconsCacheDemoFormMain, ListViewIconsCacheDemoFormMain);
   Application.Run;
end.


