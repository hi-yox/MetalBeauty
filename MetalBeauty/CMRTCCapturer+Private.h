//
//  RTCVideoCapturer+Private.h
//  DCCoreImage
//
//  Created by jfdreamyang on 2019/8/12.
//  Copyright © 2019 LiveMe. All rights reserved.
//

#import "CMRTCCapturer.h"

NS_ASSUME_NONNULL_BEGIN

@interface CMRTCCapturer (Private)
- (AVCaptureDevice *)findDeviceForPosition:(AVCaptureDevicePosition)position;
- (AVCaptureDeviceFormat *)selectFormatForDevice:(AVCaptureDevice *)device;

+ (NSInteger)frame:(LVRTCVideoProfile)videoProfile;
+ (NSInteger)bitRate:(LVRTCVideoProfile)videoProfile;

/// 通过 videoProfile 获取分辨率大小
/// @param videoProfile 分辨率大小
+ (CGSize)resolutionSize:(LVRTCVideoProfile)videoProfile;

/// 支持像素格式
+ (NSSet<NSNumber*>*)supportedPixelFormats;

/// 通过编码分辨找到当前最到视频分辨率
/// @param encodeSize 编码分辨率大小
//+ (CGSize)adapterCaptureResolution:(CGSize)encodeSize;


+ (CGSize)adapterCaptureResolution:(CGSize)encodeSize size:(CGSize)size;


+(NSString *)CVPixelBufferFormat:(NSInteger)type;


+ (NSArray<AVCaptureDevice *> *)captureDevices;

+ (NSArray<AVCaptureDevice *> *)audioCaptureDevices;

+ (NSArray<NSValue *> *)availableVideoResolutions:(NSString *)cameraName;

+ (NSArray<NSString *> *)GetCameraColorType:(NSString *)cameraName;

+ (AVCaptureDevice *)captureDeviceByName:(NSString *)cameraName;

@end

NS_ASSUME_NONNULL_END
