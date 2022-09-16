unit Unit7;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.Controls.Presentation, FMX.StdCtrls, FMX.Objects;

type
  TForm7 = class(TForm)
    Button1: TButton;
    Timer1: TTimer;
    Image1: TImage;
    Label1: TLabel;
    procedure Button1Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form7: TForm7;

implementation

{$R *.fmx}

uses
  System.Permissions,
  PhotoPicker.iOS;

procedure TForm7.Button1Click(Sender: TObject);
var
  iOSPhotoPicker: TiOSPhotoPicker;
begin
iOSPhotoPicker := TiOSPhotoPicker.Create(procedure (AFileNanem: String;
                                                    AFileCreationDate,AFileModificationDate: TDateTIme;
                                                    AImage: TBitmap) begin
       TTHread.Synchronize(nil, procedure begin
         image1.Bitmap.Assign(AImage)     ;
         label1.Text := AFileNanem;
       end)
     end,

     procedure begin
      ShowMessage('Finito');
     end,

     procedure (AError: String) begin
     end)
  ;

iOSPhotoPicker.showPicker;
end;

end.
