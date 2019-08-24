//
//  UIImageView+RGGif.h
//  CampTalk
//
//  Created by renge on 2019/8/3.
//  Copyright © 2019 yuru. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIImageView(RGGif)

- (void)rg_setImagePath:(NSString *)path;
- (void)rg_setImagePath:(NSString *)path async:(BOOL)async delayGif:(NSTimeInterval)delayGif completion:(NS_NOESCAPE BOOL(^_Nullable)(NSData *data))completion;

- (void)rg_setImageData:(NSData *)data;
- (void)rg_setImageData:(NSData *)data delayGif:(NSTimeInterval)delayGif;

- (BOOL)rg_isAnimating;
- (void)rg_start;
- (void)rg_stop;

@end

@interface UIImage (RGGif)

+ (UIImage *)rg_imageOrGifWithData:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
