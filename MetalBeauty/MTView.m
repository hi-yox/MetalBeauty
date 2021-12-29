//
//  MTView.m
//  MetalDemo
//
//  Created by jfdreamyang on 2020/9/27.
//

#import "MTView.h"
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#import <MetalKit/MetalKit.h>
#import "MTImageEngine.h"
#import "MTImage.h"
#import "MTShaders.h"
#import <GLKit/GLKit.h>

@interface MTView ()<MTKViewDelegate>
{
    BOOL _configured;
    OSType _pixelFormat;
    CVPixelBufferRef _renderTarget;
    
    
    id<MTLLibrary> _defaultLibrary;
    id<MTLBuffer> _uniformsBuffer;
    id<MTLBuffer> _vertexBuffer;
    
    int _oldCropX;
    int _oldCropY;
    int _oldCropWidth;
    int _oldCropHeight;
    int _oldRotation;
    size_t _oldFrameWidth;
    size_t _oldFrameHeight;
}
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipelineState;
@property (nonatomic, strong) MTKView *view;
@property (nonatomic, strong, readonly)id <MTLDevice> device;

@property (nonatomic, strong) id<MTLTexture> texture;

@property (nonatomic, strong) id<MTLTexture> yTexture;
@property (nonatomic, strong) id<MTLTexture> uvTexture;

@property (nonatomic, strong) id<MTLBuffer> vertexBuffer;
@end


@implementation MTView

@synthesize renderMode = _renderMode;
@synthesize orientation = _orientation;
@synthesize definedOrientation = _definedOrientation;
@synthesize commandQueue = _commandQueue;
@synthesize pipelineState = _pipelineState;
@synthesize view = _view;
@synthesize texture = _texture;
@synthesize yTexture = _yTexture;
@synthesize uvTexture = _uvTexture;
@synthesize vertexBuffer = _vertexBuffer;

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _view = [[MTKView alloc] initWithFrame:self.bounds];
        [self addSubview:_view];
#if TARGET_OS_OSX
        self.layer.backgroundColor = NSColor.blackColor.CGColor;
        _view.preferredFramesPerSecond = 0;
#elif TARGET_OS_IOS
        self.backgroundColor = UIColor.blackColor;
        _view.preferredFramesPerSecond = 0;
#endif
        _view.device = MTLCreateSystemDefaultDevice();
        _definedOrientation = NO;
        _orientation = LVImageOrientationNone;
        _view.delegate = self;
    }
    return self;
}

-(id<MTLDevice>)device{
    return self.view.device;
}

-(void)setFrame:(CGRect)frame{
    [super setFrame:frame];
    self.view.frame = self.bounds;
    self.view.drawableSize = frame.size;
}

-(BOOL)loadAssets:(OSType)format{
    // Create a new command queue.
    
    if (_commandQueue) return YES;
    _commandQueue = [self.device newCommandQueue];
    // Load metal library from source.
    NSError *libraryError = nil;
    
    BOOL isRGBA = (format == kCVPixelFormatType_32BGRA || format == kCVPixelFormatType_32ARGB);
    NSString *shaderSource = isRGBA ? kShaderSourceRGBA : kShaderSourceNV12;
    
    if (isRGBA){
        BOOL isARGB = (format == kCVPixelFormatType_32ARGB);
        _uniformsBuffer =
        [self.device newBufferWithBytes:&isARGB
                             length:sizeof(isARGB)
                            options:MTLResourceCPUCacheModeDefaultCache];
    }
    
    id<MTLLibrary> sourceLibrary =
        [self.device newLibraryWithSource:shaderSource options:NULL error:&libraryError];
    if (libraryError) {
      NSLog(@"Metal: Library with source failed\n%@", libraryError);
      return NO;
    }
    if (!sourceLibrary) {
        NSLog(@"Metal: Failed to load library. %@", libraryError);
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
    _pipelineState = [self.device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
    if (!_pipelineState) {
        NSLog(@"Metal: Failed to create pipeline state. %@", error);
        return NO;
    }
    float vertexBufferArray[16] = {0};
    _vertexBuffer = [self.device newBufferWithBytes:vertexBufferArray
                                         length:sizeof(vertexBufferArray)
                                        options:MTLResourceCPUCacheModeWriteCombined];
    
    return YES;
}

-(void)display:(CVPixelBufferRef)image texture:(nullable MTTexture *)texture{
    _pixelFormat = CVPixelBufferGetPixelFormatType(image);
    [self loadAssets:_pixelFormat];
    if (!texture) texture = [MTImage texture:image];
    self.texture = texture.rgbTexture;
    self.yTexture = texture.yTexture;
    self.uvTexture = texture.uvTexture;
    [self.view draw];
}

-(void)clearView:(BOOL)clear{
#if TARGET_OS_IOS
    if(clear) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.view removeFromSuperview];
        });
    }
    else {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIView * superView = [self.view superview];
            if(superView != nil)
                return;
            [self addSubview:self.view];
        });
    }
#endif
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size{}

- (void)drawInMTKView:(nonnull MTKView *)view{
    if (self.texture == nil && self.yTexture == nil && self.uvTexture == nil) {
        return;
    }
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> _Nonnull buffer) {
        
    }];
    commandBuffer.label = commandBufferLabel;
    OSType format = _pixelFormat;
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
    if(!commandBuffer || !renderPassDescriptor) return;
    // MTLRenderPassDescriptor描述一系列attachments的值，类似GL的FrameBuffer；同时也用来创建MTLRenderCommandEncoder
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0f); // 设置默认颜色
    id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    renderEncoder.label = renderEncoderLabel;//编码绘制指令的Encoder
    CGSize textureSize = CGSizeMake(MAX(self.texture.width, self.yTexture.width), MAX(self.texture.height, self.yTexture.height));
    MTLViewport viewport = [self viewport:textureSize];
    [renderEncoder setViewport:viewport]; // 设置显示区域
    
    size_t frameWidth = 0;
    size_t frameHeight = 0;
    BOOL isRGBA = (format == kCVPixelFormatType_32BGRA || format == kCVPixelFormatType_32ARGB);
    if (isRGBA) {
        frameWidth = self.texture.width;
        frameHeight = self.texture.height;
    }
    else{
        frameWidth = self.yTexture.width;
        frameHeight = self.yTexture.height;
    }
    
    int cropX = 0;
    int cropY = 0;
    int cropWidth = (int)frameWidth;
    int cropHeight = (int)frameHeight;
    
    // Recompute the texture cropping and recreate vertexBuffer if necessary.
    if (cropX != _oldCropX || cropY != _oldCropY || cropWidth != _oldCropWidth ||
        cropHeight != _oldCropHeight || (int)_orientation != _oldRotation || frameWidth != _oldFrameWidth ||
        frameHeight != _oldFrameHeight) {
        LinkvGetCubeVertexData(cropX,
                               cropY,
                               cropWidth,
                               cropHeight,
                               frameWidth,
                               frameHeight,
                               _orientation,
                               (float *)_vertexBuffer.contents);
        _oldCropX = cropX;
        _oldCropY = cropY;
        _oldCropWidth = cropWidth;
        _oldCropHeight = cropHeight;
        _oldRotation = (int)_orientation;
        _oldFrameWidth = frameWidth;
        _oldFrameHeight = frameHeight;
    }
    
    // Set context state.
    [renderEncoder setRenderPipelineState:_pipelineState];
    [renderEncoder setVertexBuffer:_vertexBuffer offset:0 atIndex:0];
    [self uploadTexturesToRenderEncoder:renderEncoder format:format];
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip
                      vertexStart:0
                      vertexCount:4
                    instanceCount:1];
    [renderEncoder endEncoding];
    [commandBuffer presentDrawable:view.currentDrawable];
    // CPU work is completed, GPU work can be started.
    [commandBuffer commit];
    
    [commandBuffer waitUntilCompleted];
}

- (void)uploadTexturesToRenderEncoder:(id<MTLRenderCommandEncoder>)encoder format:(OSType)format{
    BOOL isRGBA = (format == kCVPixelFormatType_32BGRA || format == kCVPixelFormatType_32ARGB);
    if (isRGBA) {
        [encoder setFragmentTexture:self.texture atIndex:0];
        [encoder setFragmentBuffer:_uniformsBuffer offset:0 atIndex:0];
    }
    else{
        [encoder setFragmentTexture:self.yTexture atIndex:0];
        [encoder setFragmentTexture:self.uvTexture atIndex:1];
    }
}

- (MTLViewport)viewport:(CGSize)textureSize {
    CGSize drawSize = self.view.drawableSize;
    MTLViewport viewport;
    switch (self.renderMode) {
        case LVViewContentModeScaleToFill:{
            viewport = (MTLViewport){0, 0, drawSize.width, drawSize.height, -1.0, 1.0};
        }
            break;
        case LVViewContentModeScaleAspectFit:{
            double newTextureW, newTextureH, newOrigenX, newOrigenY;
            
            if (drawSize.width/drawSize.height < textureSize.width/textureSize.height) {
                newTextureW = drawSize.width;
                newTextureH = textureSize.height * drawSize.width / textureSize.width;
                newOrigenX = 0;
                newOrigenY = (drawSize.height - newTextureH) / 2;
            }
            else {
                newTextureH = drawSize.height;
                newTextureW = textureSize.width * drawSize.height / textureSize.height;
                newOrigenY = 0;
                newOrigenX = (drawSize.width - newTextureW) / 2;
            }
            
            viewport = (MTLViewport){newOrigenX, newOrigenY, newTextureW, newTextureH, -1.0, 1.0};
        }
            break;
        case LVViewContentModeScaleAspectFill:{
            double newTextureW, newTextureH, newOrigenX, newOrigenY;
            
            if (drawSize.width/drawSize.height < textureSize.width/textureSize.height) {
                newTextureH = drawSize.height;
                newTextureW = textureSize.width * drawSize.height / textureSize.height;
                newOrigenY = 0;
                newOrigenX = (drawSize.width - newTextureW) / 2;
            }
            else {
                newTextureW = drawSize.width;
                newTextureH = textureSize.height * drawSize.width / textureSize.width;
                newOrigenX = 0;
                newOrigenY = (drawSize.height - newTextureH) / 2;
            }
            
            viewport = (MTLViewport){newOrigenX, newOrigenY, newTextureW, newTextureH, -1.0, 1.0};
        }
            break;
    }
    
    return viewport;
}

-(void)setOrientation:(LVImageOrientation)orientation{
    if (!self.definedOrientation) {
        _orientation = orientation;
    }
}

@end
