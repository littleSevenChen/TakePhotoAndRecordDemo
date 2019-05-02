//
//  UseAVFTakePhotoAndRecordViewController.m
//  TakePhotoAndRecordDemo
//
//  Created by Chen on 2018/11/15.
//  Copyright © 2018年 Chen. All rights reserved.
//

#import "UseAVFTakePhotoAndRecordViewController.h"
#import <AVFoundation/AVFoundation.h>

#define KScreenWidth  [UIScreen mainScreen].bounds.size.width
#define KScreenHeight  [UIScreen mainScreen].bounds.size.height
@interface UseAVFTakePhotoAndRecordViewController ()<UIGestureRecognizerDelegate,AVCaptureVideoDataOutputSampleBufferDelegate,AVCaptureFileOutputRecordingDelegate>
//session：由他把输入输出结合在一起，并开始启动捕获设备（摄像头）
@property (nonatomic,strong)AVCaptureSession *session;
@property (nonatomic,strong)AVCaptureDevice *device;
//AVCaptureDeviceInput 代表输入设备，他使用AVCaptureDevice 来初始化
@property(nonatomic)AVCaptureDeviceInput *input;
//照片输出流
@property (nonatomic,strong)AVCaptureStillImageOutput *stillImageOut;

//视频输出流
@property (nonatomic,strong)AVCaptureMovieFileOutput *movieFileOutput;
@property (nonatomic,strong)dispatch_queue_t videoQueue;
@property (nonatomic,strong)AVCaptureConnection *connect;
//图像预览层，实时显示捕获的图像
@property(nonatomic)AVCaptureVideoPreviewLayer *previewLayer;
//拍照按钮
@property (nonatomic)UIButton           *photoButton;
//闪光灯按钮
@property (nonatomic)UIButton           *flashButton;
//聚焦
@property (nonatomic)UIView             *focusView;
//是否开启闪光灯
@property (nonatomic)BOOL               isflashOn;
/**
 *  记录开始的缩放比例
 */
@property(nonatomic,assign)CGFloat beginGestureScale;
/**
 *  最后的缩放比例
 */
@property(nonatomic,assign)CGFloat effectiveScale;

@property(nonatomic,strong)AVAssetWriterInput *videoInput;
@property(nonatomic,strong)AVAssetWriterInput *audioInput;
@property (nonatomic,strong)AVAssetWriter *writer;
@property (nonatomic, strong) NSURL *fileUrl;

@end

@implementation UseAVFTakePhotoAndRecordViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _isflashOn = NO;
    [self customCamera];
    [self initSubViews];
    self.effectiveScale = 1.0f;
    self.beginGestureScale = 1.0f;
    [self setUpGesture];
    // Do any additional setup after loading the view.
}

- (void)customCamera{
    _session = [[AVCaptureSession alloc] init];
    [_session setSessionPreset:AVCaptureSessionPresetHigh];
    
    if (self.isRecord) {
        self.device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        self.input = [AVCaptureDeviceInput deviceInputWithDevice:self.device error:nil];
        self.movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
        self.connect = [self.movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
        if ([_session canAddOutput:_movieFileOutput]) {
            [_session addOutput:_movieFileOutput];
        }
        
    }else{
        _stillImageOut = [[AVCaptureStillImageOutput alloc] init];
        self.device = [self getCameraWithPostion:AVCaptureDevicePositionBack];
        self.input = [[AVCaptureDeviceInput alloc] initWithDevice:self.device error:nil];
        if ([_session canAddOutput:_stillImageOut]) {
            [_session addOutput:_stillImageOut];
        }
    }
    if ([_session canAddInput:self.input]) {
        [_session addInput:self.input];
    }
    
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_session];
    self.previewLayer.frame = self.view.bounds;
    [self.view.layer addSublayer:self.previewLayer];
    
    [_session startRunning];
}
- (void)initSubViews
{
    UIButton *dismissButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [dismissButton setImage:[UIImage imageNamed:@"dismiss"] forState:UIControlStateNormal];
    dismissButton.frame = CGRectMake(KScreenWidth-70, KScreenHeight-70, 50, 50);
    dismissButton.center = CGPointMake((KScreenWidth - 60)/2.0/2.0, KScreenHeight-70);
    [dismissButton addTarget:self action:@selector(disMiss) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:dismissButton];
    
    self.photoButton = [[UIButton alloc] init];
    self.photoButton.frame = CGRectMake(KScreenWidth/2.0-30, KScreenHeight-100, 60, 60);
    if (self.isRecord) {
        [self.photoButton setTitle:@"录像" forState:UIControlStateNormal];
        [self.photoButton addTarget:self action:@selector(Record:) forControlEvents:UIControlEventTouchUpInside];
    }else{
        [self.photoButton setImage:[UIImage imageNamed:@"photograph"] forState:UIControlStateNormal];
        [self.photoButton addTarget:self action:@selector(takePhoto) forControlEvents:UIControlEventTouchUpInside];
    }
    
    
    [self.view addSubview:self.photoButton];
    
    self.focusView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, 80, 80)];
    self.focusView.layer.borderWidth = 1.0;
    self.focusView.layer.borderColor = [UIColor greenColor].CGColor;
    [self.view addSubview:self.focusView];
    self.focusView.hidden = YES;
    
    UIButton *btn = [[UIButton alloc]init];
    btn.frame = CGRectMake(KScreenWidth - 60, 20, 40, 20);
    [btn setTitle:@"切换" forState:UIControlStateNormal];
    btn.titleLabel.textAlignment = NSTextAlignmentCenter;
    [btn sizeToFit];
    [btn addTarget:self action:@selector(changeCamera) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn];
    
    self.flashButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.flashButton setTitle:@"闪光灯关" forState:UIControlStateNormal];
    self.flashButton.titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.flashButton sizeToFit];
    self.flashButton.center = CGPointMake(KScreenWidth - (KScreenWidth - 60)/2.0/2.0, KScreenHeight-70);
    [ self.flashButton addTarget:self action:@selector(FlashOn) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview: self.flashButton];
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(focusGesture:)];
    [self.view addGestureRecognizer:tapGesture];
}

-(AVCaptureDevice *)getCameraWithPostion:(AVCaptureDevicePosition)position{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for ( AVCaptureDevice *device in devices )
        if ( device.position == position ){
            return device;
        }
    return nil;
}


- (void)setUpGesture{
    UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinchGesture:)];
    pinch.delegate = self;
    [self.view addGestureRecognizer:pinch];
}
#pragma mark  --拍照
-(void)takePhoto{
    AVCaptureConnection *connect = [self.stillImageOut connectionWithMediaType:AVMediaTypeVideo];
    [self.stillImageOut captureStillImageAsynchronouslyFromConnection:connect completionHandler:^(CMSampleBufferRef  _Nullable imageDataSampleBuffer, NSError * _Nullable error) {
        NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
        UIImage *image = [UIImage imageWithData:imageData];
        UIImageWriteToSavedPhotosAlbum(image, self, @selector(image:didFinishSavingWithError:contextInfo:), (__bridge void * _Nullable)(self));
    }];
}
#pragma mark  --录像
-(void)Record:(UIButton *) sender{
    if ([sender.titleLabel.text isEqualToString:@"录像"]) {
        [self.movieFileOutput startRecordingToOutputFileURL:self.fileUrl recordingDelegate:self];
        [self.photoButton setTitle:@"结束" forState:UIControlStateNormal];
    }else{
        //停止录制
        [self.movieFileOutput stopRecording];
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)captureOutput:(AVCaptureFileOutput *)output didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray<AVCaptureConnection *> *)connections{
    NSLog(@"开始录制了");
}
- (void)captureOutput:(AVCaptureFileOutput *)output didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray<AVCaptureConnection *> *)connections error:(nullable NSError *)error{
    NSLog(@"结束录制了");
}


-(void)changeCamera{
    
    NSUInteger cameraCount = [[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] count];
    if (cameraCount <= 1) {
        return;
    }
    AVCaptureDevice *newDevice = nil;
    AVCaptureDeviceInput *newInput = nil;
    AVCaptureDevicePosition position = [[self.input device] position];
    if (position == AVCaptureDevicePositionBack) {
        newDevice = [self getCameraWithPostion:AVCaptureDevicePositionFront];
    }else{
        newDevice = [self getCameraWithPostion:AVCaptureDevicePositionBack];
    }
    newInput = [[AVCaptureDeviceInput alloc] initWithDevice:newDevice error:nil];
    if (newDevice != nil) {
        [self.session beginConfiguration];
        [self.session removeInput:self.input];
        if ([self.session canAddInput:newInput]) {
            [self.session addInput:newInput];
            self.input = newInput;
        }else{
            [self.session addInput:self.input];
        }
        [self.session commitConfiguration];
    }
    
}

-(void)FlashOn{
    [_device lockForConfiguration:nil];
    if (_isflashOn) {
        if ([_device isFlashModeSupported:AVCaptureFlashModeOff]) {
            [_device setFlashMode:AVCaptureFlashModeOff];
            [_device setTorchMode:AVCaptureTorchModeOff];
            _isflashOn = NO;
            [_flashButton setTitle:@"闪光灯关" forState:UIControlStateNormal];
        }
    }else{
        if ([_device isFlashModeSupported:AVCaptureFlashModeOn]) {
            [_device setFlashMode:AVCaptureFlashModeOn];
            [_device setTorchMode:AVCaptureTorchModeOn];
            _isflashOn = YES;
            [_flashButton setTitle:@"闪光灯开" forState:UIControlStateNormal];
        }
    }
     [_device unlockForConfiguration];
}


- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo
{

    NSLog(@"image = %@, error = %@, contextInfo = %@", image, error, contextInfo);
}
-(void)disMiss{
    [self dismissViewControllerAnimated:YES completion:nil];
}
#pragma mark gestureRecognizer delegate
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if ( [gestureRecognizer isKindOfClass:[UIPinchGestureRecognizer class]] ) {
        self.beginGestureScale = self.effectiveScale;
    }
    return YES;
}
//缩放手势 用于调整焦距
- (void)handlePinchGesture:(UIPinchGestureRecognizer *)recognizer{
    BOOL allTouchesAreOnThePreViewLayer = YES;
    NSUInteger numTouches = [recognizer numberOfTouches];
    for (int i = 0; i < numTouches; ++i) {
        CGPoint location = [recognizer locationInView:self.view];
        CGPoint covertedLocation = [self.previewLayer convertPoint:location fromLayer:self.previewLayer.superlayer];
        if (![self.previewLayer containsPoint:covertedLocation]) {
            allTouchesAreOnThePreViewLayer = NO;
            break;
        }
        
    }
    if (allTouchesAreOnThePreViewLayer) {
        self.effectiveScale = self.beginGestureScale * recognizer.scale;
        if (self.effectiveScale < 1.0) {
            self.effectiveScale = 1.0;
        }
        if (self.effectiveScale > 10) {
            self.effectiveScale = 10;
        }
        CGFloat maxScaleAndCropFactor = [[self.stillImageOut connectionWithMediaType:AVMediaTypeVideo] videoMaxScaleAndCropFactor];
        if (maxScaleAndCropFactor < 10.0) {
            self.effectiveScale = maxScaleAndCropFactor;
        }
        
        [CATransaction begin];
        [CATransaction setAnimationDuration:0.05];
        [self.previewLayer setAffineTransform:CGAffineTransformMakeScale(self.effectiveScale, self.effectiveScale)];
        [CATransaction commit];
        
        
    }
}

- (void)focusGesture:(UITapGestureRecognizer*)gesture{
    CGPoint point = [gesture locationInView:gesture.view];
    [self focusAtPoint:point];
}
- (void)focusAtPoint:(CGPoint)point{
    CGSize size = self.view.bounds.size;
#warning
    /* focusPointOfInterest根据API文档：A value of (0,0) indicates that the camera should focus on the top left corner of the image, while a value of (1,1) indicates that it should focus on the bottom right.
     坐上角的坐标为(0,0),右下角的坐标为（1，1）。但经测试，发现文档是错误的，实际是：右上角的坐标为（0，0），左下角的坐标为（1，1）
    */
    CGPoint focusPoint = CGPointMake( point.y /size.height ,1 - point.x/size.width );
    
    NSLog(@"focusPoint%@ y:%f,x:%f",NSStringFromCGPoint(focusPoint),point.y,point.x);
    if ([self.device lockForConfiguration:nil]) {
        
        if ([self.device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
            [self.device setFocusPointOfInterest:focusPoint];
            [self.device setFocusMode:AVCaptureFocusModeAutoFocus];
        }
        
        if ([self.device isExposureModeSupported:AVCaptureExposureModeAutoExpose ]) {
            [self.device setExposurePointOfInterest:focusPoint];
            //曝光量调节
            [self.device setExposureMode:AVCaptureExposureModeAutoExpose];
        }
        
        [self.device unlockForConfiguration];
        _focusView.center = point;
        _focusView.hidden = NO;
        [UIView animateWithDuration:0.3 animations:^{
            self.focusView.transform = CGAffineTransformMakeScale(1.25, 1.25);
        }completion:^(BOOL finished) {
            [UIView animateWithDuration:0.5 animations:^{
                self.focusView.transform = CGAffineTransformIdentity;
            } completion:^(BOOL finished) {
                self.focusView.hidden = YES;
            }];
        }];
    }
    
}
- (NSURL *)fileUrl
{
    if (!_fileUrl) {
        _fileUrl = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"testMovie.mp4"]];
    }
    return _fileUrl;
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
