//
//  ViewController.m
//  MetalBeauty
//
//  Created by badwin on 2021/12/14.
//

#import "ViewController.h"
#import "MTImageEngine.h"
#import "MTView.h"
#import "CMRTCCapturer.h"

@interface ViewController ()<CMRTCCapturerDelegate>

@end

@implementation ViewController
{
    MTView *content;
}
- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.
    
    CMRTCCapturer.sharedCapturer.delegate = self;
    [CMRTCCapturer.sharedCapturer startCapture];
    
    content = [[MTView alloc]initWithFrame:CGRectMake(0, 0, 1280, 720)];
    [self.view addSubview:content];
    
    [[MTImageEngine sharedManager] setObject:content forKey:kLVRTCLocalView];
}
-(void)handleVideoFrame:(CMSampleBufferRef)sampleBuffer rotation:(LVVideoRotation)rotation isFaceCamera:(BOOL)isFaceCamera{
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    [[MTImageEngine sharedManager] display:pixelBuffer isFaceCamera:NO rotation:(LVVideoRotation_0) cropToSize:CGSizeMake(1280, 720) scaleToSize:CGSizeMake(1280, 720) completion:^(CVPixelBufferRef  _Nonnull pixelBuffer) {

        NSLog(@"%@", pixelBuffer);
    }];
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}


@end
