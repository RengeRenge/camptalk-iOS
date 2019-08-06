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

@interface RGImageGallery : UIViewController<UIScrollViewDelegate, UIAlertViewDelegate, UIGestureRecognizerDelegate>

@property (strong,nonatomic) NSMutableArray<UIScrollView *>  *scrollViewArr;
@property (strong,nonatomic) NSMutableArray<UIImageView *>  *imageViewArr;
@property (strong,nonatomic) UIScrollView    *bgScrollView;

@property (assign,nonatomic) RGImageGalleryPushState pushState;
@property (assign,nonatomic) NSInteger      oldPage;
@property (assign,nonatomic) NSInteger      page;
@property (weak,nonatomic) id<RGImageGalleryDelegate> delegate;

+ (UIImage *)imageForTranslucentNavigationBar:(UINavigationBar *)navigationBar backgroundImage:(UIImage *)image;

- (instancetype)initWithPlaceHolder:(UIImage *)placeHolder andDelegate:(id)delegate;

- (void)showImageGalleryAtIndex:(NSInteger)Index fatherViewController:(UIViewController *)viewController;

- (void)addInteractionGestureShowImageGalleryAtIndex:(NSInteger)index fatherViewController:(UIViewController *)viewController fromView:(UIView *)view imageView:(UIImageView *)imageView;

- (void)showMessage:(NSString *)message atPercentY:(CGFloat)percentY;

- (void)updatePages:(NSIndexSet *)pages;
- (void)insertPages:(NSIndexSet *)pages;
- (void)deletePages:(NSIndexSet *)pages;

- (void)configToolBarItem;

- (void)setLoading:(BOOL)loading;

@end

@protocol RGImageGalleryDelegate <NSObject>

- (UIImage *)backgroundImageForImageGalleryBar:(RGImageGallery *)imageGallery;
- (UIImage *)backgroundImageForParentViewControllerBar;

- (NSInteger)numOfImagesForImageGallery:(RGImageGallery *)imageGallery;
- (UIView *)imageGallery:(RGImageGallery *)imageGallery thumbViewForPushAtIndex:(NSInteger)index;

- (UIImage *)imageGallery:(RGImageGallery *)imageGallery thumbnailAtIndex:(NSInteger)index targetSize:(CGSize)targetSize;
- (UIImage *)imageGallery:(RGImageGallery *)imageGallery imageAtIndex:(NSInteger)index targetSize:(CGSize)targetSize updateImage:(void(^_Nullable)(UIImage *image))updateImage;

- (UIColor *_Nullable)titleColorForImageGallery:(RGImageGallery *)imageGallery;
- (NSString *_Nullable)titleForImageGallery:(RGImageGallery *)imageGallery AtIndex:(NSInteger)index;

@optional

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
