//
//  MTImage.h
//  MetaiView
//
//  Created by jfdreamyang on 2020/10/10.
//

#import <Foundation/Foundation.h>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif

#import <CoreVideo/CoreVideo.h>


NS_ASSUME_NONNULL_BEGIN

@interface MTTexture : NSObject
@property (nonatomic, strong) id<MTLTexture> rgbTexture;
@property (nonatomic, strong) id<MTLTexture> yTexture;
@property (nonatomic, strong) id<MTLTexture> uvTexture;

-(void)configure:(CVPixelBufferRef)image;
@end

@interface MTImage : NSObject

@property (nonatomic)CGSize size;

@property (nonatomic, strong, readonly) id<MTLTexture> destTexture;

@property (nonatomic, readonly) CVPixelBufferRef renderPixelBuffer;

/// 配置渲染目标
/// @param size 渲染目标大小
-(void)setupRenderTarget:(CGSize)size;


+(MTTexture *)texture:(CVPixelBufferRef)image;

@end

NS_ASSUME_NONNULL_END
