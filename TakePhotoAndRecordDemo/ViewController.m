
//  ViewController.m
//  TakePhotoAndRecordDemo
//
//  Created by Chen on 2018/11/15.
//  Copyright © 2018年 Chen. All rights reserved.
//
/**
 录制的视频在应用中，可以根据自己的需求设置路径及获取路径，并播放展示出来;
 
 */


#import "ViewController.h"
#import "UseAVFTakePhotoAndRecordViewController.h"
#import "UseGPUImageVideoViewController.h"
@interface ViewController ()

@end

@implementation ViewController




- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view, typically from a nib.
}


- (IBAction)AVFTakePhotoBtnClick:(id)sender {
    UseAVFTakePhotoAndRecordViewController *takePhotoVC = [[UseAVFTakePhotoAndRecordViewController alloc] init];
    takePhotoVC.isRecord = NO;
    [self presentViewController:takePhotoVC animated:YES completion:nil];
}
- (IBAction)AVFRecordBtnClick:(id)sender {
    UseAVFTakePhotoAndRecordViewController *takePhotoVC = [[UseAVFTakePhotoAndRecordViewController alloc] init];
    takePhotoVC.isRecord = YES;
    [self presentViewController:takePhotoVC animated:YES completion:nil];
}


- (IBAction)GPUImageTakePhotoBtnClick:(id)sender {
    UseGPUImageVideoViewController *gpuImageVc = [[UseGPUImageVideoViewController   alloc] init];
    gpuImageVc.isRecord = NO;
    [self presentViewController:gpuImageVc animated:YES completion:nil];
}
- (IBAction)GPUImageRecordBtnClick:(id)sender {
    UseGPUImageVideoViewController *gpuImageVc = [[UseGPUImageVideoViewController   alloc] init];
    gpuImageVc.isRecord = YES;
    [self presentViewController:gpuImageVc animated:YES completion:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
