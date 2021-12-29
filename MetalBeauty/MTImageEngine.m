//
//  MTImageEngine.m
//  products
//
//  Created by jfdreamyang on 2020/4/9.
//

#import "MTImageEngine.h"
#import "MTImage.h"
#import "MTView.h"
#import "MTShaders.h"

NSString *const kLVRTCLocalView = @"cm_rtc_local_view";

NSString *const commandBufferLabel = @"RTCCommandBuffer";
NSString *const renderEncoderLabel = @"RTCEncoder";
NSString *const renderEncoderDebugGroup = @"RTCDrawFrame";
// As defined in shaderSource.
NSString *const vertexFunctionName = @"vertexPassthrough";
NSString *const fragmentFunctionName = @"fragmentColorConversion";
NSString *const pipelineDescriptorLabel = @"RTCPipeline";


// Computes the texture coordinates given rotation and cropping.
void LinkvGetCubeVertexData(int cropX,
                            int cropY,
                            int cropWidth,
                            int cropHeight,
                            size_t frameWidth,
                            size_t frameHeight,
                            LVImageOrientation rotation,
                            float *buffer) {
    // The computed values are the adjusted texture coordinates, in [0..1].
    // For the left and top, 0.0 means no cropping and e.g. 0.2 means we're skipping 20% of the
    // left/top edge.
    // For the right and bottom, 1.0 means no cropping and e.g. 0.8 means we're skipping 20% of the
    // right/bottom edge (i.e. render up to 80% of the width/height).
    float cropLeft = cropX / (float)frameWidth;
    float cropRight = (cropX + cropWidth) / (float)frameWidth;
    float cropTop = cropY / (float)frameHeight;
    float cropBottom = (cropY + cropHeight) / (float)frameHeight;
    
    /*
       LVImageOrientationNone = 0,
       LVImageOrientationRotate90,
       LVImageOrientationRotateLeft = LVImageOrientationRotate90,
       LVImageOrientationRotate180,
       LVImageOrientationRotate270,
       LVImageOrientationRotateRight = LVImageOrientationRotate270,
       LVImageOrientationFlipVertical,
       LVImageOrientationFlipHorizonal,
       LVImageOrientationRotateLeftHorizonal,
       LVImageOrientationRotateRightHorizonal,
       LVImageOrientationAuto
     */
    
    // These arrays map the view coordinates to texture coordinates, taking cropping and rotation
    // into account. The first two columns are view coordinates, the last two are texture coordinates.
    switch (rotation) {
        case LVImageOrientationNone: {
            float values[16] = {
                -1.0, -1.0, cropLeft, cropBottom,
                1.0, -1.0, cropRight, cropBottom,
                -1.0,  1.0, cropLeft, cropTop,
                1.0,  1.0, cropRight, cropTop};
            memcpy(buffer, &values, sizeof(values));
        } break;
        case LVImageOrientationRotate90: {
            float values[16] = {
                -1.0, -1.0, cropRight, cropBottom,
                1.0, -1.0, cropRight, cropTop,
                -1.0,  1.0, cropLeft, cropBottom,
                1.0,  1.0, cropLeft, cropTop};
            memcpy(buffer, &values, sizeof(values));
        } break;
        case LVImageOrientationRotate180: {
            float values[16] = {
                -1.0, -1.0, cropRight, cropTop,
                1.0, -1.0, cropLeft, cropTop,
                -1.0,  1.0, cropRight, cropBottom,
                1.0,  1.0, cropLeft, cropBottom};
            memcpy(buffer, &values, sizeof(values));
        } break;
        case LVImageOrientationRotate270: {
            float values[16] = {
                -1.0, -1.0, cropLeft, cropTop,
                1.0, -1.0, cropLeft, cropBottom,
                -1.0, 1.0, cropRight, cropTop,
                1.0, 1.0, cropRight, cropBottom};
            memcpy(buffer, &values, sizeof(values));
        } break;
        case LVImageOrientationFlipVertical:{
            float values[16] = {
                -1.0, -1.0, cropLeft, cropTop,
                1.0, -1.0,  cropRight, cropTop,
                -1.0, 1.0,  cropLeft, cropBottom,
                1.0,  1.0,  cropRight, cropBottom};
            memcpy(buffer, &values, sizeof(values));
        } break;
        case LVImageOrientationFlipHorizonal:{
            float values[16] = {
                -1.0, -1.0, cropRight, cropBottom,
                1.0, -1.0, cropLeft, cropBottom,
                -1.0,  1.0, cropRight, cropTop,
                1.0,  1.0,  cropLeft, cropTop,};
            memcpy(buffer, &values, sizeof(values));
        } break;
        case LVImageOrientationRotateRightHorizonal:{
            float values[16] = {
                -1.0, -1.0,cropLeft, cropBottom,
                1.0, -1.0, cropLeft, cropTop,
                -1.0, 1.0, cropRight, cropBottom,
                1.0, 1.0, cropRight, cropTop};
            memcpy(buffer, &values, sizeof(values));
        } break;
        case LVImageOrientationRotateLeftHorizonal:{
            float values[16] = {
                -1.0, -1.0, cropRight, cropTop,
                1.0, -1.0, cropRight, cropBottom,
                -1.0,  1.0, cropLeft, cropTop,
                1.0,  1.0, cropLeft, cropBottom};
            memcpy(buffer, &values, sizeof(values));
        } break;
        default: {
            // default: LVImageOrientationNone
            float values[16] = {
                -1.0, -1.0, cropLeft, cropBottom,   /*0, 0*/
                1.0, -1.0, cropRight, cropBottom,   /*1, 0*/
                -1.0,  1.0, cropLeft, cropTop,      /*0, 1*/
                1.0,  1.0, cropRight, cropTop};     /*1, 1*/
            memcpy(buffer, &values, sizeof(values));
        } break;
    }
    /**
             -----------------                                              ----------------
             |  -1, 1  |   1,1  |     3,  4                                  |  0, 1  |  1, 1  |      3,  4
             -----------------                                              -----------------
             | -1,-1  |  1,-1  |     1,  2                                  |  0, 0  |  1, 0  |      1 , 2
             -----------------                                              ----------------
     */
}

@interface MTImageEngine ()
@property (nonatomic) CVMetalTextureCacheRef textureCache;

@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) MTLRenderPassDescriptor *renderPassDescriptor;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipelineState;
@property (nonatomic, strong) id<MTLBuffer> convertMatrix;

@end

@implementation MTImageEngine{
    NSMutableDictionary *_renders;
    MTImage     *_image;
    
    // Renderer.
    id<MTLDevice> _device;
    id<MTLCommandQueue> _commandQueue;
    id<MTLLibrary> _defaultLibrary;
    id<MTLBuffer> _uniformsBuffer;
    
    MTTexture *_currentTexture;
    // Buffers.
    id<MTLBuffer> _vertexBuffer;
    
    int _oldCropX;
    int _oldCropY;
    int _oldCropWidth;
    int _oldCropHeight;
    int _oldRotation;
    size_t _oldFrameWidth;
    size_t _oldFrameHeight;
    
    dispatch_semaphore_t _sem;
    
}

@synthesize textureCache = _textureCache;

@synthesize commandQueue = _commandQueue;
@synthesize renderPassDescriptor = _renderPassDescriptor;
@synthesize pipelineState = _pipelineState;

@synthesize convertMatrix = _convertMatrix;

@synthesize orientation = _orientation;

@synthesize beautyLevel = _beautyLevel;
@synthesize brightLevel = _brightLevel;
@synthesize toneLevel = _toneLevel;
@synthesize beautyEnable = _beautyEnable;

// 先裁剪，后缩放
@synthesize cropToSize = _cropToSize;
@synthesize scaleToSize = _scaleToSize;
@synthesize definedOrientation = _definedOrientation;


+(instancetype)sharedManager{
    static MTImageEngine *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[self alloc]init];
        [manager configure];
    });
    return manager;
}

-(void)configure{
    _renders = [[NSMutableDictionary alloc]init];
    _device = MTLCreateSystemDefaultDevice();
    CVMetalTextureCacheCreate(NULL, NULL, _device, NULL, &_textureCache);
//
    _image = [[MTImage alloc]init];
    _orientation = LVImageOrientationNone;
    _definedOrientation = NO;
    _brightLevel = 0.3;
    _toneLevel = 0.5;
    _beautyLevel = 1.0;
    
    _sem = dispatch_semaphore_create(0);
}


-(BOOL)loadAssets:(OSType)format{
    // Create a new command queue.
    
    if (_commandQueue) return YES;
    _commandQueue = [_device newCommandQueue];
    // Load metal library from source.
    NSError *libraryError = nil;
    BOOL isRGBA = (format == kCVPixelFormatType_32BGRA || format == kCVPixelFormatType_32ARGB);
    NSString *shaderSource = isRGBA ? kShaderSourceRGBA : kShaderSourceNV12;
    
    if (isRGBA){
        BOOL isARGB = (format == kCVPixelFormatType_32ARGB);
        _uniformsBuffer =
        [_device newBufferWithBytes:&isARGB
                             length:sizeof(isARGB)
                            options:MTLResourceCPUCacheModeDefaultCache];
    }
    
    id<MTLLibrary> sourceLibrary =
        [_device newLibraryWithSource:shaderSource options:NULL error:&libraryError];
    if (libraryError) {
//      RTCLogError(@"Metal: Library with source failed\n%@", libraryError);
      return NO;
    }
    if (!sourceLibrary) {
//      RTCLogError(@"Metal: Failed to load library. %@", libraryError);
      return NO;
    }
    _defaultLibrary = sourceLibrary;
    id<MTLFunction> vertexFunction = [_defaultLibrary newFunctionWithName:vertexFunctionName];
    id<MTLFunction> fragmentFunction = [_defaultLibrary newFunctionWithName:fragmentFunctionName];
    MTLRenderPipelineDescriptor *pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineDescriptor.label = pipelineDescriptorLabel;
    pipelineDescriptor.vertexFunction = vertexFunction;
    pipelineDescriptor.fragmentFunction = fragmentFunction;
    pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    pipelineDescriptor.depthAttachmentPixelFormat = MTLPixelFormatInvalid;
    NSError *error = nil;
    _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
    if (!_pipelineState) {
//      RTCLogError(@"Metal: Failed to create pipeline state. %@", error);
        return NO;
    }
    _renderPassDescriptor = [MTLRenderPassDescriptor new];
    _renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
    _renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    _renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    float vertexBufferArray[16] = {0};
    _vertexBuffer = [_device newBufferWithBytes:vertexBufferArray
                                         length:sizeof(vertexBufferArray)
                                        options:MTLResourceCPUCacheModeWriteCombined];
    
    return YES;
}

-(BOOL)loadBeautyAssets:(OSType)format{
    if (_commandQueue) return YES;
    _device = MTLCreateSystemDefaultDevice();
    _commandQueue = [_device newCommandQueue];
    NSError *libraryError = nil;
    id<MTLLibrary> sourceLibrary =
    [_device newLibraryWithSource:kBeautyShaderSourceBGRA options:NULL error:&libraryError];
    if (libraryError) {
        NSLog(@"Metal: Library with source failed\n%@", libraryError);
        return NO;
    }
    if (!sourceLibrary) {
        NSLog(@"Metal: Failed to load library. %@", libraryError);
        return NO;
    }
    _defaultLibrary = sourceLibrary;
    id <MTLFunction> vertexFunction = [_defaultLibrary newFunctionWithName:@"VertexShader"];
    id <MTLFunction> fragmentFunction = [_defaultLibrary newFunctionWithName:@"FragmentShader"];
    
    MTLRenderPipelineDescriptor *pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineDescriptor.label = pipelineDescriptorLabel;
    pipelineDescriptor.vertexFunction = vertexFunction;
    pipelineDescriptor.fragmentFunction = fragmentFunction;
    pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    pipelineDescriptor.depthAttachmentPixelFormat = MTLPixelFormatInvalid;
    NSError *error = nil;
    _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
    if (!_pipelineState) {
        NSLog(@"Metal: Failed to create pipeline state. %@", error);
        return NO;
    }
    _renderPassDescriptor = [MTLRenderPassDescriptor new];
    _renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
    _renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    _renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    float vertexBufferArray[16] = {0};
    _vertexBuffer = [_device newBufferWithBytes:vertexBufferArray
                                         length:sizeof(vertexBufferArray)
                                        options:MTLResourceCPUCacheModeWriteCombined];
    
    return YES;
}

+(CVMetalTextureCacheRef)textureCache{
    return [MTImageEngine sharedManager].textureCache;
}

-(void)setObject:(MTView *)target forKey:(NSString *)key{
    _renders[key] = target;
}

-(void)removeObjectForKey:(NSString *)key{
    [_renders removeObjectForKey:key];
}

-(void)removeAllObjects{
    [_renders removeAllObjects];
}

-(MTView *)objectForKey:(NSString *)key{
    return _renders[key];
}

- (void)uploadTexturesToRenderEncoder:(id<MTLRenderCommandEncoder>)encoder format:(OSType)format{
    BOOL isRGBA = (format == kCVPixelFormatType_32BGRA || format == kCVPixelFormatType_32ARGB);
    if (isRGBA) {
        [encoder setFragmentTexture:_currentTexture.rgbTexture atIndex:0];
        [encoder setFragmentBuffer:_uniformsBuffer offset:0 atIndex:0];
    }
    else{
        [encoder setFragmentTexture:_currentTexture.yTexture atIndex:0];
        [encoder setFragmentTexture:_currentTexture.uvTexture atIndex:1];
    }
}


- (void)render:(OSType)format orientation:(int)orientation completion:(MTCompletedHandler)completion{
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = commandBufferLabel;
    //  __block dispatch_semaphore_t block_semaphore = _inflight_semaphore;
    __weak MTImageEngine* weakSelf = self;
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> _Nonnull buffer) {
        // GPU work completed.
        __strong MTImageEngine *strongSelf = weakSelf;
        completion(strongSelf->_image.renderPixelBuffer);
    }];
    
    CGSize imageSize = CGSizeMake(self.scaleToSize.width, self.scaleToSize.height);
    if (LVImageRotationSwapsWidthAndHeight(orientation)) {
        imageSize = CGSizeMake(imageSize.height, imageSize.width);
    }
    [_image setupRenderTarget:imageSize];
    
    size_t frameWidth = 0;
    size_t frameHeight = 0;
    BOOL isRGBA = (format == kCVPixelFormatType_32BGRA || format == kCVPixelFormatType_32ARGB);
    if (isRGBA) {
        frameWidth = _currentTexture.rgbTexture.width;
        frameHeight = _currentTexture.rgbTexture.height;
    }
    else{
        frameWidth = _currentTexture.yTexture.width;
        frameHeight = _currentTexture.yTexture.height;
    }
    
    int cropX = (frameWidth - _cropToSize.width)/2.0;
    int cropY = (frameHeight - _cropToSize.height)/2.0;
    int cropWidth = _cropToSize.width;
    int cropHeight = _cropToSize.height;
    
    // Recompute the texture cropping and recreate vertexBuffer if necessary.
    if (cropX != _oldCropX || cropY != _oldCropY || cropWidth != _oldCropWidth ||
        cropHeight != _oldCropHeight || orientation != _oldRotation || frameWidth != _oldFrameWidth ||
        frameHeight != _oldFrameHeight) {
        LinkvGetCubeVertexData(cropX,
                               cropY,
                               cropWidth,
                               cropHeight,
                               frameWidth,
                               frameHeight,
                               orientation,
                               (float *)_vertexBuffer.contents);
        _oldCropX = cropX;
        _oldCropY = cropY;
        _oldCropWidth = cropWidth;
        _oldCropHeight = cropHeight;
        _oldRotation = orientation;
        _oldFrameWidth = frameWidth;
        _oldFrameHeight = frameHeight;
    }
    MTLRenderPassDescriptor *renderPassDescriptor = _renderPassDescriptor;
    renderPassDescriptor.colorAttachments[0].texture = _image.destTexture;
    if (renderPassDescriptor) {  // Valid drawable.
        id<MTLRenderCommandEncoder> renderEncoder =
        [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        renderEncoder.label = renderEncoderLabel;
        // Set context state.
        [renderEncoder pushDebugGroup:renderEncoderDebugGroup];
        [renderEncoder setRenderPipelineState:_pipelineState];
        [renderEncoder setVertexBuffer:_vertexBuffer offset:0 atIndex:0];
        [self uploadTexturesToRenderEncoder:renderEncoder format:format];
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip
                          vertexStart:0
                          vertexCount:4
                        instanceCount:1];
        [renderEncoder popDebugGroup];
        [renderEncoder endEncoding];
        //    [commandBuffer presentDrawable:_view.currentDrawable];
    }
    // CPU work is completed, GPU work can be started.
    [commandBuffer commit];
}


-(void)displayOnMain:(CVPixelBufferRef)pixelBuffer isFaceCamera:(BOOL)isFaceCamera cropToSize:(CGSize)cropToSize scaleToSize:(CGSize)scaleToSize orientation:(LVImageOrientation)orientation completion:(MTCompletedHandler)completion{
    _cropToSize = cropToSize;
    _scaleToSize = scaleToSize;
    OSType pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
    [self loadAssets:pixelFormat];
    [self render:pixelFormat orientation:(int)orientation completion:completion];

    MTView *renderView = [self objectForKey:kLVRTCLocalView];
    if (renderView) {
        if (self.definedOrientation) {
            renderView.orientation = isFaceCamera ? LVImageOrientationFlipHorizonal : LVImageOrientationNone;
        } else{
            renderView.orientation = orientation;
        }
        [renderView display:pixelBuffer texture:_currentTexture];
    }
    [self FaceSmoothing:pixelBuffer completion:completion];
}

-(void)FaceSmoothing:(CVPixelBufferRef)pixelBuffer completion:(MTCompletedHandler)completion{
    __weak MTImageEngine* weakSelf = self;
    dispatch_semaphore_wait(_sem, DISPATCH_TIME_NOW);
    OSType pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
    [self loadBeautyAssets:pixelFormat];
    CVBufferRetain(pixelBuffer);
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong MTImageEngine*strongSelf = weakSelf;
        [strongSelf __FaceSmoothing:pixelBuffer completion:completion];
        CVBufferRelease(pixelBuffer);
        dispatch_semaphore_signal(strongSelf->_sem);
    });
}

-(void)__FaceSmoothing:(CVPixelBufferRef)pixelBuffer completion:(MTCompletedHandler)completion{
    _currentTexture = [MTImage texture:pixelBuffer];
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = commandBufferLabel;
    __weak MTImageEngine* weakSelf = self;
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> _Nonnull buffer) {
        // GPU work completed.
        __strong MTImageEngine *strongSelf = weakSelf;
        completion(strongSelf->_image.renderPixelBuffer);
        MTView *renderView = [strongSelf objectForKey:kLVRTCLocalView];
        if (renderView) {
            [renderView display:strongSelf->_image.renderPixelBuffer texture:nil];
        }
    }];
    
    size_t frameWidth = _currentTexture.rgbTexture.width;
    size_t frameHeight = _currentTexture.rgbTexture.height;
    
    CGSize imageSize = CGSizeMake(frameWidth, frameHeight);
    [_image setupRenderTarget:imageSize];
    
    int cropX = 0;
    int cropY = 0;
    int cropWidth = (int)frameWidth;
    int cropHeight = (int)frameHeight;
    
    // Recompute the texture cropping and recreate vertexBuffer if necessary.
    if (cropX != _oldCropX || cropY != _oldCropY || cropWidth != _oldCropWidth || cropHeight != _oldCropHeight || frameWidth != _oldFrameWidth ||
        frameHeight != _oldFrameHeight) {
        LinkvGetCubeVertexData(cropX, cropY, cropWidth, cropHeight, frameWidth, frameHeight, _oldRotation, (float *)_vertexBuffer.contents);
        _oldCropX = cropX;
        _oldCropY = cropY;
        _oldCropWidth = cropWidth;
        _oldCropHeight = cropHeight;
        _oldRotation = 0;
        _oldFrameWidth = frameWidth;
        _oldFrameHeight = frameHeight;
    }
    MTLRenderPassDescriptor *renderPassDescriptor = _renderPassDescriptor;
    if (@available(macOS 10.15, *)) {
        renderPassDescriptor.renderTargetHeight = frameHeight;
        renderPassDescriptor.renderTargetWidth = frameWidth;
    } else {
        // Fallback on earlier versions
    }
    renderPassDescriptor.colorAttachments[0].texture = _image.destTexture;
    if (renderPassDescriptor) {  // Valid drawable.
        id<MTLRenderCommandEncoder> renderEncoder =
        [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        renderEncoder.label = renderEncoderLabel;
        // Set context state.
        [renderEncoder pushDebugGroup:renderEncoderDebugGroup];
        [renderEncoder setRenderPipelineState:_pipelineState];
        [renderEncoder setVertexBuffer:_vertexBuffer offset:0 atIndex:0];
        [renderEncoder setFragmentTexture:_currentTexture.rgbTexture atIndex:0];
        
        float parameters[8];
        parameters[0] = 2.0f / frameWidth;
        parameters[1] = 2.0f / frameHeight;
        
        parameters[2] = (1.0 - 0.6 * _beautyLevel);
        parameters[3] = (1.0 - 0.3 * _beautyLevel);
        parameters[4] = (0.1 + 0.3 * _toneLevel);
        parameters[5] = (0.1 + 0.3 * _toneLevel);
        parameters[6] = (0.6 * (-0.5 + _brightLevel));
        parameters[7] = 0.0;
        
        [renderEncoder setFragmentBytes:parameters length:(sizeof(float) * 8) atIndex:1];
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip
                          vertexStart:0
                          vertexCount:4
                        instanceCount:1];
        [renderEncoder popDebugGroup];
        [renderEncoder endEncoding];
    }
    // CPU work is completed, GPU work can be started.
    [commandBuffer commit];
}


-(void)display:(CVPixelBufferRef)pixelBuffer isFaceCamera:(BOOL)isFaceCamera rotation:(LVVideoRotation)rotation cropToSize:(CGSize)cropToSize scaleToSize:(CGSize)scaleToSize completion:(MTCompletedHandler)completion{
//    _currentTexture = [MTImage texture:pixelBuffer];
//    __weak MTImageEngine* weakSelf = self;
//    LVImageOrientation orientation = [self orientation:isFaceCamera rotation:rotation];
//    if (self.definedOrientation) orientation = self.orientation;
//    CFRetain(pixelBuffer);
//    dispatch_async(dispatch_get_main_queue(), ^{
//        __strong MTImageEngine*strongSelf = weakSelf;
//        [strongSelf displayOnMain:pixelBuffer isFaceCamera:isFaceCamera cropToSize:cropToSize scaleToSize:scaleToSize orientation:orientation completion:completion];
//        CFRelease(pixelBuffer);
//    });
    
//    if (@available(iOS 11.0, macOS 10.15, *)) {
        [self FaceSmoothing:pixelBuffer completion:completion];
//    }
//    else{
//        completion(pixelBuffer);
//    }
}

-(LVImageOrientation)orientation:(BOOL)isFrontCamera rotation:(LVVideoRotation)rotation{
    LVImageOrientation outputOrientation = LVImageOrientationNone;
    if (rotation == LVVideoRotation_0) {
        if (isFrontCamera) {
            outputOrientation = LVImageOrientationFlipHorizonal;
        }
        else{
            outputOrientation = LVImageOrientationNone;
        }
    }
    else if (rotation == LVVideoRotation_90){
        if (isFrontCamera) {
            outputOrientation = LVImageOrientationRotateRightHorizonal;
        }
        else{
            outputOrientation = LVImageOrientationRotateRight;
        }
    }
    else if (rotation == LVVideoRotation_180){
        if (isFrontCamera) {
            outputOrientation = LVImageOrientationFlipHorizonal;
        }
        else{
            outputOrientation = LVImageOrientationNone;
        }
    }
    else{
        if (isFrontCamera) {
            outputOrientation = LVImageOrientationRotateLeftHorizonal;
        }
        else{
            outputOrientation = LVImageOrientationRotateLeft;
        }
    }
    return outputOrientation;
}

-(LVImageOrientation)rotation2Orientation:(LVVideoRotation)rotation{
    switch (rotation) {
        case LVVideoRotation_0:
            return LVImageOrientationNone;
            
        case LVVideoRotation_90:
            return LVImageOrientationRotate90;
            
        case LVVideoRotation_180:
            return LVImageOrientationRotate180;
            
        case LVVideoRotation_270:
            return LVImageOrientationRotate270;
    }
}


@end
