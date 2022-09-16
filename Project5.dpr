program Project5;

uses
  System.StartUpCopy,
  FMX.Forms,
  Unit7 in 'Unit7.pas' {Form7},
  iOSapi.Photos in 'iOSapi.Photos.pas',
  iOSapi.PhotosUI in 'iOSapi.PhotosUI.pas',
  PhotoPicker.iOS in 'PhotoPicker.iOS.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm7, Form7);
  Application.Run;
end.
