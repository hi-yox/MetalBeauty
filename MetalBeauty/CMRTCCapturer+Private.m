//
//  RTCVideoCapturer+Private.m
//  DCCoreImage
//
//  Created by jfdreamyang on 2019/8/12.
//  Copyright © 2019 LiveMe. All rights reserved.
//

#import "CMRTCCapturer+Private.h"

@interface CMRTCCapturer (PrivateInternal)
@property (readonly)FourCharCode preferredOutputPixelFormat;
@end


@implementation CMRTCCapturer (Private)

#pragma mark - Private

+(NSInteger)bitRate:(LVRTCVideoProfile)videoProfile{
    return [[self configure:videoProfile].firstObject integerValue];
}

+(NSInteger)frame:(LVRTCVideoProfile)videoProfile{
    return [[self configure:videoProfile][1] integerValue];
}

+(NSString *)resolution:(LVRTCVideoProfile)videoProfile{
    return [self configure:videoProfile][2];
}
+(CGSize)resolutionSize:(LVRTCVideoProfile)videoProfile{
    NSString *size = [self resolution:videoProfile];
    NSArray *res = [size componentsSeparatedByString:@"x"];
    return CGSizeMake([res[0] floatValue], [res[1] floatValue]);
}

//+(CGSize)adapterCaptureResolution:(CGSize)encodeSize{
//    CGSize frameSize = [CMRTCCapturer resolutionSize:[CMRTCCapturer sharedCapturer].profile];
//    frameSize = CGSizeMake(frameSize.height, frameSize.width);
//    CGRect insetRect = AVMakeRectWithAspectRatioInsideRect(encodeSize, CGRectMake(0, 0, frameSize.width, frameSize.height));
//    return insetRect.size;
//}

+(CGSize)adapterCaptureResolution:(CGSize)encodeSize size:(CGSize)frameSize{
    CGRect insetRect = AVMakeRectWithAspectRatioInsideRect(encodeSize, CGRectMake(0, 0, frameSize.width, frameSize.height));
    return insetRect.size;
}

+(NSArray *)configure:(LVRTCVideoProfile)videoProfile{
    NSInteger bitRate = 0, frame = 0;
    NSString * resolution = @"";
    switch (videoProfile) {
        case LVRTCVideoProfile_180P:{
            resolution = @"320x180";
            frame = 15;
            bitRate = 300;
        }
            break;
        case LVRTCVideoProfile_270P:{
            resolution = @"480x270";
            frame = 15;
            bitRate = 500;
        }
            break;
        case LVRTCVideoProfile_360P:{
            resolution = @"640x360";
            frame = 15;
            bitRate = 800;
        }
            break;
//        case LVRTCVideoProfile_368P:{
//            resolution = @"640x368";
//            frame = 15;
//            bitRate = 410;
//        }
//            break;
        case LVRTCVideoProfile_480P:{
            resolution = @"640x480";
            frame = 15;
            bitRate = 1000;
        }
            break;
        case LVRTCVideoProfile_540P:{
            resolution = @"960x540";
            frame = 15;
            bitRate = 1200;
        }
            break;
            
        case LVRTCVideoProfile_720P:{
            resolution = @"1280x720";
            frame = 15;
            bitRate = 1800;
        }
            break;
        case LVRTCVideoProfile_1080P:{
            resolution = @"1920x1080";
            frame = 15;
            bitRate = 2400;
        }
            break;
        default:{
            resolution = @"960x540";
            frame = 15;
            bitRate = 1200;
        }
            break;
    }
    return @[@(bitRate),@(frame),resolution];
}

+ (NSSet<NSNumber*>*)supportedPixelFormats {
    int a = 0;
    if (a == 0) {
        return [NSSet setWithObjects:@(kCVPixelFormatType_32BGRA), nil];
    }
    return [NSSet setWithObjects:
            @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange),
            @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
            @(kCVPixelFormatType_32BGRA),
            @(kCVPixelFormatType_32ARGB),
            nil];
}

+(NSString *)CVPixelBufferFormat:(NSInteger)type{
    NSDictionary <NSNumber *,NSString *>*defaultFormats = @{@(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange):@"kCVPixelFormatType_420YpCbCr8BiPlanarFullRange",@(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange):@"kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange",@(kCVPixelFormatType_32BGRA):@"kCVPixelFormatType_32BGRA",@(kCVPixelFormatType_32ARGB):@"kCVPixelFormatType_32ARGB"};
    return defaultFormats[[NSNumber numberWithInteger:type]];
}


- (AVCaptureDevice *)findDeviceForPosition:(AVCaptureDevicePosition)position {
    NSArray<AVCaptureDevice *> *captureDevices = [CMRTCCapturer captureDevices];
    for (AVCaptureDevice *device in captureDevices) {
        if (device.position == position) {
            return device;
        }
    }
    return captureDevices[0];
}

+ (NSArray<AVCaptureDeviceFormat *> *)supportedFormatsForDevice:(AVCaptureDevice *)device {
    // Support opening the device in any format. We make sure it's converted to a format we
    // can handle, if needed, in the method `-setupVideoDataOutput`.
    return device.formats;
}

- (AVCaptureDeviceFormat *)selectFormatForDevice:(AVCaptureDevice *)device {
    
    NSArray<AVCaptureDeviceFormat *> *formats = [CMRTCCapturer supportedFormatsForDevice:device];
    NSString *s = [CMRTCCapturer resolution:self.profile];
    int targetWidth = [self videoResolutionComponentAtIndex:0 inString:s];
    int targetHeight = [self videoResolutionComponentAtIndex:1 inString:s];
    AVCaptureDeviceFormat *selectedFormat = nil;
    int currentDiff = INT_MAX;
    
    for (AVCaptureDeviceFormat *format in formats) {
        if (true) {
            FourCharCode mediaSubType = CMFormatDescriptionGetMediaSubType(format.formatDescription);
            if (mediaSubType != kCVPixelFormatType_32BGRA) {
                continue;
            }
        }
        CMVideoDimensions dimension = CMVideoFormatDescriptionGetDimensions(format.formatDescription);
        FourCharCode pixelFormat = CMFormatDescriptionGetMediaSubType(format.formatDescription);
        int diff = abs(targetWidth - dimension.width) + abs(targetHeight - dimension.height);
        if (diff < currentDiff) {
            selectedFormat = format;
            currentDiff = diff;
        } else if (diff == currentDiff && pixelFormat == self.preferredOutputPixelFormat) {
            selectedFormat = format;
        }
    }
    
    if (!selectedFormat) {
        for (AVCaptureDeviceFormat *format in formats) {
            CMVideoDimensions dimension = CMVideoFormatDescriptionGetDimensions(format.formatDescription);
            FourCharCode pixelFormat = CMFormatDescriptionGetMediaSubType(format.formatDescription);
            int diff = abs(targetWidth - dimension.width) + abs(targetHeight - dimension.height);
            if (diff < currentDiff) {
                selectedFormat = format;
                currentDiff = diff;
            } else if (diff == currentDiff && pixelFormat == self.preferredOutputPixelFormat) {
                selectedFormat = format;
            }
        }
    }
    return selectedFormat;
}
- (int)videoResolutionComponentAtIndex:(int)index inString:(NSString *)resolution {
    if (index != 0 && index != 1) {
        return 0;
    }
    NSArray<NSString *> *components = [resolution componentsSeparatedByString:@"x"];
    if (components.count != 2) {
        return 0;
    }
    return components[index].intValue;
}

+ (NSArray<NSValue *> *)availableVideoResolutions:(NSString *)cameraName{
    NSMutableArray<NSValue *> *resolutions = [[NSMutableArray alloc] init];
    
    NSMutableSet *exceptList = [[NSMutableSet alloc]init];
    
    for (AVCaptureDevice *device in [CMRTCCapturer captureDevices]) {
        if ([device.localizedName isEqualToString:cameraName]) {
            for (AVCaptureDeviceFormat *format in [CMRTCCapturer supportedFormatsForDevice:device]) {
                CMVideoDimensions resolution = CMVideoFormatDescriptionGetDimensions(format.formatDescription);
                NSString *s = [NSString stringWithFormat:@"%dx%d", resolution.width, resolution.height];
                if ([exceptList containsObject:s]) {
                    continue;
                }
                
                [exceptList addObject:s];

#if TARGET_OS_IOS
                NSValue *value = [NSValue valueWithCGSize:CGSizeMake(resolution.width, resolution.height)];
#else
                NSValue *value = [NSValue valueWithSize:CGSizeMake(resolution.width, resolution.height)];
#endif
                [resolutions addObject:value];
            }
            break;
        }
    }
    return resolutions;
}

+ (AVCaptureDevice *)captureDeviceByName:(NSString *)cameraName{
    for (AVCaptureDevice *device in [CMRTCCapturer captureDevices]) {
        if ([device.localizedName isEqualToString:cameraName]) {
            return device;
        }
    }
    return nil;
}

+ (NSArray<NSString *> *)GetCameraColorType:(NSString *)cameraName{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wunguarded-availability"
    NSMutableSet<NSString *> *resolutions = [[NSMutableSet alloc] init];
    for (AVCaptureDevice *device in [CMRTCCapturer captureDevices]) {
        if ([device.localizedName isEqualToString:cameraName]) {
            for (AVCaptureDeviceFormat *format in [CMRTCCapturer supportedFormatsForDevice:device]) {
                for (NSNumber *v in format.supportedColorSpaces) {
                    NSString *pixelFormat = [NSString stringWithFormat:@"%@", v];
                    [resolutions addObject:pixelFormat];
                }
            }
            break;
        }
    }
#pragma clang diagnostic pop
    return resolutions.allObjects;
}

- (NSArray<NSString *> *)availableVideoResolutions {
    NSMutableSet<NSArray<NSNumber *> *> *resolutions =
    [[NSMutableSet<NSArray<NSNumber *> *> alloc] init];
    for (AVCaptureDevice *device in [CMRTCCapturer captureDevices]) {
        for (AVCaptureDeviceFormat *format in
             [CMRTCCapturer supportedFormatsForDevice:device]) {
            CMVideoDimensions resolution =
            CMVideoFormatDescriptionGetDimensions(format.formatDescription);
            NSArray<NSNumber *> *resolutionObject = @[ @(resolution.width), @(resolution.height) ];
            [resolutions addObject:resolutionObject];
        }
    }
    
    NSArray<NSArray<NSNumber *> *> *sortedResolutions =
    [[resolutions allObjects] sortedArrayUsingComparator:^NSComparisonResult(
                                                                             NSArray<NSNumber *> *obj1, NSArray<NSNumber *> *obj2) {
        return obj1.firstObject > obj2.firstObject;
    }];
    
    NSMutableArray<NSString *> *resolutionStrings = [[NSMutableArray<NSString *> alloc] init];
    for (NSArray<NSNumber *> *resolution in sortedResolutions) {
        NSString *resolutionString =
        [NSString stringWithFormat:@"%@x%@", resolution.firstObject, resolution.lastObject];
        [resolutionStrings addObject:resolutionString];
    }
    
    return [resolutionStrings copy];
}

+ (NSArray<AVCaptureDevice *> *)audioCaptureDevices{
#if defined(WEBRTC_IOS) && defined(__IPHONE_10_0) && \
__IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_10_0
#if TARGET_OS_OSX
    AVCaptureDeviceDiscoverySession *session = [AVCaptureDeviceDiscoverySession
                                                discoverySessionWithDeviceTypes:@[ AVCaptureDeviceTypeBuiltInMicrophone, AVCaptureDeviceTypeExternalUnknown]
                                                mediaType:AVMediaTypeAudio
                                                position:AVCaptureDevicePositionUnspecified];
#else
    AVCaptureDeviceDiscoverySession *session = [AVCaptureDeviceDiscoverySession
                                                discoverySessionWithDeviceTypes:@[ AVCaptureDeviceTypeBuiltInMicrophone]
                                                mediaType:AVMediaTypeAudio
                                                position:AVCaptureDevicePositionUnspecified];
#endif
    return session.devices;
#else
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio];
#pragma clang diagnostic pop
    
#endif
}

+ (NSArray<AVCaptureDevice *> *)captureDevices {
#if defined(WEBRTC_IOS) && defined(__IPHONE_10_0) && \
__IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_10_0
    AVCaptureDeviceDiscoverySession *session = [AVCaptureDeviceDiscoverySession
                                                discoverySessionWithDeviceTypes:@[ AVCaptureDeviceTypeBuiltInWideAngleCamera ]
                                                mediaType:AVMediaTypeVideo
                                                position:AVCaptureDevicePositionUnspecified];
    return session.devices;
#else
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
#pragma clang diagnostic pop
    
#endif
}

@end
