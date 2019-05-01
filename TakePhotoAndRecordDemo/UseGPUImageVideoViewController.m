//
//  UseGPUImageVideoViewController.m
//  TakePhotoAndRecordDemo
//
//  Created by Chen on 2018/11/16.
//  Copyright © 2018年 Chen. All rights reserved.
//

#import "UseGPUImageVideoViewController.h"
#import <GPUImage.h>
#import "AppDelegate.h"

#define SCREEN_WIDTH    [UIScreen mainScreen].bounds.size.width
#define SCREEN_HEIGHT [[UIScreen mainScreen] bounds].size.height
@interface UseGPUImageVideoViewController ()
@property (nonatomic, strong) GPUImageVideoCamera *videoCamera;
@property (nonatomic, strong) GPUImageMovieWriter *movieWriter;
@property (nonatomic, strong) GPUImageAlphaBlendFilter *blendFilter;
@property (nonatomic, strong) GPUImageView *filterView;
@property (nonatomic, strong) GPUImageUIElement *UIElement;
@property (nonatomic, strong) GPUImageFilter *filter;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) UILabel *preivewTimeLabel;
@property (nonatomic, strong) UILabel *previewNameLabel;
@property (nonatomic, strong) UILabel *freeSpaceLabel;
@property (nonatomic, strong) UIView *waterMarkView;
@property (nonatomic, strong) UIButton *recordBt;
@property (nonatomic, strong) UIButton *takePhotoBt;
@property (nonatomic, assign) float cropWidth;
@property (nonatomic, assign) float cropHeight;
@property (nonatomic, strong) NSTimer *refreshTimer;
@property (nonatomic, assign) int recordSeconds;
@property (nonatomic,strong)NSMutableArray *cameraOrMicrophoneAlertViewArr;
@property (nonatomic, copy) NSString *videoFileName;
@property (nonatomic, strong) UIButton *backButton;
@property (nonatomic, copy) NSString *labelName;
@property (nonatomic,strong)NSMutableArray *facesViewArr;
@property (nonatomic,strong) AVCaptureVideoPreviewLayer *previewLayer;
@end

@implementation UseGPUImageVideoViewController

-(void)viewWillAppear:(BOOL)animated
{
    
    [self.videoCamera addTarget:self.filterView];
    [self.videoCamera addTarget:self.filter];
    [self.filter addTarget:self.blendFilter];
    [self.UIElement addTarget:self.blendFilter];
    [self.videoCamera startCameraCapture];
    
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    [super viewWillAppear:animated];
    if (self.refreshTimer == nil) {
        self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateWaterTimeAndRecordTime) userInfo:nil repeats:YES];
    }

}

- (void)viewDidLoad {
    [super viewDidLoad];

   
    [self setupAboutGPUImage];
    //添加水印相关信息
    [self addWaterMarkView];
    [self addWaterMarkPreview];
     [self setupSubView];

}
-(void)setupSubView{
    
    UIButton *switchButton = [[UIButton alloc] initWithFrame:CGRectMake(50, SCREEN_HEIGHT - 50 - 10, 50, 50)];
    switchButton.layer.cornerRadius = 5.0;
    switchButton.layer.borderWidth = 2.0;
    switchButton.layer.borderColor = [[UIColor blackColor] CGColor];
    switchButton.backgroundColor = [UIColor lightGrayColor];
    [switchButton setTitle:@"切换" forState:UIControlStateNormal];
    [switchButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [switchButton addTarget:self action:@selector(switchButtonClicked:) forControlEvents:UIControlEventTouchDown];
    switchButton.transform = CGAffineTransformMakeRotation(M_PI_2);
    [self.view addSubview:switchButton];
    [self.view bringSubviewToFront:switchButton];
    
    
    if (self.isRecord == NO) {
        
        self.takePhotoBt = [self createButtonWithTitle:@"拍照" andCenter:CGRectMake(SCREEN_WIDTH / 2 + 25 + 10,SCREEN_HEIGHT - 50 - 10, 50, 50) andAction:@selector(takePhoto)];
        self.takePhotoBt.transform = CGAffineTransformMakeRotation(M_PI_2);
        [self.view addSubview:self.takePhotoBt];
        [self.view bringSubviewToFront:self.takePhotoBt];
        
    }
    else{
        
        self.recordBt = [self createButtonWithTitle:@"开始" andCenter:CGRectMake(SCREEN_WIDTH / 2 + 25 + 10,SCREEN_HEIGHT - 50 - 10, 50, 50) andAction:@selector(recordBtClicked:)];
        
        
        self.recordBt.transform = CGAffineTransformMakeRotation(M_PI_2);
        [self.view addSubview:self.recordBt];
        [self.view bringSubviewToFront:self.recordBt];

    }
    self.backButton = [self createButtonWithTitle:@"返回" andCenter:CGRectMake(SCREEN_WIDTH/ 2 - 25 - 10, SCREEN_HEIGHT - 50 - 10, 50, 50) andAction:@selector(backButtonClicked:)];
    self.backButton.transform = CGAffineTransformMakeRotation(M_PI_2);
    [self.view addSubview:self.backButton];
    [self.view bringSubviewToFront:self.backButton];
}
-(void)setupAboutGPUImage{
    self.videoCamera = [[GPUImageVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPreset1280x720 cameraPosition:AVCaptureDevicePositionFront];
    self.videoCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
    self.videoCamera.horizontallyMirrorFrontFacingCamera = YES;
    
    NSError *error;
    [self.videoCamera.inputCamera lockForConfiguration:&error];
    if ([self.videoCamera.inputCamera isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
        [self.videoCamera.inputCamera setFocusMode:AVCaptureFocusModeAutoFocus];
    }
    [self.videoCamera.inputCamera unlockForConfiguration];
    
    self.filterView = [[GPUImageView alloc] initWithFrame:CGRectMake(0, 0, 480, 640)];
    self.filterView.fillMode = kGPUImageFillModePreserveAspectRatioAndFill;
    
    self.view = self.filterView;
    
    
    self.filter = [[GPUImageFilter alloc] init];
    
    self.blendFilter = [[GPUImageAlphaBlendFilter alloc] init];
    [(GPUImageAlphaBlendFilter *)self.blendFilter setMix:1];
    
}
#pragma mark --拍照
-(void)takePhoto{
    AVAuthorizationStatus videoAuthStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
    if (videoAuthStatus == AVAuthorizationStatusNotDetermined) {// 未询问用户是否授权
        //第一次询问用户是否进行授权
        [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
            // CALL YOUR METHOD HERE - as this assumes being called only once from user interacting with permission alert!
            if (granted) {
                // Microphone enabled code
            }
            else {
                // Microphone disabled code
            }
        }];
        return;
    }
    
    //相机权限
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (authStatus ==AVAuthorizationStatusRestricted ||
        authStatus ==AVAuthorizationStatusDenied){
        [self showSetAlertView:@"相机"];
        return;
    }
    
    [self.blendFilter useNextFrameForImageCapture];
    UIImage *image = [self.blendFilter imageFromCurrentFramebufferWithOrientation:UIImageOrientationLeft];
    
    UIImageWriteToSavedPhotosAlbum(image, self, @selector(image:didFinishSavingWithError:contextInfo:), (__bridge void * _Nullable)(self));
    
    [self playsoud];
    [self dismissViewControllerAnimated:YES completion:nil];
}
- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo{
    
    NSLog(@"image = %@, error = %@, contextInfo = %@", image, error, contextInfo);
}


-(void)playsoud{
    SystemSoundID soundId;
    
    NSString *path = @"/System/Library/Audio/UISounds/photoShutter.caf";
    
    AudioServicesCreateSystemSoundID((__bridge CFURLRef)[NSURL fileURLWithPath:path], &soundId);
    
    AudioServicesPlaySystemSound(soundId);
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
}

-(void)updateWaterTimeAndRecordTime{
    self.recordSeconds++;
    [self updateTimeString];
    if ([self.recordBt.titleLabel.text isEqualToString:@"结束"]) {
        if (self.recordSeconds == 2) {
            self.recordBt.enabled = YES;
        }
        [self updateRecordTime];
    }
}




-(void) addWaterMarkView{
    //要做水印的视图
    self.waterMarkView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height)];
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 200, 21)];
    label.textAlignment = NSTextAlignmentLeft;
    
    label.text = @"我是水印";
    label.font = [UIFont systemFontOfSize:18];
    label.textColor = [UIColor whiteColor];
    [label sizeToFit];
    label.transform = CGAffineTransformMakeRotation(M_PI_2);
    label.frame = CGRectMake(self.view.frame.size.width - 21, 0, 21, 300);
    [self.waterMarkView addSubview:label];
    

    self.timeLabel = [[UILabel alloc] initWithFrame:CGRectMake(self.filterView.frame.size.width - 180, self.filterView.frame.size.height - 21, 180, 21)];
    self.timeLabel.textColor = [UIColor whiteColor];
    
    int hour = 0,min = 0,sec = 0;
    hour = (self.recordSeconds - 1) / 3600;
    min = ((self.recordSeconds - 1) % 3600) / 60;
    sec = ((self.recordSeconds - 1) % 3600) % 60;
    self.timeLabel.text =  [NSString stringWithFormat:@"时长：%.2d:%.2d:%.2d",hour,min,sec];
    self.timeLabel.textAlignment = NSTextAlignmentCenter;
    self.timeLabel.transform = CGAffineTransformMakeRotation(M_PI_2);
    
    self.timeLabel.frame = CGRectMake(self.view.frame.size.width - 21, self.view.frame.size.height - 200, 21, 200);
    [self.waterMarkView addSubview:self.timeLabel];
    
    //添加水印内容
    self.UIElement = [[GPUImageUIElement alloc] initWithView:self.waterMarkView];
    
    //
    __weak typeof(self) weakSelf = self;
    
    [self.filter setFrameProcessingCompletionBlock:^(GPUImageOutput *output, CMTime time) {
        if (weakSelf.isRecord == NO) {
            NSDateFormatter * dateFormat = [[NSDateFormatter alloc] init] ;
            [dateFormat setDateFormat: @"yyyy-MM-dd HH:mm:ss"];
            NSString *dateString = [dateFormat stringFromDate:[NSDate date]];
            weakSelf.timeLabel.text = dateString;
        }
        else
        {
            int hour = 0,min = 0,sec = 0;
            hour = (weakSelf.recordSeconds - 1) / 3600;
            min = ((weakSelf.recordSeconds - 1) % 3600) / 60;
            sec = ((weakSelf.recordSeconds - 1) % 3600) % 60;
            weakSelf.timeLabel.text =  [NSString stringWithFormat:@"时长：%.2d:%.2d:%.2d",hour,min,sec];
            
        }
        
        
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf.UIElement updateWithTimestamp:time];
        [output useNextFrameForImageCapture];
        
    }];
    
}

-(void) addWaterMarkPreview{
    self.previewNameLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 150, 21)];
    self.previewNameLabel.textAlignment = NSTextAlignmentLeft;
    self.previewNameLabel.text = @"我是水印";;
    self.previewNameLabel.font = [UIFont systemFontOfSize:18];
    self.previewNameLabel.textColor = [UIColor whiteColor];
    [self.previewNameLabel sizeToFit];
    self.previewNameLabel.transform = CGAffineTransformMakeRotation(M_PI_2);
    self.previewNameLabel.frame = CGRectMake(SCREEN_WIDTH - 21, 0, 21, 150);
    self.preivewTimeLabel.numberOfLines = 0;
    [self.view addSubview:self.previewNameLabel];

    
    self.freeSpaceLabel = [[UILabel alloc] init];
    self.freeSpaceLabel.textColor = [UIColor whiteColor];
    self.freeSpaceLabel.textAlignment = NSTextAlignmentCenter;
    self.freeSpaceLabel.transform = CGAffineTransformMakeRotation(M_PI_2);
    self.freeSpaceLabel.frame = CGRectMake(SCREEN_WIDTH - 21, SCREEN_HEIGHT - 200 - 150, 21, 150);
    self.freeSpaceLabel.hidden = YES;
    [self.view addSubview:self.freeSpaceLabel];
    
    self.preivewTimeLabel = [[UILabel alloc] initWithFrame:CGRectMake(self.filterView.frame.size.width - 200, self.filterView.frame.size.height - 21, 200, 21)];
    self.preivewTimeLabel.textColor = [UIColor whiteColor];
    
    self.preivewTimeLabel.textAlignment = NSTextAlignmentCenter;
    self.preivewTimeLabel.transform = CGAffineTransformMakeRotation(M_PI_2);
    
    self.preivewTimeLabel.frame = CGRectMake(SCREEN_WIDTH - 21, SCREEN_HEIGHT - 200, 21, 200);
    self.preivewTimeLabel.hidden = YES;
    [self.view addSubview:self.preivewTimeLabel];
    
}

#pragma mark --按钮创建及点击事件
- (UIButton *)createButtonWithTitle:(NSString *)title andCenter:(CGRect)frame andAction:(SEL)action{
    
    CGRect rect = CGRectMake(self.view.frame.size.width / 2 + 25 + 10 + self.cropWidth,self.view.frame.size.height - 50 - 10 + self.cropHeight, 50, 50);
    UIButton *btn = [[UIButton alloc] initWithFrame:rect];
    btn.layer.cornerRadius = 5.0;
    btn.layer.borderWidth = 2.0;
    btn.layer.borderColor = [[UIColor blackColor] CGColor];
    btn.backgroundColor = [UIColor lightGrayColor];
    btn.frame = frame;
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchDown];
    return btn;
    
}



-(void) switchButtonClicked:(UIButton *) sender{
    [self.videoCamera rotateCamera];
}

-(void) backButtonClicked:(UIButton *) sender{
    [self dismissViewControllerAnimated:YES completion:nil];
}



-(void) recordBtClicked:(UIButton *) sender{
    if ([sender.titleLabel.text isEqualToString:@"开始"]) {
        
        AVAuthorizationStatus videoAuthStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
        if (videoAuthStatus == AVAuthorizationStatusNotDetermined) {// 未询问用户是否授权
            //第一次询问用户是否进行授权
            [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
            }];
            return;
        }
        else if(videoAuthStatus == AVAuthorizationStatusRestricted || videoAuthStatus == AVAuthorizationStatusDenied) {// 未授权
            [self showSetAlertView:@"麦克风"];
            return;
        }
        //相机权限
        AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
        if (authStatus ==AVAuthorizationStatusRestricted ||
            authStatus ==AVAuthorizationStatusDenied)
        {
            [self showSetAlertView:@"相机"];
            return;
        }
        [self startRecord];
        
    }else{
        [self endRecord];
        
    }
}
#pragma mark  开始录制
-(void)startRecord
{
    //将录制时间保存到当前任务中
    NSString *nowTime = [NSString stringWithFormat:@"%lld",(long long)([[NSDate date] timeIntervalSince1970] * 1000)];
    self.videoFileName = [NSString stringWithFormat:@"%@.mp4",nowTime];
    self.recordBt.enabled = YES;
    
    self.recordSeconds = 0;
    self.backButton.enabled = NO;
    self.backButton.hidden = YES;
    
    
    [self.recordBt setTitle:@"结束" forState:UIControlStateNormal];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask, YES);
    
    //文件名
    NSString *videoFilePath = [NSString stringWithFormat:@"%@/%@",[paths objectAtIndex:0],self.videoFileName];
    
    NSURL *filePath = [NSURL fileURLWithPath:videoFilePath];
    
    NSMutableDictionary *videoSettings = [[NSMutableDictionary alloc] init];;
    [videoSettings setObject:AVVideoCodecH264 forKey:AVVideoCodecKey];
    
    AppDelegate *app = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    
    NSString *widthAndHeight = [[app.captureSession componentsSeparatedByString:@"Preset"] lastObject];
    
    int width = [[[widthAndHeight componentsSeparatedByString:@"x"] firstObject] intValue];
    int height = [[[widthAndHeight componentsSeparatedByString:@"x"] lastObject] intValue];
    
    [videoSettings setObject:[NSNumber numberWithInteger:width] forKey:AVVideoWidthKey];
    [videoSettings setObject:[NSNumber numberWithInteger:height] forKey:AVVideoHeightKey];
    NSMutableDictionary * compressionProperties = [[NSMutableDictionary alloc] init];
    
    NSString *videoSettingPlistPath = [[NSBundle mainBundle] pathForResource:@"VideoSetting" ofType:@"plist"];
    
    NSDictionary *videoSetting = [[NSDictionary alloc] initWithContentsOfFile:videoSettingPlistPath];
    
    [compressionProperties setObject:[NSNumber numberWithInt: [videoSetting[app.captureSession] intValue]*1024] forKey:AVVideoAverageBitRateKey];
    
    [videoSettings setObject:compressionProperties forKey:AVVideoCompressionPropertiesKey];
    
    self.movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:filePath size:CGSizeMake(height, width) fileType:AVFileTypeMPEG4 outputSettings:videoSettings];
    self.movieWriter.encodingLiveVideo = YES;
    self.movieWriter.assetWriter.movieFragmentInterval = kCMTimeInvalid;
    [self.blendFilter addTarget:self.movieWriter];
    [self.blendFilter setInputRotation:kGPUImageRotateLeft atIndex:0];
    [self.blendFilter setInputRotation:kGPUImageRotateLeft atIndex:1];
    self.videoCamera.audioEncodingTarget = self.movieWriter;
    [self.movieWriter startRecordingInOrientation:CGAffineTransformMakeRotation(0)];
    
    
}
#pragma mark -- 结束录制
-(void)endRecord{
    self.freeSpaceLabel.hidden = YES;
    self.preivewTimeLabel.hidden = YES;
    self.recordBt.enabled = YES;
    self.recordSeconds = 0;
    [self.recordBt setTitle:@"开始" forState:UIControlStateNormal];
    self.backButton.enabled = YES;
    self.backButton.hidden = NO;
    [self.blendFilter removeTarget:self.movieWriter];
    self.videoCamera.audioEncodingTarget = nil;
    __weak typeof(self) weakSelf = self;
    [self.movieWriter finishRecordingWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf dismissViewControllerAnimated:YES completion:^{
                NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask, YES);
                
                NSString *videoFilePath = [NSString stringWithFormat:@"%@/%@",[paths objectAtIndex:0],self.videoFileName];
                NSLog(@"videoFilePath:%@",videoFilePath);
            }];
        });
    }];
    
}

#pragma mark --GPUImageVideoCameraDelegate
- (void)willOutput:(AVCaptureOutput *)output withMetadataObjects:(NSArray<__kindof AVMetadataObject *> *)metadataObjects{
    //转换
    dispatch_async(dispatch_get_main_queue(), ^{
        for (UIView *faceView in self.facesViewArr) {
            [faceView removeFromSuperview];
        }
        [self.facesViewArr removeAllObjects];
    });
    
    for (AVMetadataFaceObject *faceobject in metadataObjects) {
        AVMetadataObject *face = [self.previewLayer transformedMetadataObjectForMetadataObject:faceobject];
        CGRect r = face.bounds;
        //画框
        dispatch_async(dispatch_get_main_queue(), ^{
            UIView *faceBox = [[UIView alloc] initWithFrame:r];
            faceBox.layer.borderWidth = 3;
            faceBox.layer.borderColor = [UIColor redColor].CGColor;
            faceBox.backgroundColor = [UIColor clearColor];
            [self.view addSubview:faceBox];
            [self.facesViewArr addObject:faceBox];
                NSLog(@"self.facesViewArr.count：%lu",(unsigned long)self.facesViewArr.count);
        });
       
    }

}

#pragma mark -- 提示用户进行麦克风使用授权
- (void)showSetAlertView:(NSString *)type
{
    NSAttributedString *title = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@权限未开启",type]];
    NSMutableAttributedString *message = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@权限未开启，请进入系统【设置】>【隐私】>【%@】中打开开关,开启%@功能",type,type,type]];
    NSLog(@"title:%@ message:%@",title,message);
    
}


//更新显示的时间
- (void)updateTimeString {
    NSDateFormatter * dateFormat = [[NSDateFormatter alloc] init] ;
    [dateFormat setDateFormat: @"yyyy-MM-dd HH:mm:ss"];
    NSString *dateString = [dateFormat stringFromDate:[NSDate date]];
    dispatch_async(dispatch_get_main_queue(), ^{
        self.preivewTimeLabel.text =  dateString;
    });
}

-(void)updateRecordTime
{
    int hour = 0,min = 0,sec = 0;
    hour = self.recordSeconds / 3600;
    min = (self.recordSeconds % 3600) / 60;
    sec = (self.recordSeconds % 3600) % 60;
    
    self.freeSpaceLabel.hidden = NO;
    self.freeSpaceLabel.text = [NSString stringWithFormat:@"剩余:%lldMB",(unsigned long long)([self getFreeDiskSpace] / 1000.0 / 1000.0)];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.preivewTimeLabel.text = [NSString stringWithFormat:@"时长：%.2d:%.2d:%.2d",hour,min,sec];
        self.preivewTimeLabel.hidden = NO;
        if (self.recordSeconds == 79 * 60) {
          
        }
        if (self.recordSeconds == 80 * 60) {
            [self recordBtClicked:self.recordBt];
        }
    });
}

// 获取未使用的磁盘空间
- (int64_t)getFreeDiskSpace {
    NSError *error = nil;
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfFileSystemForPath:NSHomeDirectory() error:&error];
    if (error) return -1;
    int64_t space =  [[attrs objectForKey:NSFileSystemFreeSize] longLongValue];
    if (space < 0) space = -1;
    return space;
}


-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.videoCamera stopCameraCapture];
    [self.videoCamera removeTarget:self.filterView];
    [self.videoCamera removeTarget:self.filter];
    [self.filter removeTarget:self.blendFilter];
    [self.UIElement removeTarget:self.blendFilter];
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [self.refreshTimer invalidate];
    self.refreshTimer = nil;
    
  
}


-(NSMutableArray *)cameraOrMicrophoneAlertViewArr
{
    if (!_cameraOrMicrophoneAlertViewArr) {
        _cameraOrMicrophoneAlertViewArr = [NSMutableArray array];
    }
    return _cameraOrMicrophoneAlertViewArr;
}
-(NSMutableArray *)facesViewArr{
    if (!_facesViewArr) {
        _facesViewArr = [NSMutableArray array];
    }
    return _facesViewArr;
}
#pragma mark - 其他
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
