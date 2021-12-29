//
//  MTView.h
//  MetalDemo
//
//  Created by jfdreamyang on 2020/9/27.
//

#import <Foundation/Foundation.h>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import "MTImageEngine.h"
/**
 本地预览视频视图的模式
 */
typedef NS_OPTIONS(NSUInteger, LVViewContentMode) {
    /**
     等比缩放，可能有黑边（或白边）
     */
    LVViewContentModeScaleAspectFit     = 0,
    /**
     等比缩放填充整View，可能有部分被裁减
     */
    LVViewContentModeScaleAspectFill    = 1,
    /**
     填充整个View
     */
    LVViewContentModeScaleToFill        = 2,
};

NS_ASSUME_NONNULL_BEGIN

@class MTTexture;

#if TARGET_OS_IOS
@interface MTView : UIView
#else
@interface MTView : NSView
#endif

-(void)display:(CVPixelBufferRef)image texture:(nullable MTTexture *)texture;

-(void)clearView:(BOOL)clear;

/// 设置视频内容渲染模式
@property (nonatomic)LVViewContentMode renderMode;

/// 设置视频渲染方向
@property (nonatomic)LVImageOrientation orientation;

/// 用户自定义试图方向，此时内部方向失效
@property (nonatomic)BOOL definedOrientation;

@end

NS_ASSUME_NONNULL_END
