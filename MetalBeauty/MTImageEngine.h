//
//  MTImageEngine.h
//  products
//
//  Created by jfdreamyang on 2020/4/9.
//

#import <Foundation/Foundation.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#import <MetalKit/MetalKit.h>

/**
 视频图像翻转操作枚举
 */
typedef enum : NSUInteger {
    /**
        不旋转
     */
    LVImageOrientationNone = 0,
    /**
        画面旋转 90 度
     */
    LVImageOrientationRotate90,
    /**
        向左旋转
     */
    LVImageOrientationRotateLeft = LVImageOrientationRotate90,
    /**
        旋转 180 度
     */
    LVImageOrientationRotate180,
    /**
        画面选择 270 度
     */
    LVImageOrientationRotate270,
    /**
        向右旋转
     */
    LVImageOrientationRotateRight = LVImageOrientationRotate270,
    /**
        竖直翻转
     */
    LVImageOrientationFlipVertical,
    /**
        水平翻转
     */
    LVImageOrientationFlipHorizonal,
    /**
        向左旋转并同时水平翻转
     */
    LVImageOrientationRotateLeftHorizonal,
    /**
        向右旋转并同时水平翻转
     */
    LVImageOrientationRotateRightHorizonal,
    /**
        由程序内部控制旋转方向
     */
    LVImageOrientationAuto
} LVImageOrientation;

/**
 外层视频旋转方向，注意不是视频采集方向
 */
typedef NS_ENUM(NSInteger, LVVideoRotation) {
    /**
        对视频数据进行 0 度旋转
     */
    LVVideoRotation_0          = 0,
    /**
       对视频数据进行 90 度旋转
    */
    LVVideoRotation_90         = 90,
    /**
       对视频数据进行 180 度旋转
    */
    LVVideoRotation_180        = 180,
    /**
       对视频数据进行 270 度旋转
    */
    LVVideoRotation_270        = 270,
};


#ifdef __cplusplus
#define LVEXTERN extern "C"  __attribute__((visibility ("default")))
#else
#define LVEXTERN extern __attribute__((visibility ("default")))
#endif

#define LVImageRotationSwapsWidthAndHeight(rotation) ((rotation) == LVImageOrientationRotateLeft || (rotation) == LVImageOrientationRotateRight || (rotation) == LVImageOrientationRotateLeftHorizonal || (rotation) == LVImageOrientationRotateRightHorizonal)


NS_ASSUME_NONNULL_BEGIN

LVEXTERN NSString *const kLVRTCLocalView;


LVEXTERN NSString *const commandBufferLabel;
LVEXTERN NSString *const renderEncoderLabel;
LVEXTERN NSString *const renderEncoderDebugGroup;
// As defined in shaderSource.
LVEXTERN NSString *const vertexFunctionName;
LVEXTERN NSString *const fragmentFunctionName;
LVEXTERN NSString *const pipelineDescriptorLabel;




void LinkvGetCubeVertexData(int cropX,
                            int cropY,
                            int cropWidth,
                            int cropHeight,
                            size_t frameWidth,
                            size_t frameHeight,
                            LVImageOrientation rotation,
                            float *buffer);

@class MTView;

typedef void(^MTCompletedHandler)(CVPixelBufferRef pixelBuffer);


@interface MTImageEngine : NSObject

+(instancetype)sharedManager;

/// 设置视频输出方向
@property (nonatomic)LVImageOrientation orientation;

/// 用户自定义视频输出方向
@property (nonatomic)BOOL definedOrientation;

/// 纹理缓存
@property (nonatomic, class, readonly) CVMetalTextureCacheRef textureCache;
/**
 下面所有方法均为非线程安全的
 */

/// 设置远端渲染路径
/// @param target 远端渲染视图
/// @param key 视图对应 key
-(void)setObject:(MTView *)target forKey:(NSString *)key;

/// 获取远端渲染视图
/// @param key 视图对应的 key
-(MTView *)objectForKey:(NSString *)key;

/// 移除远端视图渲染
/// @param key 视图对应 key
-(void)removeObjectForKey:(NSString *)key;

/// 移除所有远端视图
-(void)removeAllObjects;

/// 离屏渲染视频数据
/// @param pixelBuffer 视频数据
/// @param rotation 旋转方向
/// @param cropToSize 裁剪大小
/// @param scaleToSize 缩放大小
/// @param isFaceCamera 是否前置摄像头
/// @param completion 渲染完成回掉
-(void)display:(CVPixelBufferRef)pixelBuffer isFaceCamera:(BOOL)isFaceCamera rotation:(LVVideoRotation)rotation cropToSize:(CGSize)cropToSize scaleToSize:(CGSize)scaleToSize completion:(MTCompletedHandler)completion;


-(void)FaceSmoothing:(CVPixelBufferRef)pixelBuffer completion:(MTCompletedHandler)completion;


@property (nonatomic)float beautyLevel;
@property (nonatomic)float brightLevel;
@property (nonatomic)float toneLevel;
@property (nonatomic)BOOL beautyEnable;

// 先裁剪，后缩放
@property (nonatomic)CGSize cropToSize;
@property (nonatomic)CGSize scaleToSize;

-(LVImageOrientation)rotation2Orientation:(LVVideoRotation)rotation;

@end

NS_ASSUME_NONNULL_END
