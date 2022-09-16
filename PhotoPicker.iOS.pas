unit PhotoPicker.iOS;

interface
uses
  System.Classes,
  System.SysUtils,
  System.Threading,
  Macapi.ObjectiveC,
  Macapi.Helpers,
  iOSapi.Foundation,
  iOSapi.UIKit,
  FMX.Helpers.iOS,
  iOSapi.CocoaTypes,
  iOSapi.PhotosUI,
  FMX.Types,
  FMX.Graphics;

Type
  TOnSelectedImage = TProc<String,TDateTime,TDateTime,TBitmap>;
  TOnFinish = TProc;
  TOnError = TProc<String>;

  TiOSPhotoPicker = class(TOCLocal,PHPickerViewControllerDelegate)
  private const
    SECONDS_ELAPSED = 40;
  private
    FPickerViewController: PHPickerViewController;
    FMaxSelectdImage: Integer;
    FPickerSelectedImageCount: Integer;
    FImageCounter: Integer;
    FLastTime: TTime;
    FTimer: TTimer;
    FOnSelectedImage: TOnSelectedImage;
    FOnFinish: TOnFinish;
    FOnError: TOnError;

    procedure OnTimer(Sender: TObject);
  private
    procedure DoClosePicker;
    procedure DoCreatePicker;
    procedure DoShowPicker;
    procedure DoGetUrlFromProvider(url: NSURL; error: NSError);
    procedure DoClearTimer;
    procedure DoInitializeTimer(const ASelectedImageCount: Integer);
    procedure DoUpdateImageCount;
 public
    constructor Create(AOnSelectedImage: TOnSelectedImage; AOnFinish: TOnFinish; AOnError: TOnError; const AMaxSelectdImage: Integer = 0 {All}); overload;
    destructor Destroy; override;

    procedure ShowPicker;
    procedure picker(picker: PHPickerViewController; didFinishPicking: NSArray); cdecl;

  end;

implementation
uses
  System.IOUtils,
  System.DateUtils,
  iOSapi.Photos;

{ TiOSPhotoPicker }

constructor TiOSPhotoPicker.Create(AOnSelectedImage: TOnSelectedImage; AOnFinish: TOnFinish; AOnError: TOnError; const AMaxSelectdImage: Integer = 0);
begin
  inherited Create;

  FMaxSelectdImage := AMaxSelectdImage;  //0 = All
  if (FMaxSelectdImage < 0) then
    FMaxSelectdImage := 0;

  FOnSelectedImage := AOnSelectedImage;
  FOnFinish := AOnFinish;
  FOnError := AOnError;

  FTimer := TTimer.Create(nil);
  FTimer.Interval := 100;
  FTimer.OnTimer := OnTimer;

  DoClearTImer
end;

destructor TiOSPhotoPicker.Destroy;
begin
  FTimer.Enabled := False;
  FreeAndNil(FTimer);

  inherited;
end;

procedure TiOSPhotoPicker.OnTimer(Sender: TObject);
begin
  FTimer.Enabled := False;

  TMonitor.Enter(Self);
  try
    if (FImageCounter >= FPickerSelectedImageCount) then  begin
      DoClosePicker;

      if (Assigned(FOnFinish)) then
        FOnFinish;
    end
    else if (SecondSpan(FLastTime,Time) >= SECONDS_ELAPSED) then begin
      DoClosePicker;

      if (Assigned(FOnError)) then
        FOnError('Error: Timeout to get selected images');
    end else
      FTimer.Enabled := True;
  finally
    TMonitor.Exit(Self);
  end;
end;

procedure TiOSPhotoPicker.DoClearTimer;
begin
  FPickerSelectedImageCount := 0;
  FLastTime := 0;
  FImageCounter := 0;
  FTimer.Enabled := False;
end;

procedure TiOSPhotoPicker.DoInitializeTimer(const ASelectedImageCount: Integer);
begin
  DoClearTimer;

  FPickerSelectedImageCount := ASelectedImageCount;
  FLastTime := Time;
  FTimer.Enabled := True;
end;

procedure TiOSPhotoPicker.DoUpdateImageCount;
begin
  TMonitor.Enter(Self);
  try
    FLastTime := Time;
    Inc(FImageCounter);
  finally
    TMonitor.Exit(Self);
  end;
end;

procedure TiOSPhotoPicker.DoClosePicker;
begin
  DoClearTimer;

  if (FPickerViewController <> nil) then begin
    FPickerViewController.setDelegate(nil);
    FPickerViewController.release;
  end;
end;

procedure TiOSPhotoPicker.DoCreatePicker;
var
  pickerConfiguration: PHPickerConfiguration;
begin
  DoClosePicker;

  TPHPhotoLibrary.OCClass.requestAuthorization(nil); //TODO: controllare lo stato

  pickerConfiguration := TPHPickerConfiguration.Alloc;
  pickerConfiguration.initWithPhotoLibrary(TPHPhotoLibrary.OCClass.sharedPhotoLibrary);

  pickerConfiguration.setSelectionLimit(FMaxSelectdImage);
  pickerConfiguration.setFilter(TPHPickerFilter.OCClass.imagesFilter);

  FPickerViewController := TPHPickerViewController.Alloc;
  FPickerViewController.initWithConfiguration(pickerConfiguration);
  FPickerViewController.setDelegate(self.GetObjectID);
end;

procedure TiOSPhotoPicker.DoShowPicker;
var
  Window: UIWindow;
begin
  DoCreatePicker;

  Window := SharedApplication.keyWindow;
  if (Window <> nil) and (Window.rootViewController <> nil) then
     Window.rootViewController.presentModalViewController(FPickerViewController, True);
end;

procedure TiOSPhotoPicker.ShowPicker;
begin
  DoShowPicker;
end;

procedure TiOSPhotoPicker.DoGetUrlFromProvider(url: NSURL; error: NSError);
const
  NSFILECREATIONDATE = 'NSFileCreationDate';
  NSFILEMODIFICATIONDATE = 'NSFileModificationDate';
var
  fileAttributes: NSDictionary;

  filePath: String;
  fileName: String;
  fileCreationDate: TDateTime;
  fileModificationDate: TDateTime;

  image: TBitmap;
begin
  if (Assigned(error)) then begin
    DoClosePicker;

    if (Assigned(FOnError)) then
        FOnError('Error on get image: ' +
                  NSStrToStr(error.localizedDescription) +
                  sLineBreak +
                  NSStrToStr(error.localizedFailureReason));

    Exit;
  end;

  if (Assigned(url)) then begin
    var fileManager: NSFileManager := TNSFileManager.Wrap(TNSFileManager.OCClass.defaultManager);

    fileAttributes := fileManager.attributesOfItemAtPath(url.path);

    filePath := NSStrToStr(url.path); // This is fullpath with image name
    fileName := NSStrToStr(url.lastPathComponent);
    fileCreationDate := NSDateToDateTime(TNSDate.Wrap(fileAttributes.valueForKey(StrToNSStr(NSFILECREATIONDATE))));
    fileModificationDate := NSDateToDateTime(TNSDate.Wrap(fileAttributes.valueForKey(StrToNSStr(NSFILEMODIFICATIONDATE))));

    if (FileExists(filePath)) then begin
      if (Assigned(FOnSelectedImage)) then begin
        image := TBitMap.CreateFromFile(filePath);
        try
          FOnSelectedImage(filename,fileCreationDate,fileModificationDate,image);
        finally
          FreeAndNil(image);
        end;

        DoUpdateImageCount;
      end;
    end;
  end;
end;


procedure TiOSPhotoPicker.picker(picker: PHPickerViewController; didFinishPicking: NSArray);
var
  pickerResult: PHPickerResult;
//
//  refID: String;
//  refIDs: NSMutableArray;
//
//  assetResults: PHFetchResult;
//  assetResult: PHAsset;

  fileDate: TDateTime;
  fileName: String;
begin
  picker.dismissModalViewControllerAnimated(True);
  var imageCount: Integer := didFinishPicking.count;

  DoInitializeTimer(imageCount);

  for var i: Integer := 0 to imageCount - 1 do begin
    pickerResult := TPHPickerResult.Wrap(didFinishPicking.objectAtIndex(i));
    if (pickerResult <> nil) then begin
       //Get data from Asset
//       refID := NSStrToStr(pickerResult.assetIdentifier);
//
//       refIDS := TNSMutableArray.Create;
//       refIDS.addObject(StringToID(refID));
//
//       assetResults :=  TPHAsset.OCClass.fetchAssetsWithLocalIdentifiers(refIDS,nil);
//       for var t: Integer := 0 to assetResults.count -1 do begin
//         assetResult := TPHAsset.Wrap(assetResults.objectAtIndex(t));
//         if (Assigned(assetResult)) then begin
//           fileDate := NSDateToDateTime(assetResult.modificationDate);
//
//         end;
//       end;
      if (Assigned(pickerResult.itemProvider)) then
        pickerResult.itemProvider.loadFileRepresentationForTypeIdentifier(StrToNSStr('public.image'),DoGetUrlFromProvider);
    end;
  end;
end;
end.
