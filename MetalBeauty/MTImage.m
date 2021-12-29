//
//  MTImage.m
//  MetaiView
//
//  Created by jfdreamyang on 2020/10/10.
//

#import "MTImage.h"
#import "MTImageEngine.h"

@interface MTImage ()
@property (nonatomic, strong) id<MTLTexture> destTexture;
@property (nonatomic) CVPixelBufferRef renderPixelBuffer;
@end

@implementation MTImage

@synthesize size = _size;
@synthesize destTexture = _destTexture;
@synthesize renderPixelBuffer = _renderPixelBuffer;

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.size = CGSizeZero;
    }
    return self;
}

-(void)setupRenderTarget:(CGSize)size{
 
    if (CGSizeEqualToSize(self.size, size)) return;
    if (!CGSizeEqualToSize(self.size, CGSizeZero)) {
        CFRelease(self.renderPixelBuffer);
    }
    self.size = size;
    CFDictionaryRef empty = CFDictionaryCreate(kCFAllocatorDefault, // our empty IOSurface properties dictionary
                                               NULL,
                                               NULL,
                                               0,
                                               &kCFTypeDictionaryKeyCallBacks,
                                               &kCFTypeDictionaryValueCallBacks);
    CFMutableDictionaryRef attrs = CFDictionaryCreateMutable(kCFAllocatorDefault,
                                                             1,
                                                             &kCFTypeDictionaryKeyCallBacks,
                                                             &kCFTypeDictionaryValueCallBacks);
    
    CFDictionarySetValue(attrs,kCVPixelBufferIOSurfacePropertiesKey,empty);
    CFRelease(empty);
    
    CVPixelBufferRef renderTarget;
    CVPixelBufferCreate(kCFAllocatorDefault, self.size.width, self.size.height,
                        kCVPixelFormatType_32BGRA,
                        attrs,
                        &renderTarget);
    CFRelease(attrs);
    // in real life check the error return value of course.
    // rendertarget
    {
        size_t width = CVPixelBufferGetWidthOfPlane(renderTarget, 0);
        size_t height = CVPixelBufferGetHeightOfPlane(renderTarget, 0);
        MTLPixelFormat pixelFormat = MTLPixelFormatBGRA8Unorm;
        CVMetalTextureRef texture = NULL;
        CVReturn status = CVMetalTextureCacheCreateTextureFromImage(NULL, MTImageEngine.textureCache, renderTarget, NULL, pixelFormat, width, height, 0, &texture);
        if(status == kCVReturnSuccess){
            self.destTexture = CVMetalTextureGetTexture(texture);
            self.renderPixelBuffer = renderTarget;
            CFRelease(texture);
        }
        else {
            NSAssert(NO, @"CVMetalTextureCacheCreateTextureFromImage fail");
        }
    }
}


-(void)dealloc{
    
}

+(MTTexture *)texture:(CVPixelBufferRef)image{
    
    MTTexture *mlTexture = [[MTTexture alloc]init];
    [mlTexture configure:image];
    return mlTexture;

}


@end


@implementation MTTexture
{
    CVPixelBufferRef _pixelBuffer;
}
@synthesize rgbTexture = _rgbTexture;
@synthesize yTexture = _yTexture;
@synthesize uvTexture = _uvTexture;

-(void)configure:(CVPixelBufferRef)image{
    _pixelBuffer = image;
    CVBufferRetain(image);
    OSType pixelFormat = CVPixelBufferGetPixelFormatType(image);
    if (pixelFormat == kCVPixelFormatType_32BGRA || pixelFormat == kCVPixelFormatType_32RGBA) {
        CVMetalTextureRef tmpTexture = NULL;
        CVReturn status = kCVReturnSuccess;
        if (pixelFormat == kCVPixelFormatType_32BGRA) {
            status = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                               MTImageEngine.textureCache,
                                                               image,
                                                               NULL,
                                                               MTLPixelFormatBGRA8Unorm,
                                                               CVPixelBufferGetWidth(image),
                                                               CVPixelBufferGetHeight(image),
                                                               0,
                                                               &tmpTexture);
        }
        else{
            status = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                               MTImageEngine.textureCache,
                                                               image,
                                                               NULL,
                                                               MTLPixelFormatRGBA8Unorm,
                                                               CVPixelBufferGetWidth(image),
                                                               CVPixelBufferGetHeight(image),
                                                               0,
                                                               &tmpTexture);
        }
        if(status == kCVReturnSuccess) {
            self.rgbTexture = CVMetalTextureGetTexture(tmpTexture);
            CFRelease(tmpTexture);
        }
        else{
            NSLog(@"Invalid generate texture, code:%d", status);
        }
    }
    else {
        id<MTLTexture> textureY = nil;
        id<MTLTexture> textureUV = nil;
        // textureY 设置
        {
            size_t width = CVPixelBufferGetWidthOfPlane(image, 0);
            size_t height = CVPixelBufferGetHeightOfPlane(image, 0);
            MTLPixelFormat pixelFormat = MTLPixelFormatR8Unorm; // 这里的颜色格式不是RGBA
            CVMetalTextureRef texture = NULL; // CoreVideo的Metal纹理
            CVReturn status = CVMetalTextureCacheCreateTextureFromImage(NULL, MTImageEngine.textureCache, image, NULL, pixelFormat, width, height, 0, &texture);
            if(status == kCVReturnSuccess){
                textureY = CVMetalTextureGetTexture(texture); // 转成Metal用的纹理
                self.yTexture = textureY;
                CFRelease(texture);
            }
            else{
                NSLog(@"Invalid generate Ytexture, code:%d", status);
            }
        }
        
        // textureUV 设置
        {
            size_t width = CVPixelBufferGetWidthOfPlane(image, 1);
            size_t height = CVPixelBufferGetHeightOfPlane(image, 1);
            MTLPixelFormat pixelFormat = MTLPixelFormatRG8Unorm; // 2-8bit的格式
            CVMetalTextureRef texture = NULL; // CoreVideo 的 Metal 纹理
            CVReturn status = CVMetalTextureCacheCreateTextureFromImage(NULL, MTImageEngine.textureCache, image, NULL, pixelFormat, width, height, 1, &texture);
            if(status == kCVReturnSuccess){
                textureUV = CVMetalTextureGetTexture(texture); // 转成Metal用的纹理
                self.uvTexture = textureUV;
                CFRelease(texture);
            }
            else{
                NSLog(@"Invalid generate UVtexture, code:%d", status);
            }
        }
    }
}

-(void)dealloc{
    if (_pixelBuffer) {
        CVBufferRelease(_pixelBuffer);
        _pixelBuffer = nil;
    }
}

@end
