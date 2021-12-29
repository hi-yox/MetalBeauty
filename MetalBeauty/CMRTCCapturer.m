//
//  RTCVideoCapturer.m
//  DCCoreImage
//
//  Created by jfdreamyang on 2019/8/12.
//  Copyright © 2019 LiveMe. All rights reserved.
//

#import "CMRTCCapturer.h"
#import "CMRTCCapturer+Private.h"
#import <AVFoundation/AVFoundation.h>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
#endif

BOOL CFStringContainsString(CFStringRef theString, CFStringRef stringToFind) {
  return CFStringFindWithOptions(theString,
                                 stringToFind,
                                 CFRangeMake(0, CFStringGetLength(theString)),
                                 kCFCompareCaseInsensitive,
                                 nil);
}

@implementation AVCaptureSession (DevicePosition)

+ (AVCaptureDevicePosition)cmdevicePositionForSampleBuffer:(CMSampleBufferRef)sampleBuffer {
  // Check the image's EXIF for the camera the image came from.
  AVCaptureDevicePosition cameraPosition = AVCaptureDevicePositionUnspecified;
  CFDictionaryRef attachments = CMCopyDictionaryOfAttachments(
      kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate);
  if (attachments) {
    int size = CFDictionaryGetCount(attachments);
    if (size > 0) {
      CFDictionaryRef cfExifDictVal = nil;
      if (CFDictionaryGetValueIfPresent(
              attachments, (const void *)CFSTR("{Exif}"), (const void **)&cfExifDictVal)) {
        CFStringRef cfLensModelStrVal;
        if (CFDictionaryGetValueIfPresent(cfExifDictVal,
                                          (const void *)CFSTR("LensModel"),
                                          (const void **)&cfLensModelStrVal)) {
          if (CFStringContainsString(cfLensModelStrVal, CFSTR("front"))) {
            cameraPosition = AVCaptureDevicePositionFront;
          } else if (CFStringContainsString(cfLensModelStrVal, CFSTR("back"))) {
            cameraPosition = AVCaptureDevicePositionBack;
          }
        }
      }
    }
    CFRelease(attachments);
  }
  return cameraPosition;
}

@end






@interface CMRTCCapturer ()<AVCaptureVideoDataOutputSampleBufferDelegate>
{
    AVCaptureVideoDataOutput *_videoDataOutput;
    AVCaptureSession *_captureSession;
    AVCaptureDevice *_currentDevice;
    FourCharCode _outputPixelFormat;
    BOOL _hasRetriedOnFatalError;
    long long _lastOutputTimeMs;
    
    NSString *_mCameraName;
    NSString *_mColorFormat;
    int _mWidth;
    int _mHeight;
    
    AVCaptureDevice *_mCurrentDevice;
    
    bool _mAudoControlCamera;
}
@property (readonly)FourCharCode preferredOutputPixelFormat;
@property (nonatomic,strong)dispatch_queue_t frameQueue;
@property (nonatomic,strong)dispatch_queue_t captureSessionQueue;
/// 仅用来表示当前摄像头是否可用
@property (nonatomic,assign)BOOL cameraEnable;
@end


@implementation CMRTCCapturer

@synthesize delegate = _delegate;
@synthesize profile = _profile;
@synthesize cameraPosition = _cameraPosition;
@synthesize orientation = _orientation;
#if TARGET_OS_IOS
@synthesize deviceOrientation = _deviceOrientation;
@synthesize statusBarOrientation = _statusBarOrientation;
#endif
@synthesize framerate = _framerate;
@synthesize preferredOutputPixelFormat = _preferredOutputPixelFormat;
@synthesize frameQueue = _frameQueue;
@synthesize captureSessionQueue = _captureSessionQueue;
@synthesize cameraEnable = _cameraEnable;
@synthesize isRunning = _isRunning;


+(CMRTCCapturer *)sharedCapturer{
    static CMRTCCapturer *_capturer;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _capturer = [[CMRTCCapturer alloc]init];
        [_capturer configure];
    });
    return _capturer;
}

-(void)configure{
    _cameraPosition = LVRTCCameraPositionFront;
    _framerate = 0;
    _profile = LVRTCVideoProfile_480P;
    _frameQueue = dispatch_queue_create("com.jfdream.imagecamera.queue", DISPATCH_QUEUE_SERIAL);
    _captureSessionQueue = dispatch_queue_create("com.jfdream.imagecamera.queue.session", DISPATCH_QUEUE_SERIAL);
    _orientation = AVCaptureVideoOrientationPortrait;
    _lastOutputTimeMs = 0;
    _mCurrentDevice = nil;
    [self confirmOrientation];
    
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
#if TARGET_OS_IOS
    [center addObserver:self
               selector:@selector(deviceOrientationDidChange:)
                   name:UIDeviceOrientationDidChangeNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(handleCaptureSessionInterruption:)
                   name:AVCaptureSessionWasInterruptedNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(handleCaptureSessionInterruptionEnded:)
                   name:AVCaptureSessionInterruptionEndedNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(handleApplicationDidBecomeActive:)
                   name:UIApplicationDidBecomeActiveNotification
                 object:[UIApplication sharedApplication]];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    });
    

#endif
    [center addObserver:self
               selector:@selector(handleCaptureSessionRuntimeError:)
                   name:AVCaptureSessionRuntimeErrorNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(handleCaptureSessionDidStartRunning:)
                   name:AVCaptureSessionDidStartRunningNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(handleCaptureSessionDidStopRunning:)
                   name:AVCaptureSessionDidStopRunningNotification
                 object:nil];
    
}

-(void)startCapture{
    [self confirmOrientation];
    _cameraEnable = YES;
    __weak CMRTCCapturer *weakSelf = self;
    dispatch_async(self.captureSessionQueue, ^{
        __strong CMRTCCapturer*strongSelf = weakSelf;
        if (strongSelf) {
            [strongSelf _startCapture];
        }
    });
}

-(void)_startCapture{
    AVCaptureDevicePosition position =
    _cameraPosition == LVRTCCameraPositionFront ? AVCaptureDevicePositionFront : AVCaptureDevicePositionBack;
    AVCaptureDevice *device = _mCurrentDevice ? _mCurrentDevice : [self findDeviceForPosition:position];
    AVCaptureDeviceFormat *format = [self selectFormatForDevice:device];
    if (format == nil) {
        NSLog(@"No valid formats for device %@", device);
        return;
    }
    _currentDevice = device;
    NSError *error = nil;
    [_captureSession stopRunning];
    if (![_currentDevice lockForConfiguration:&error]) {
        NSLog(@"Failed to lock device %@. Error: %@", _currentDevice, error.userInfo);
        return;
    }
    NSInteger fps = _framerate > 0 ? _framerate : [CMRTCCapturer frame:_profile];
    if (!_captureSession) {
        AVCaptureSession *session = [[AVCaptureSession alloc]init];
        [self setupCaptureSession:session];
    }
    NSLog(@"startCaptureWithDevice %@ @ %ld fps", format, (long)fps);
    [self reconfigureCaptureSessionInput];
    _framerate = 0;
    
#if TARGET_OS_OSX
    [self updateDeviceCaptureFormat:format fps:fps];
#endif
    [self updateVideoDataOutputPixelFormat:format];
    
    AVCaptureConnection *connection = [_videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
    connection.videoOrientation = _orientation;

    [_currentDevice unlockForConfiguration];
    [_captureSession startRunning];
#if TARGET_OS_IOS
    [self updateDeviceCaptureFormat:format fps:fps];
#endif
    self.isRunning = YES;
}

-(void)confirmOrientation{
#if TARGET_OS_IOS
    UIInterfaceOrientation orientation =     UIApplication.sharedApplication.statusBarOrientation;
    
    switch (orientation) {
        case UIInterfaceOrientationPortrait:
            _deviceOrientation = UIDeviceOrientationPortrait;
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            _deviceOrientation = UIDeviceOrientationPortraitUpsideDown;
            break;
        case UIInterfaceOrientationLandscapeLeft:
            _deviceOrientation = UIDeviceOrientationLandscapeRight;
            break;
        case UIInterfaceOrientationLandscapeRight:
            _deviceOrientation = UIDeviceOrientationLandscapeLeft;
            break;
        default:
            _deviceOrientation = UIDeviceOrientationUnknown;
            break;
    }
    BOOL notFound = NO;
    if (_deviceOrientation == UIDeviceOrientationUnknown) {
        _deviceOrientation = UIDeviceOrientationPortrait;
        notFound = YES;
    }
    LV_LOGI(@"deviceOrientation: %@, notFound:%@", @(_deviceOrientation), @(notFound));
#endif
}


-(void)setOrientation:(AVCaptureVideoOrientation)orientation{
    _orientation = orientation;
    __weak CMRTCCapturer *weakSelf = self;
    dispatch_async(self.captureSessionQueue, ^{
        CMRTCCapturer *strongSelf = weakSelf;
        AVCaptureConnection *connection = [strongSelf->_videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
        connection.videoOrientation = orientation;
    });
}

-(void)stopCapture{
    __weak CMRTCCapturer *weakSelf = self;
    _cameraEnable = NO;
    dispatch_async(self.captureSessionQueue, ^{
        CMRTCCapturer *strongSelf = weakSelf;
        NSLog(@"Stop");
        if (strongSelf->_currentDevice == nil) {
            return;
        }
        strongSelf->_currentDevice = nil;
        for (AVCaptureDeviceInput *oldInput in [strongSelf->_captureSession.inputs copy]) {
            [strongSelf->_captureSession removeInput:oldInput];
        }
        [strongSelf->_captureSession stopRunning];
#if TARGET_OS_IOS
        dispatch_async(dispatch_get_main_queue(), ^{
            [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
        });
#endif
        strongSelf.isRunning = NO;
        strongSelf->_captureSession = nil;
        strongSelf->_videoDataOutput = nil;
        
    });
    
}

-(void)switchCamera:(LVRTCCameraPosition)position{
    _cameraPosition = position;
    _framerate = 0;
    [self startCapture];
}

- (void)updateVideoDataOutputPixelFormat:(AVCaptureDeviceFormat *)format {
    FourCharCode mediaSubType = CMFormatDescriptionGetMediaSubType(format.formatDescription);
    if (![[CMRTCCapturer supportedPixelFormats] containsObject:@(mediaSubType)]) {
        mediaSubType = _preferredOutputPixelFormat;
    }
    
    if (mediaSubType != _outputPixelFormat) {
        _outputPixelFormat = mediaSubType;
        _videoDataOutput.videoSettings =
        @{ (NSString *)kCVPixelBufferPixelFormatTypeKey : @(mediaSubType), (NSString *)kCVPixelBufferMetalCompatibilityKey : @(TRUE)};
    }
}

- (void)updateDeviceCaptureFormat:(AVCaptureDeviceFormat *)format fps:(NSInteger)fps {
#if TARGET_OS_OSX
    _currentDevice.activeFormat = format;
#endif
    [self updateFrameRate:fps];
}

-(void)reconfigureCaptureSessionInput{
    NSError *error = nil;
    AVCaptureDeviceInput *input =
    [AVCaptureDeviceInput deviceInputWithDevice:_currentDevice error:&error];
    if (!input) {
        NSLog(@"Failed to create front camera input: %@", error.localizedDescription);
        return;
    }
    [_captureSession beginConfiguration];
    for (AVCaptureDeviceInput *oldInput in [_captureSession.inputs copy]) {
        [_captureSession removeInput:oldInput];
    }
    if ([_captureSession canAddInput:input]) {
        [_captureSession addInput:input];
    } else {
        NSLog(@"Cannot add camera as an input to the session.");
    }
    [_captureSession commitConfiguration];
}

-(void)setFramerate:(int)framerate{
    if (_framerate == framerate) return;
    _framerate = framerate;
    __weak CMRTCCapturer *weakSelf = self;
    dispatch_async(self.captureSessionQueue, ^{
        CMRTCCapturer *strongSelf = weakSelf;
        if (!strongSelf->_currentDevice) {
            NSLog(@"Device not launch, ignore");
            return;
        }
        NSError *error;
        if (![strongSelf->_currentDevice lockForConfiguration:&error]) {
            NSLog(@"Cannot set activeVideoMinFrameDuration,%@",error);
            return;
        }
        [strongSelf updateFrameRate:framerate];
        [strongSelf->_currentDevice unlockForConfiguration];
    });
}

-(void)updateFrameRate:(int)framerate{
    if (_framerate == framerate) return;
    _framerate = framerate;
    @try {
#if TARGET_OS_IOS
        _currentDevice.activeVideoMinFrameDuration = CMTimeMake(1, (int32_t)framerate);
        _currentDevice.activeVideoMaxFrameDuration = CMTimeMake(1, (int32_t)framerate);
#else
        float min = 99999999;
        AVFrameRateRange *trange = nil;
        AVCaptureDeviceFormat *activeFormat = _currentDevice.activeFormat;
        for (AVFrameRateRange *range in activeFormat.videoSupportedFrameRateRanges) {
            if (fabs(range.maxFrameRate - framerate) < min) {
                trange = range;
                min = fabs(range.maxFrameRate - framerate);
            }
        }
        if (trange) {
            _currentDevice.activeVideoMinFrameDuration = trange.minFrameDuration;
            _currentDevice.activeVideoMaxFrameDuration = trange.maxFrameDuration;
        }
#endif
    } @catch (NSException *exception) {
        
        NSLog(@"activeVideoMinFrameDuration:%@,activeVideoMaxFrameDuration:%@",[NSValue valueWithCMTime:_currentDevice.activeVideoMinFrameDuration],[NSValue valueWithCMTime:_currentDevice.activeVideoMaxFrameDuration]);
        
        NSLog(@"Failed to set active format! User info:%@", exception);
    }
}

-(BOOL)setupCaptureSession:(AVCaptureSession *)captureSession{
    NSAssert(_captureSession == nil, @"Setup capture session called twice.");
    _captureSession = captureSession;
#if defined(WEBRTC_IOS)
    _captureSession.sessionPreset = AVCaptureSessionPresetInputPriority;
    _captureSession.usesApplicationAudioSession = NO;
#endif
    [self setupVideoDataOutput];
    // Add the output.
    if (![_captureSession canAddOutput:_videoDataOutput]) {
        NSLog(@"Video data output unsupported.");
        return NO;
    }
    [_captureSession addOutput:_videoDataOutput];
    return YES;
}
- (void)setupVideoDataOutput {
    NSAssert(_videoDataOutput == nil, @"Setup video data output called twice.");
    AVCaptureVideoDataOutput *videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    
    // `videoDataOutput.availableVideoCVPixelFormatTypes` returns the pixel formats supported by the
    // device with the most efficient output format first. Find the first format that we support.
    NSSet<NSNumber *> *supportedPixelFormats = [CMRTCCapturer supportedPixelFormats];
    NSMutableOrderedSet *availablePixelFormats =
    [NSMutableOrderedSet orderedSetWithArray:videoDataOutput.availableVideoCVPixelFormatTypes];
    [availablePixelFormats intersectSet:supportedPixelFormats];
    NSNumber *pixelFormat = availablePixelFormats.firstObject;
    NSAssert(pixelFormat, @"Output device has no supported formats.");
    _preferredOutputPixelFormat = [pixelFormat unsignedIntValue];
    NSLog(@"OutputPixelFormat:%@",[CMRTCCapturer CVPixelBufferFormat:[pixelFormat integerValue]]);
    _outputPixelFormat = _preferredOutputPixelFormat;
    videoDataOutput.videoSettings = @{(NSString *)kCVPixelBufferPixelFormatTypeKey : pixelFormat, (NSString *)kCVPixelBufferMetalCompatibilityKey : @(TRUE)};
    videoDataOutput.alwaysDiscardsLateVideoFrames = NO;
    [videoDataOutput setSampleBufferDelegate:self queue:self.frameQueue];
    _videoDataOutput = videoDataOutput;
}

-(void)InitCameraCapture:(NSString *)cameraName colorFormat:(NSString *)colorFormat width:(int)width height:(int)height{
    _mCameraName = cameraName;
    _mColorFormat = colorFormat;
    _mWidth = width;
    _mHeight = height;
    NSLog(@"InitCameraCapture: %@, colorFormat:%@, width:%@, height:%@", _mCameraName, _mColorFormat, @(_mWidth), @(_mHeight));
    _mAudoControlCamera = YES;
    _mCurrentDevice = [CMRTCCapturer captureDeviceByName:cameraName];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection{
    NSParameterAssert(captureOutput == _videoDataOutput);
    
    if (CMSampleBufferGetNumSamples(sampleBuffer) != 1 || !CMSampleBufferIsValid(sampleBuffer) ||
        !CMSampleBufferDataIsReady(sampleBuffer)) {
        return;
    }
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (pixelBuffer == nil || !self.isRunning) return;
    LVVideoRotation _rotation = LVVideoRotation_0;
    // Default to portrait orientation on iPhone.
    BOOL usingFrontCamera = NO;
#if TARGET_OS_IOS
    // Check the image's EXIF for the camera the image came from as the image could have been
    // delayed as we set alwaysDiscardsLateVideoFrames to NO.
    AVCaptureDevicePosition cameraPosition =
    [AVCaptureSession cmdevicePositionForSampleBuffer:sampleBuffer];
    if (cameraPosition != AVCaptureDevicePositionUnspecified) {
        usingFrontCamera = AVCaptureDevicePositionFront == cameraPosition;
    } else {
        AVCaptureDeviceInput *deviceInput =
        (AVCaptureDeviceInput *)((AVCaptureInputPort *)connection.inputPorts.firstObject).input;
        usingFrontCamera = AVCaptureDevicePositionFront == deviceInput.device.position;
    }

    BOOL isFrontCamera = (LVRTCCameraPositionFront == _cameraPosition);
    if (usingFrontCamera != isFrontCamera) {
        return;
    }
    
    switch (_deviceOrientation) {
        case UIDeviceOrientationPortrait:
            _rotation = LVVideoRotation_0;
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            _rotation = LVVideoRotation_180;
            break;
        case UIDeviceOrientationLandscapeLeft:
            _rotation = usingFrontCamera ? LVVideoRotation_90 : LVVideoRotation_270;
            break;
        case UIDeviceOrientationLandscapeRight:
            _rotation = usingFrontCamera ? LVVideoRotation_270 : LVVideoRotation_90;
            break;
        case UIDeviceOrientationFaceUp:
        case UIDeviceOrientationFaceDown:
        case UIDeviceOrientationUnknown:
            // Ignore.
            break;
    }
#else
    // No rotation on Mac. 
    _rotation = LVVideoRotation_0;
    usingFrontCamera = YES;
#endif
    _lastOutputTimeMs = [NSDate date].timeIntervalSince1970 * 1000;
    [self.delegate handleVideoFrame:sampleBuffer rotation:_rotation isFaceCamera:usingFrontCamera];
}


#pragma mark NSSessionNotificationCenter
-(void)deviceOrientationDidChange:(NSNotification *)notification{
#if TARGET_OS_IOS
    _deviceOrientation =  [UIDevice currentDevice].orientation;
#endif
}

-(void)handleCaptureSessionInterruption:(NSNotification *)notification{
    NSLog(@"handleCaptureSessionInterruption:%@",notification);
}

-(void)handleCaptureSessionInterruptionEnded:(NSNotification *)notification{
    NSLog(@"handleCaptureSessionInterruption:%@",notification);
}

-(void)handleApplicationDidBecomeActive:(NSNotification *)notification{
    if (!self.cameraEnable) return;
    __weak CMRTCCapturer *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        long long now = NSDate.date.timeIntervalSince1970 * 1000;
        __strong CMRTCCapturer*strongSelf = weakSelf;
        if (now - strongSelf->_lastOutputTimeMs > 1500) {
            [strongSelf _startCapture];
        }
    });
}

-(void)handleCaptureSessionRuntimeError:(NSNotification *)notification{
    NSLog(@"handleCaptureSessionRuntimeError:%@",notification);
}

-(void)handleCaptureSessionDidStartRunning:(NSNotification *)notification{
    
}

-(void)handleCaptureSessionDidStopRunning:(NSNotification *)notification{
    
}

@end
