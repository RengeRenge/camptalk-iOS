//
//  ImageGallery.h
//  yb
//
//  Created by LD on 16/4/2.
//  Copyright © 2016年 acumen. All rights reserved.
//
 /**********************
      ImageGallery
 ***********************
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^RGIMGalleryTransitionCompletion)(BOOL flag);

typedef enum : NSUInteger {
    RGImageGalleryPushStateNoPush,
    RGImageGalleryPushStatePushing,
    RGImageGalleryPushStatePushed,
} RGImageGalleryPushState;

@protocol RGImageGalleryDelegate;

@interface RGImageGallery : UIViewController

@property (assign, nonatomic, readonly) NSInteger page;

@property (assign, nonatomic) BOOL pushFromView;
@property (assign, nonatomic, readonly) RGImageGalleryPushState pushState;

@property (weak, nonatomic) id<RGImageGalleryDelegate> delegate;

+ (UIImage *)imageForTranslucentNavigationBar:(UINavigationBar *)navigationBar backgroundImage:(UIImage *)image;

- (instancetype)initWithPlaceHolder:(UIImage *_Nullable)placeHolder andDelegate:(id)delegate;

- (void)showImageGalleryAtIndex:(NSInteger)Index fatherViewController:(UIViewController *)viewController;

- (void)addInteractionGestureShowImageGalleryAtIndex:(NSInteger)index fatherViewController:(UIViewController *)viewController fromView:(UIView *)view imageView:(UIImageView *)imageView;

- (void)showMessage:(NSString *)message atPercentY:(CGFloat)percentY;

- (void)updatePages:(NSIndexSet *)pages;
- (void)insertPages:(NSIndexSet *)pages;
- (void)deletePages:(NSIndexSet *)pages;

- (void)reloadTitle;
- (void)reloadToolBarItem;

- (void)setLoading:(BOOL)loading;

@end

@protocol RGImageGalleryDelegate <NSObject>

- (NSInteger)numOfImagesForImageGallery:(RGImageGallery *)imageGallery;
- (UIView *)imageGallery:(RGImageGallery *)imageGallery thumbViewForTransitionAtIndex:(NSInteger)index;

- (UIImage *)imageGallery:(RGImageGallery *)imageGallery thumbnailAtIndex:(NSInteger)index targetSize:(CGSize)targetSize;
- (UIImage *)imageGallery:(RGImageGallery *)imageGallery imageAtIndex:(NSInteger)index targetSize:(CGSize)targetSize updateImage:(void(^_Nullable)(UIImage *image))updateImage;

- (UIColor *_Nullable)titleColorForImageGallery:(RGImageGallery *)imageGallery;
- (NSString *_Nullable)titleForImageGallery:(RGImageGallery *)imageGallery AtIndex:(NSInteger)index;

@optional

- (void)configNavigationBarForImageGallery:(BOOL)forImageGallery imageGallery:(RGImageGallery *)imageGallery;

- (BOOL)imageGallery:(RGImageGallery *)imageGallery toolBarItemsShouldDisplayForIndex:(NSInteger)index;
- (NSArray <UIBarButtonItem *> *)imageGallery:(RGImageGallery *)imageGallery toolBarItemsForIndex:(NSInteger)index;

- (UIImage *_Nullable)buttonForPlayVideo;
- (BOOL)isVideoAtIndex:(NSInteger)index;
- (BOOL)imageGallery:(RGImageGallery *)imageGallery selectePlayVideoAtIndex:(NSInteger)index;

- (void)imageGallery:(RGImageGallery *)imageGallery middleImageHasChangeAtIndex:(NSInteger)index;

- (RGIMGalleryTransitionCompletion)imageGallery:(RGImageGallery *)imageGallery willPopToParentViewController:(UIViewController *)viewController;
- (RGIMGalleryTransitionCompletion)imageGallery:(RGImageGallery *)imageGallery willBePushedWithParentViewController:(UIViewController *)viewController;

@end

NS_ASSUME_NONNULL_END
