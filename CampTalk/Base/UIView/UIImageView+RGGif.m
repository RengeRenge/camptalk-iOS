//
//  UIImageView+RGGif.m
//  CampTalk
//
//  Created by renge on 2019/8/3.
//  Copyright © 2019 yuru. All rights reserved.
//

#import "UIImageView+RGGif.h"
#import "FLAnimatedImage.h"
#import <RGUIKit/RGUIKit.h>

@implementation UIImageView(RGGif)

+ (void)load {
    [self rg_swizzleOriginalSel:@selector(setContentMode:) swizzledSel:@selector(rg_setContentMode:)];
    [self rg_swizzleOriginalSel:@selector(image) swizzledSel:@selector(rg_image)];
    [self rg_swizzleOriginalSel:@selector(setImage:) swizzledSel:@selector(rg_setImage:)];
}

- (UIImage *)rg_image {
    if (self.rg_image) {
        return self.rg_image;
    }
    FLAnimatedImageView *gifView = [self rg_valueForKey:@"gifView"];
    if (gifView.animatedImage) {
        return [gifView.animatedImage imageLazilyCachedAtIndex:0];
    }
    return nil;
}

- (void)rg_setImage:(UIImage *)image {
    FLAnimatedImageView *gifView = [self rg_valueForKey:@"gifView"];
    if ([image isKindOfClass:UIImage.class]) {
        [self rg_setImage:image];
        gifView.animatedImage = nil;
    } else if ([image isKindOfClass:FLAnimatedImage.class]) {
        [self rg_setImage:nil];
        self.gifView.animatedImage = (FLAnimatedImage *)image;
    } else if ([image isKindOfClass:NSData.class]) {
        [self rg_setImageData:(NSData *)image];
    } else {
        if (self.image) {
            [self rg_setImage:nil];
        }
        if (gifView.animatedImage) {
            gifView.animatedImage = nil;
        }
    }
}

- (void)rg_setContentMode:(UIViewContentMode)mode {
    [self rg_setContentMode:mode];
    FLAnimatedImageView *gifView = [self rg_valueForKey:@"gifView"];
    if (gifView.contentMode != mode) {
        gifView.contentMode = mode;
    }
}

- (FLAnimatedImageView *)gifView {
    FLAnimatedImageView *gifView = [self rg_valueForKey:@"gifView"];
    if (!gifView) {
        gifView = [[FLAnimatedImageView alloc] initWithFrame:self.bounds];
        [self rg_setValue:gifView forKey:@"gifView" retain:YES];
        gifView.contentMode = self.contentMode;
        gifView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self insertSubview:gifView atIndex:0];
    }
    return gifView;
}

- (void)rg_setImagePath:(NSString *)path
                  async:(BOOL)async
               delayGif:(NSTimeInterval)delayGif
             completion:(NS_NOESCAPE BOOL (^)(NSData * _Nonnull))completion {
    if (async) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSData *data = [NSData dataWithContentsOfURL:[NSURL fileURLWithPath:path]];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) {
                    if (completion(data)) {
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                            [self rg_setImageData:data delayGif:delayGif];
                        });
                    }
                } else {
                    [self rg_setImageData:data delayGif:delayGif];
                }
            });
        });
    } else {
        NSData *data = [NSData dataWithContentsOfURL:[NSURL fileURLWithPath:path]];
        if (completion) {
            if (completion(data)) {
                [self rg_setImageData:data delayGif:delayGif];
            }
        } else {
            [self rg_setImageData:data delayGif:delayGif];
        }
    }
}

- (void)rg_setImagePath:(NSString *)path {
    [self rg_setImagePath:path async:NO delayGif:0 completion:nil];
}

- (void)rg_setImageData:(NSData *)data {
    [self rg_setImageData:data delayGif:0];
}

- (void)rg_setImageData:(NSData *)data delayGif:(NSTimeInterval)delayGif {
    
    FLAnimatedImage *image = [[FLAnimatedImage alloc] initWithAnimatedGIFData:data];
    UIImage *firstImage = nil;
    if (image && delayGif) {
        firstImage = [image imageLazilyCachedAtIndex:0];
    }
    
    if (!image) {
        image = (FLAnimatedImage *)[UIImage imageWithData:data];
    }
    
    BOOL isMainThread = [NSThread isMainThread];
    
    void(^setImage)(void) = ^{
        if (delayGif && firstImage) {
            self.image = firstImage;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayGif * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (firstImage != self.image) {
                    return;
                }
                self.image = (UIImage *)image;
            });
        } else {
            self.image = (UIImage *)image;
        }
    };
    
    if (isMainThread) {
        setImage();
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            setImage();
        });
    }
}

- (BOOL)rg_isAnimating {
    return self.gifView.isAnimating;
}

- (void)rg_stop {
    [self.gifView stopAnimating];
}

- (void)rg_start {
    [self.gifView startAnimating];
}

@end


@implementation UIImage (RGGif)

+ (UIImage *)rg_imageOrGifWithData:(NSData *)data {
    FLAnimatedImage *image = [[FLAnimatedImage alloc] initWithAnimatedGIFData:data];
    if (image) {
        return (UIImage *)image;
    }
    return [UIImage imageWithData:data];
}

@end


