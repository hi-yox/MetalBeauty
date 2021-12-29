//
//  RTCVideoCapturer.h
//  DCCoreImage
//
//  Created by jfdreamyang on 2019/8/12.
//  Copyright © 2019 LiveMe. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "MTImageEngine.h"

NS_ASSUME_NONNULL_BEGIN

/**
 前后摄像头枚举
 */
typedef NS_OPTIONS(NSUInteger, LVRTCCameraPosition) {
    /**
        前置摄像头
     */
    LVRTCCameraPositionFront,
    /**
        后置摄像头
     */
    LVRTCCameraPositionBack,
};


/**
 视频编码参数
 */
typedef NS_ENUM(NSInteger, LVRTCVideoProfile) {
    /**
        320x180   15   300
     */
    LVRTCVideoProfile_180P = 0,
    /**
        480x270   15   500
     */
    LVRTCVideoProfile_270P = 1,
    /**
        640x360   15   800
     */
    LVRTCVideoProfile_360P = 2,
    /**
        640x480   15   1000
     */
    LVRTCVideoProfile_480P = 3,
    /**
        960x540    15   1200
     */
    LVRTCVideoProfile_540P = 4,
    /**
        1280x720  15   1800
     */
    LVRTCVideoProfile_720P = 5,
    /**
        1920x1080  15   2400， 手机端暂不支持 1080P 视频走 RTC，请不要支持使用
     */
    LVRTCVideoProfile_1080P = 6
};

@protocol CMRTCCapturerDelegate <NSObject>

@optional
-(void)handleVideoFrame:(CMSampleBufferRef)sampleBuffer rotation:(LVVideoRotation)rotation isFaceCamera:(BOOL)isFaceCamera;
@end


@interface CMRTCCapturer : NSObject
+(CMRTCCapturer *)sharedCapturer;

/// 是否正在运行中
@property (atomic,assign)BOOL isRunning;

/**
 设置采集回调代理
 */
@property (nonatomic,weak)id <CMRTCCapturerDelegate> delegate;

/**
 设置视频采集 profile，默认为 DIVideoProfile_720P
 */
@property LVRTCVideoProfile profile;

/**
 是否使用前置摄像头
 */
@property LVRTCCameraPosition cameraPosition;

/**
 设置视频采集方向
 */
@property (nonatomic) AVCaptureVideoOrientation orientation;

#if TARGET_OS_IOS
/**
 设备方向
 */
@property (nonatomic) UIDeviceOrientation deviceOrientation;


/// 当前 statusBar 的方向
@property (nonatomic,readonly) UIInterfaceOrientation statusBarOrientation;
#endif

/**
 单独设置视频帧率
 */
@property (nonatomic)int framerate;

/**
 开始采集
 */
-(void)startCapture;

/**
 停止采集
 */
-(void)stopCapture;

/**
 切换摄像头
 */
-(void)switchCamera:(LVRTCCameraPosition)position;

/// 初始化摄像头参数
/// @param cameraName 摄像头名词
/// @param colorFormat 颜色格式
/// @param width 视频分辨率宽
/// @param height 视频分辨率高
-(void)InitCameraCapture:(NSString *)cameraName colorFormat:(NSString *)colorFormat width:(int)width height:(int)height;

@end

NS_ASSUME_NONNULL_END
