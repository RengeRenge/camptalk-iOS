//
//  ImageGallery.m
//  yb
//
//  Created by LD on 16/4/2.
//  Copyright © 2016年 acumen. All rights reserved.
//

#import "RGImageGallery.h"

#define TEXTFONTSIZE 14
#define BUTTON_CLICK_WIDTH  100
#define BUTTON_CLICK_HEIGHT 100
#define pageWidth (kScreenWidth + 20)

#define kScreenWidth    (self.view.bounds.size.width)
#define kScreenHeight   (self.view.bounds.size.height)
#define kTargetSize     CGSizeMake(kScreenWidth*[UIScreen mainScreen].scale, kScreenHeight*[UIScreen mainScreen].scale)

#define SYSTEM_LESS_THAN(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)
#define ButtonTag 12222

typedef enum : NSUInteger {
    RGIGViewIndexL=0,
    RGIGViewIndexM,
    RGIGViewIndexR,
    RGIGViewIndexCount,
} RGIGViewIndex;

@interface UIBigButton: UIButton

@end

@implementation UIBigButton

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    CGRect bounds =self.bounds;
    CGFloat widthDelta = BUTTON_CLICK_WIDTH - bounds.size.width;
    CGFloat heightDelta = BUTTON_CLICK_HEIGHT - bounds.size.height;
    bounds = CGRectInset(bounds, -0.5 * widthDelta, -0.5* heightDelta);
    return CGRectContainsPoint(bounds, point);
}

@end

@class IGNavigationControllerDelegate;
@class IGPushAndPopAnimationController;
@class IGInteractionController;

@interface IGNavigationControllerDelegate : NSObject <UINavigationControllerDelegate>

@property (nonatomic, assign) BOOL interactive;
@property (nonatomic, assign) BOOL operateSucceed;
@property (nonatomic, assign) CGFloat leftProgress;
@property (nonatomic, strong) IGPushAndPopAnimationController *animationController;
@property (nonatomic, strong) IGInteractionController *interactionController;
@property (nonatomic, strong) NSMutableArray<IGInteractionController *> *interactionControllers;

- (IGInteractionController *)addPinchGestureOnView:(UIView *)view FromVC:(UIViewController *)fromVC toVC:(UIViewController *)toVC;

@end

@interface IGPushAndPopAnimationController : NSObject <UIViewControllerAnimatedTransitioning>

@property (nonatomic, assign) UINavigationControllerOperation operation;

@property (nonatomic, weak) IGNavigationControllerDelegate *transitionDelegate;

- (instancetype)initWithNavigationControllerOperation:(UINavigationControllerOperation)operation;

@end

@interface IGInteractionController : UIPercentDrivenInteractiveTransition <UIGestureRecognizerDelegate>

@property (nonatomic, assign) CGRect originalFrame;
@property (nonatomic, assign) CGPoint originalCenter;
@property (nonatomic, assign) CGFloat scale;

@property (nonatomic, assign) CGFloat maxScale;
@property (nonatomic, assign) NSInteger index;

@property (nonatomic, strong) UIGestureRecognizer *gestureRecognizer;

@property (nonatomic, strong) UIPanGestureRecognizer *panGestureRecognizer;
@property (nonatomic, strong) UIPinchGestureRecognizer *pinchGestureRecognizer;

@property (nonatomic, assign) UINavigationControllerOperation operation;

@property (nonatomic, weak) UIViewController *toVC;
@property (nonatomic, weak) UIViewController *fromVC;
@property (nonatomic, weak) UIView *view;
@property (nonatomic, weak) IGNavigationControllerDelegate *transitionDelegate;

- (void)addPinchGestureOnView:(UIView *)view;

@end

@interface RGImageGallery() <UIScrollViewDelegate, UIAlertViewDelegate, UIGestureRecognizerDelegate>

@property (strong,nonatomic) NSMutableArray<UIScrollView *>  *scrollViewArr;
@property (strong,nonatomic) NSMutableArray<UIImageView *>  *imageViewArr;
@property (strong,nonatomic) UIScrollView    *bgScrollView;

@property (assign,nonatomic) NSInteger      oldPage;


@property (nonatomic, strong) IGNavigationControllerDelegate *navigationControllerDelegate;
@property (nonatomic, strong) UILabel        *titleLabel;

@property (nonatomic, strong) UIToolbar       *toolbar;

@property (nonatomic, assign) CGSize lastSize;

@property (nonatomic, strong) NSMutableArray  *playButtonArr;

@property (nonatomic, strong) UIImage         *placeHolder;
@property (nonatomic, strong) UIImage         *barBackgroundImage;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicatorView;

@property (nonatomic, weak) id  viewControllerF;

@property (nonatomic, assign) BOOL hideTopBar;
@property (nonatomic, assign) BOOL hideToolBar;

- (CGRect)getImageViewFrameWithImage:(UIImage *)image;

@end

@implementation RGImageGallery

@synthesize pushState = _pushState;

- (instancetype)initWithPlaceHolder:(UIImage *)placeHolder andDelegate:(id)delegate{
    self = [super init];
    if(self){
        self.delegate       =   delegate;
        self.placeHolder    =   placeHolder;
        self.barBackgroundImage = nil;
        _page           =   0;
        _pushState         =   RGImageGalleryPushStateNoPush;
    }
    return self;
}
enum{
    leftFix,
    share,
    fix,
    play,
    fix2,
    delete,
    rightFix
};

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    
    if (!self.pushFromView || self.pushState == RGImageGalleryPushStatePushing) {
        [self getCountWithSetContentSize:YES];

        //Load OtherImage
        for (int i=0; i < self.scrollViewArr.count; i++) {
            if (i != RGIGViewIndexM || !self.pushFromView) {
                [self loadThumbnail:self.imageViewArr[i] withScrollView:self.scrollViewArr[i] atPage:_page-RGIGViewIndexM+i];
            }
        }
        [self reloadTitle];
        [self reloadToolBarItem];
        
        //Sequence ScrollViews
        [self setPositionAtPage:_page ignoreIndex:-1];
        
        [self.bgScrollView setDelegate:nil];
        [self.bgScrollView setContentOffset:CGPointMake(_page*pageWidth, 0) animated:NO];
        [self getCountWithSetContentSize:YES];
        [self.bgScrollView setDelegate:self];
    }
    if (!self.pushFromView) {
        [self hide:NO toolbarWithAnimateDuration:0];
    }
    [self hide:self.hideTopBar topbarWithAnimateDuration:0 backgroundChange:NO];
}

- (void)viewDidLoad{
    [super viewDidLoad];
    [self.view setBackgroundColor:[UIColor whiteColor]];
    [self initImageScrollViewArr];
    [self.view addSubview:self.bgScrollView];
    _hideTopBar = NO;
    _hideToolBar = NO;

    self.toolbar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.toolbar];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.view
                                                          attribute:NSLayoutAttributeLeading
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self.toolbar
                                                          attribute:NSLayoutAttributeLeading
                                                         multiplier:1
                                                           constant:0]];
    
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.view
                                                          attribute:NSLayoutAttributeTrailing
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self.toolbar
                                                          attribute:NSLayoutAttributeTrailing
                                                         multiplier:1
                                                           constant:0]];
    
    if (@available(iOS 11.0, *)) {;
        [self.toolbar.lastBaselineAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor].active = YES;
    } else {
        [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.toolbar
                                                              attribute:NSLayoutAttributeBottom
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:self.view
                                                              attribute:NSLayoutAttributeBottom
                                                             multiplier:1
                                                               constant:0]];
    }
    
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
    
    //Load Visiable Image
    [self setMiddleImageViewForPushWithScale:NO];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self loadLargeImageForCurrentPage];
    [self __setNavigationBarAndTabBarForImageGallery:YES];
    
    if (self.pushFromView) {
        self.navigationController.delegate = self.navigationControllerDelegate;
        [self.navigationControllerDelegate addPinchGestureOnView:self.view FromVC:self toVC:_viewControllerF].operation = UINavigationControllerOperationPop;
    }
    _pushState = RGImageGalleryPushStatePushed;
    [self hide:!self.hideTopBar topbarWithAnimateDuration:0 backgroundChange:NO];
    [self hide:self.hideTopBar topbarWithAnimateDuration:0 backgroundChange:NO];
}

- (UIToolbar *)toolbar {
    if (!_toolbar) {
        _toolbar = [[UIToolbar alloc] init];
        _toolbar.barStyle = UIBarStyleDefault;
        _toolbar.alpha = 0.0f;
    }
    return _toolbar;
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    _pushState = RGImageGalleryPushStateNoPush;
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    if (CGSizeEqualToSize(_lastSize, self.view.bounds.size)) {
        return;
    }
    _lastSize = self.view.bounds.size;
    
    [self.bgScrollView setDelegate:nil];
    // Update ContentSize
    [self getCountWithSetContentSize:YES];
    [self setPositionAtPage:_page ignoreIndex:-1];
    
    // Update ImageView Size
    for (int i=0; i<self.scrollViewArr.count && self.pushState != RGImageGalleryPushStatePushing; i++) {
        UIImageView *imageView = self.imageViewArr[i];
        CGRect rect = [self getImageViewFrameWithImage:imageView.image];
        [imageView setFrame:rect];
        UIButton *play = [imageView viewWithTag:ButtonTag];
        play.center = CGPointMake(imageView.frame.size.width/2, imageView.frame.size.height/2);
    }
    [self.bgScrollView setContentOffset:CGPointMake(_page * pageWidth, 0) animated:NO];
    [self.bgScrollView setDelegate:self];
}

- (IGNavigationControllerDelegate *)navigationControllerDelegate {
    if (!_navigationControllerDelegate) {
        _navigationControllerDelegate = [[IGNavigationControllerDelegate alloc] init];
    }
    return _navigationControllerDelegate;
}

#pragma mark - UI
- (UIScrollView *)bgScrollView {
    if (!_bgScrollView) {
        _bgScrollView = [[UIScrollView alloc]initWithFrame:CGRectMake(0, 0, pageWidth, kScreenHeight)];
        [_bgScrollView setPagingEnabled:YES];
        [_bgScrollView setDelegate:self];
        [_bgScrollView setBackgroundColor:[UIColor clearColor]];
        [_bgScrollView setShowsHorizontalScrollIndicator:NO];
        _bgScrollView.bounces = YES;
        
        if (@available(iOS 11.0, *)) {
            _bgScrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        }
        
        UITapGestureRecognizer *singleTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideBar:)];
        singleTapGesture.cancelsTouchesInView = NO;
        singleTapGesture.delegate = self;
        [singleTapGesture setNumberOfTapsRequired:1];//单击
        [singleTapGesture setNumberOfTouchesRequired:1];//单点触碰
        _bgScrollView.userInteractionEnabled = YES;
        [_bgScrollView addGestureRecognizer:singleTapGesture];
    }
    return _bgScrollView;
}

-(UILabel *)titleLabel {
    if (!_titleLabel) {
        _titleLabel = [[UILabel alloc]init];
        _titleLabel.numberOfLines = 2;
        _titleLabel.font = [UIFont systemFontOfSize:15];
        [_titleLabel setTextAlignment:NSTextAlignmentCenter];
    }
    return _titleLabel;
}

- (void)initImageScrollViewArr {
    self.imageViewArr = [NSMutableArray array];
    self.scrollViewArr = [NSMutableArray array];
    for (RGIGViewIndex i = 0; i < RGIGViewIndexCount; i++) {
        [self.imageViewArr addObject:[self buildImageView]];
        [self.scrollViewArr addObject:[self buildScrollView]];
        [self.scrollViewArr.lastObject addSubview:self.imageViewArr.lastObject];
        [self.bgScrollView addSubview:self.scrollViewArr.lastObject];
    }
}

- (UIImageView *)buildImageView {
    UIImageView *imageView = [[UIImageView alloc] init];
    [imageView setContentMode:UIViewContentModeScaleAspectFill];
    [imageView setClipsToBounds:YES];
    imageView.userInteractionEnabled = YES;
    imageView.backgroundColor = [UIColor clearColor];
    [imageView addSubview:[self buildPlayButton]];
    return imageView;
}

- (UIButton *)buildPlayButton {
    if (_delegate && [_delegate respondsToSelector:@selector(buttonForPlayVideo)]) {
        UIBigButton *play = [[UIBigButton alloc]init];
        UIImage *image = [_delegate buttonForPlayVideo];
        [play setImage:image forState:UIControlStateNormal];
        [play sizeToFit];
        
        UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(playItem)];
        tapGestureRecognizer.cancelsTouchesInView = NO;
        tapGestureRecognizer.delegate = self;
        [tapGestureRecognizer setNumberOfTapsRequired:1];
        [tapGestureRecognizer setNumberOfTouchesRequired:1];
        
        [play addGestureRecognizer:tapGestureRecognizer];
        play.tag = ButtonTag;
        play.clipsToBounds = YES;
        play.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.3];
        play.layer.cornerRadius = image.size.width/2;
        play.alpha = 0.0f;
        play.enabled = NO;
        return play;
    }
    return nil;
}

- (UIScrollView *)buildScrollView {
    UIScrollView *imageScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, kScreenWidth, kScreenHeight)];
    [imageScrollView setDelegate:self];
    return imageScrollView;
}

- (void)loadInfoWhenPageChanged:(BOOL)loadCurrentImage {
    [self reloadTitle];
    [self reloadToolBarItem];
    if (loadCurrentImage) {
        [self loadLargeImageForCurrentPage];
    }
}

- (void)reloadTitle {
    NSInteger page = self.page;
    NSInteger count = [self getCountWithSetContentSize:NO];
    if (page >= count || page < 0) {
        self.navigationItem.title = @"";
        return;
    }
    if (_delegate && [_delegate respondsToSelector:@selector(titleForImageGallery:AtIndex:)]) {
        self.navigationItem.title = [_delegate titleForImageGallery:self AtIndex:page];
        self.titleLabel.text = [_delegate titleForImageGallery:self AtIndex:page];
        [self.titleLabel sizeToFit];
    }
    if (_delegate && [_delegate respondsToSelector:@selector(titleColorForImageGallery:)]) {
        UIColor *color = [_delegate titleColorForImageGallery:self];
        self.titleLabel.textColor = color;
        self.toolbar.tintColor = color;
    }
    self.navigationItem.titleView = nil;
    self.navigationItem.titleView = _titleLabel;
}

- (void)setMiddleImageViewForPushSetScale:(CGFloat)scale setCenter:(BOOL)setCenter orignalFrame:(CGRect)originalFrame centerX:(CGFloat)x cencentY:(CGFloat)y {
    
    UIImageView *imageView = self.imageViewArr[RGIGViewIndexM];
    
    if (!imageView.image) {
        [imageView setImage:[self getPushImage]];
    }
    
    originalFrame.size.height *= scale;
    originalFrame.size.width  *= scale;
    
    if (setCenter) {
        imageView.frame = originalFrame;
        imageView.center = CGPointMake(x, y);
    } else {
        CGPoint center = imageView.center;
        imageView.frame = originalFrame;
        imageView.center = center;
    }
    [self setMiddleImageViewPlayButton];
}

- (void)setMiddleImageViewForPopSetScale:(CGFloat)scale setCenter:(BOOL)setCenter centerX:(CGFloat)x cencentY:(CGFloat)y {
    
    UIImageView *imageView = self.imageViewArr[RGIGViewIndexM];
    
    if (!imageView.image) {
        [imageView setImage:[self getPushImage]];
    }
    
    CGRect originalFrame = [self getImageViewFrameWithImage:imageView.image];
    
    originalFrame.size.height *= scale;
    originalFrame.size.width  *= scale;
    
    if (setCenter) {
        imageView.frame = originalFrame;
        imageView.center = CGPointMake(x, y);
    } else {
        CGPoint center = imageView.center;
        imageView.frame = originalFrame;
        imageView.center = center;
    }
    [self setMiddleImageViewPlayButton];
}

- (void)setMiddleImageViewForPushWithScale:(BOOL)scale {
    if (!self.isViewLoaded) {
        return;
    }
    UIImageView *imageView = self.imageViewArr[RGIGViewIndexM];
    imageView.image = [self getPushImage];
    
    imageView.frame = scale ? [self getPushViewFrameScaleFit] : [self getPushViewFrame];
    
    if (_delegate && [_delegate respondsToSelector:@selector(isVideoAtIndex:)]) {
        UIButton *play = [imageView viewWithTag:ButtonTag];
        if (_delegate && [_delegate respondsToSelector:@selector(isVideoAtIndex:)] && [_delegate isVideoAtIndex:_page]) {
            play.enabled = YES;
        } else {
            play.enabled = NO;
        }
        [self setMiddleImageViewPlayButton];
    }
}

- (void)setMiddleImageViewWhenPopFinished {
    if ([self getCountWithSetContentSize:NO] != 0) {
        UIImageView *imageView = self.imageViewArr[RGIGViewIndexM];
        CGRect pushFrame = [self getPushViewFrame];
        imageView.frame = pushFrame;
        [self setMiddleImageViewPlayButton];
        UIButton *play = [imageView viewWithTag:ButtonTag];
        if (play) {
            play.alpha = 0.0f;
        }
    }
}

- (void)setMiddleImageViewWhenPushFinished {
    if ([self getCountWithSetContentSize:NO] != 0) {
        UIImageView *imageView = self.imageViewArr[RGIGViewIndexM];
        UIButton *play = [imageView viewWithTag:ButtonTag];
        
        CGRect pushFrame = [self getImageViewFrameWithImage:imageView.image];
        imageView.frame = pushFrame;
        if (play.enabled) {
            play.center = CGPointMake(imageView.frame.size.width/2, imageView.frame.size.height/2);
            play.alpha = 1.0f;
        }
        play.transform = CGAffineTransformMakeScale(1, 1);
    }
}

- (void)setMiddleImageViewWhenPushAnimate {
    if ([self getCountWithSetContentSize:NO] != 0) {
        UIImageView *imageView = self.imageViewArr[RGIGViewIndexM];
        UIButton *play = [imageView viewWithTag:ButtonTag];
        
        CGRect oFrame = imageView.frame;
        CGRect pushFrame = [self getImageViewFrameWithImage:imageView.image];
        
        CGFloat pWidth = CGRectGetWidth(pushFrame);
        CGFloat pHeight = CGRectGetHeight(pushFrame);
        
        CGFloat pct = 0.03;
        CGFloat offSetX = pWidth * pct;
        CGFloat offSetY = pHeight * pct;
        CGFloat minOffSet = 8;
        CGFloat maxOffSet = MIN(pWidth*0.1, pHeight*0.1);
        if (minOffSet < maxOffSet) {
            if (offSetX < minOffSet) {
                offSetX = minOffSet;
                pct = offSetX/pWidth;
                offSetY = pct*pHeight;
            }
            if (offSetY < minOffSet) {
                offSetY = minOffSet;
                pct = offSetY/pHeight;
                offSetX = pct*pWidth;
            }
        }
        
        __block BOOL L,R,U,D = NO;
        __block CGRect largePushFrame =
        CGRectInset(pushFrame, -pWidth*pct, -pHeight*pct);;
        
        void(^calOffSet)(CGPoint pP, CGPoint oP) = ^(CGPoint pP, CGPoint oP) {
            if (!L && pP.x < oP.x) { // 向左
                L = YES;
                largePushFrame.origin.x -= offSetX;
            }
            if (!R && pP.x > oP.x) { // 向右
                R = YES;
                largePushFrame.origin.x += offSetX;
            }
            if (!U && pP.y < oP.y) { // 向上
                U = YES;
                largePushFrame.origin.y -= offSetY;
            }
            if (!D && pP.y > oP.y) { // 向下
                D = YES;
                largePushFrame.origin.y += offSetY;
            }
        };
        
        calOffSet(pushFrame.origin, oFrame.origin);
        calOffSet(
                  CGPointMake(CGRectGetMaxX(pushFrame), CGRectGetMaxY(pushFrame)),
                  CGPointMake(CGRectGetMaxX(oFrame), CGRectGetMaxY(oFrame))
                  );
        calOffSet(
                  CGPointMake(CGRectGetMaxX(pushFrame), CGRectGetMinY(pushFrame)),
                  CGPointMake(CGRectGetMaxX(oFrame), CGRectGetMinY(oFrame))
                  );
        calOffSet(
                  CGPointMake(CGRectGetMinX(pushFrame), CGRectGetMaxY(pushFrame)),
                  CGPointMake(CGRectGetMinX(oFrame), CGRectGetMaxY(oFrame))
                  );
        imageView.frame = largePushFrame;
        
        if (play.enabled) {
            play.center = CGPointMake(imageView.frame.size.width/2, imageView.frame.size.height/2);
            play.alpha = 1.0f;
        }
        play.transform = CGAffineTransformMakeScale(1, 1);
    }
}

- (void)setMiddleImageViewPlayButton {
    UIImageView *imageView = self.imageViewArr[RGIGViewIndexM];
    UIButton *play = [imageView viewWithTag:ButtonTag];
    if (play) {
        play.center = CGPointMake(imageView.frame.size.width/2, imageView.frame.size.height/2);
        if (play.enabled) {
            play.alpha = imageView.frame.size.width / [self getImageViewFrameWithImage:imageView.image].size.width;
        }
        CGFloat scale = [self getImageViewFrameWithImage:imageView.image].size.width;
        if (scale != 0) {
            scale = imageView.frame.size.width / scale;
        }
        if (scale > 1) {
            scale = 1;
        }
        play.transform = CGAffineTransformMakeScale(scale, scale);
    }
}

- (void)reloadToolBarItem {
    BOOL display = NO;
    
    NSInteger page = self.page;
    NSInteger count = [self getCountWithSetContentSize:NO];
    if (page >= count || page < 0) {
        display = NO;
    } else {
        if (self.delegate && [self.delegate respondsToSelector:@selector(imageGallery:toolBarItemsShouldDisplayForIndex:)]) {
            display = [self.delegate imageGallery:self toolBarItemsShouldDisplayForIndex:page];
            
            if (display && self.delegate && [self.delegate respondsToSelector:@selector(imageGallery:toolBarItemsForIndex:)]) {
                [CATransaction begin];
                [CATransaction setDisableActions:YES];
                [self.toolbar setItems:[self.delegate imageGallery:self toolBarItemsForIndex:page] animated:NO];
                [CATransaction commit];
            }
        }
    }
    self.toolbar.hidden = !display;
}

- (NSInteger)getCountWithSetContentSize:(BOOL)setSize {
    NSInteger count = 0;
    if (_delegate && [_delegate respondsToSelector:@selector(numOfImagesForImageGallery:)]) {
        count = [_delegate numOfImagesForImageGallery:self];
        if (setSize) {
            self.bgScrollView.contentSize = CGSizeMake(count*pageWidth, 0);
            [self.bgScrollView setFrame:CGRectMake(0, 0, pageWidth, kScreenHeight)];
        }
    }
    return count;
}

- (void)setPositionAtPage:(NSInteger)page ignoreIndex:(NSInteger)ignore {
    NSInteger sum = [self getCountWithSetContentSize:NO];
    for (int i=0; i<self.scrollViewArr.count; i++) {
        NSInteger current = page-RGIGViewIndexM+i;
        UIScrollView *view = self.scrollViewArr[i];
        if (ignore != i) {
            if (current>=0 && current<sum) {
                [view setFrame:CGRectMake(pageWidth*current, 0, kScreenWidth, self.bgScrollView.frame.size.height)];
            } else {
                [view setFrame:CGRectMake(pageWidth*current, 0, kScreenWidth, self.bgScrollView.frame.size.height)];
            }
        }
    }
}

- (void)loadThumbnail:(UIImageView*)imageView withScrollView:(UIScrollView*)scrollView atPage:(NSInteger)page {
    
    if (page >= [self getCountWithSetContentSize:NO] || page < 0) {
        imageView.image = nil;
        return;
    }
    UIImage *image;
    image = [_delegate imageGallery:self thumbnailAtIndex:page targetSize:kTargetSize];
    
    //if image is nil , then show placeHolder
    if (!image) {
        image = _placeHolder;
    }
    
    if (image) {
        [imageView setImage:image];
        //set appropriate frame for imageView
        CGRect rect = [self getImageViewFrameWithImage:image];
        [imageView setFrame:rect];
        //设置最大的缩放比例为 不超过屏幕高度2倍
//        [scrollView setMaximumZoomScale:kScreenHeight/image.size.height*2];
    }
    UIButton *play = [imageView viewWithTag:ButtonTag];
    if (play) {
        play.center = CGPointMake(imageView.frame.size.width/2, imageView.frame.size.height/2);
        play.transform = CGAffineTransformMakeScale(1, 1);
        if (self->_delegate && [self->_delegate respondsToSelector:@selector(isVideoAtIndex:)]) {
            if ([self->_delegate isVideoAtIndex:page]) {
                play.enabled = YES;
                play.alpha = 1.0f;
            } else {
                play.enabled = NO;
                play.alpha = 0.0f;
            }
        }
    }
}

- (CGRect)getPushViewFrame {
    CGRect rect = CGRectZero;
    if (_delegate && [_delegate respondsToSelector:@selector(imageGallery:thumbViewForTransitionAtIndex:)]) {
        UIView *view = [_delegate imageGallery:self thumbViewForTransitionAtIndex:_page];
        //return view.frame;
        //getRect
        rect = [view convertRect:view.bounds toView:[self.viewControllerF view]];
    }
    return rect;
}

- (CGRect)getPushViewFrameScaleFit {
    
    UIImageView *imageView = self.imageViewArr[RGIGViewIndexM];
    if (!imageView.image) {
        [imageView setImage:[self getPushImage]];
    }
    
    CGRect pushFrame = [self getPushViewFrame];
    CGRect bigFrame = [self getImageViewFrameWithImage:imageView.image];
    CGFloat width = pushFrame.size.height / bigFrame.size.height *  bigFrame.size.width;
    if (width < pushFrame.size.width) {
        CGFloat height = bigFrame.size.height * pushFrame.size.width / bigFrame.size.width;
        pushFrame.origin.y += (pushFrame.size.height - height) / 2.0f;
        pushFrame.size.height = height;
    } else {
        pushFrame.origin.x += (pushFrame.size.width - width) / 2.0f;
        pushFrame.size.width = width;
    }
    return pushFrame;
}

- (CGFloat)getMaxScaleFitWithPushView:(UIView *)pushView image:(UIImage *)image {
    CGRect pushFrame = pushView.frame;
    CGRect bigFrame = [self getImageViewFrameWithImage:image];
    
    CGFloat width = pushFrame.size.height / bigFrame.size.height *  bigFrame.size.width;
    if (width < pushFrame.size.width) {
        CGFloat height = bigFrame.size.height * pushFrame.size.width / bigFrame.size.width;
        pushFrame.size.height = height;
    } else {
        pushFrame.size.width = width;
    }
    return bigFrame.size.width / pushFrame.size.width;
}


- (UIImage *)getPushImage {
    UIImage *image = nil;
    if (_delegate && [_delegate respondsToSelector:@selector(imageGallery:thumbnailAtIndex:targetSize:)]) {
        image = [_delegate imageGallery:self thumbnailAtIndex:_page targetSize:kTargetSize];
    }
    if (!image) {
        image = _placeHolder;
    }
    return image;
}

- (CGRect)getImageViewFrameWithImage:(UIImage *)image {
    if (image && image.size.height > 0 && image.size.width > 0) {
        CGFloat imageViewWidth = kScreenWidth;
        CGFloat imageViewHeight = image.size.height/image.size.width*imageViewWidth;
        if (imageViewHeight > kScreenHeight) {
            imageViewHeight = kScreenHeight;
            imageViewWidth = image.size.width/image.size.height*imageViewHeight;
        }
        return CGRectMake(kScreenWidth/2 - imageViewWidth/2, kScreenHeight/2 - imageViewHeight/2, imageViewWidth, imageViewHeight);
    }
    return CGRectZero;
}

- (void)loadLargeImageForCurrentPage {
    NSInteger page = self.page;
    UIImageView *imageView = self.imageViewArr[RGIGViewIndexM];
    
    NSInteger count = [self getCountWithSetContentSize:NO];
    if (page >= count || page < 0) {
        imageView.image = nil;
        return;
    }
    
    UIImage *image = [self.delegate imageGallery:self imageAtIndex:page targetSize:kTargetSize updateImage:^(UIImage * _Nonnull image) {
        if (image && self.page == page) {
            UIImageView *imageView = self.imageViewArr[RGIGViewIndexM];
            imageView.image = image;
            imageView.frame = [self getImageViewFrameWithImage:image];
        }
    }];
    if (image) {
        imageView.image = image;
        imageView.frame = [self getImageViewFrameWithImage:image];
    }
}

#pragma mark - UI Event

- (void)showImageGalleryAtIndex:(NSInteger)Index fatherViewController:(UIViewController *)viewController {
    if (self.pushState == RGImageGalleryPushStatePushing) {
        return;
    }
    _page       =   Index;
    _oldPage    =   Index;
    _hideTopBar = NO;
    _hideToolBar= NO;
    _pushState =   RGImageGalleryPushStatePushing;
    
    //Load Visiable Image
    [self setMiddleImageViewForPushWithScale:NO];
    
    //Show ImageGallery ViewController
    [self pushSelfByFatherViewController:viewController];
}

- (void)__showImageGalleryWithPingInteractionController:(IGInteractionController *)interactionController {
    if (self.pushFromView || self.pushState == RGImageGalleryPushStatePushing) {
        return;
    }
    _page       =   interactionController.index;
    _oldPage    =   interactionController.index;
    _hideTopBar = NO;
    _hideToolBar = NO;
    _pushState =   RGImageGalleryPushStatePushing;
    
    //Show ImageGallery ViewController
    [self pushSelfByFatherViewController:interactionController.fromVC];
}

- (void)addInteractionGestureShowImageGalleryAtIndex:(NSInteger)index fatherViewController:(UIViewController *)viewController fromView:(UIView *)view imageView:(UIImageView *)imageView {
    
    IGInteractionController *interactionController = [self.navigationControllerDelegate addPinchGestureOnView:view FromVC:viewController toVC:self];
    interactionController.index = index;
    
    if (imageView.image.size.width != 0) {
        interactionController.maxScale = [self getMaxScaleFitWithPushView:view image:imageView.image];
    }
    interactionController.operation = UINavigationControllerOperationPush;
}

- (void)hide:(BOOL)hide toolbarWithAnimateDuration:(NSTimeInterval)duration {
    [self.view bringSubviewToFront:self.toolbar];
    CGFloat alpha = hide ? 0.0f : 1.0f;
    if (duration > 0) {
        [UIView animateWithDuration:duration animations:^{
            self->_toolbar.alpha = alpha;
        }];
    } else {
        self.toolbar.alpha = alpha;
    }
}

- (void)hide:(BOOL)hide topbarWithAnimateDuration:(NSTimeInterval)duration backgroundChange:(BOOL)change {
    if (self.pushState == RGImageGalleryPushStatePushed) {
        dispatch_async(dispatch_get_main_queue(), ^{
            void (^animate)(void) = ^{
                if (self.navigationController) {
                    [self.navigationController setNavigationBarHidden:hide animated:NO];
                    [self prefersStatusBarHidden];
                    [self setNeedsStatusBarAppearanceUpdate];
                }
            };
            if (duration > 0) {
                [UIView animateWithDuration:duration animations:^{
                    animate();
                    if (change) {
                        [self.view setBackgroundColor:hide ? [UIColor blackColor] : [UIColor whiteColor]];
                    }
                }];
            } else {
                animate();
                if (change) {
                    [self.view setBackgroundColor:hide ? [UIColor blackColor] : [UIColor whiteColor]];
                }
            }
        });
    }
}

- (void)hideBar:(UILongPressGestureRecognizer *)recognizer {
    if (recognizer) {
        _hideTopBar = !_hideTopBar;
        _hideToolBar = !_hideToolBar;
        
        [self hide:_hideTopBar topbarWithAnimateDuration:0.4 backgroundChange:YES];
        [self hide:_hideToolBar toolbarWithAnimateDuration:0.4];
    } else {
        [self hide:NO topbarWithAnimateDuration:0 backgroundChange:NO];
    }
}

- (void)showParentViewControllerNavigationBar:(BOOL)show {
    if (((UIViewController *)_viewControllerF).navigationController.navigationBarHidden == show) {
        [((UIViewController *)_viewControllerF).navigationController setNavigationBarHidden:!show animated:NO];
    }
}

- (BOOL)prefersStatusBarHidden {
    return self.navigationController.navigationBarHidden;
}

-(void)pushSelfByFatherViewController:(UIViewController *)viewController {
    _viewControllerF = viewController;
    [_viewControllerF setHidesBottomBarWhenPushed:YES];
    if (self.pushFromView) {
        viewController.navigationController.delegate = self.navigationControllerDelegate;
    }
    [self __setNavigationBarAndTabBarForImageGallery:YES];
    [viewController.navigationController pushViewController:self animated:YES];
}

- (void)__setNavigationBarAndTabBarForImageGallery:(BOOL)set {
    self.automaticallyAdjustsScrollViewInsets = NO;
    if (![self.delegate respondsToSelector:@selector(configNavigationBarForImageGallery:imageGallery:)]) {
        return;
    }
    [self.delegate configNavigationBarForImageGallery:set imageGallery:self];
}

- (void)setLoading:(BOOL)loading {
    if (loading && !_activityIndicatorView) {
        _activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        _activityIndicatorView.center = CGPointMake(self.view.frame.size.width/2.0f, self.view.frame.size.height/2.0f);
        _activityIndicatorView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        [self.view addSubview:_activityIndicatorView];
    }
    if (loading) {
//        self.BgScrollView.scrollEnabled = NO;
        [self.view bringSubviewToFront:_activityIndicatorView];
        [_activityIndicatorView startAnimating];
    } else {
//        self.BgScrollView.scrollEnabled = YES;
        [_activityIndicatorView stopAnimating];
    }
}

#pragma mark - UIscrollview delegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if(self.bgScrollView == scrollView) {
        CGFloat scrollviewW =  scrollView.frame.size.width;
        CGFloat x = scrollView.contentOffset.x;
        _page = (x + scrollviewW / 2) /scrollviewW;
        if (_page>=0 && _page<[self getCountWithSetContentSize:NO]) {
            
            //change Left's Left's View
            if (_page > _oldPage) {
                UIScrollView *changeScView = self.scrollViewArr[0];
                UIImageView  *changeImageView = self.imageViewArr[0];
                
                [self.scrollViewArr removeObject:changeScView];
                [self.scrollViewArr addObject:changeScView];
                
                [self.imageViewArr removeObject:changeImageView];
                [self.imageViewArr addObject:changeImageView];
                
                CGRect rect = changeScView.frame;
                rect.origin.x = (_page+RGIGViewIndexM)*pageWidth;
                changeScView.frame  = rect;
                
                [self loadThumbnail:changeImageView withScrollView:changeScView atPage:_page+RGIGViewIndexM];
                [self loadInfoWhenPageChanged:NO];
                if (_delegate && [_delegate respondsToSelector:@selector(imageGallery:middleImageHasChangeAtIndex:)]) {
                    [_delegate imageGallery:self middleImageHasChangeAtIndex:_page];
                }
                _oldPage = _page;
                
            } else if (_page < _oldPage) { //change Right's Right's View
                
                UIScrollView *changeScView = self.scrollViewArr[RGIGViewIndexCount-1];
                UIImageView  *changeImageView = self.imageViewArr[RGIGViewIndexCount-1];
                [self.scrollViewArr removeObject:changeScView];
                [self.scrollViewArr insertObject:changeScView atIndex:0];
                
                [self.imageViewArr removeObject:changeImageView];
                [self.imageViewArr insertObject:changeImageView atIndex:0];

                CGRect rect = changeScView.frame;
                rect.origin.x = (_page-RGIGViewIndexM)*pageWidth;
                changeScView.frame  = rect;
                [self loadThumbnail:changeImageView withScrollView:changeScView atPage:_page-RGIGViewIndexM];
                [self loadInfoWhenPageChanged:NO];
                if (_delegate && [_delegate respondsToSelector:@selector(imageGallery:middleImageHasChangeAtIndex:)]) {
                    [_delegate imageGallery:self middleImageHasChangeAtIndex:_page];
                }
                _oldPage = _page;
            }
        }
    }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (decelerate == NO) {
        [self scrollViewDidEndDecelerating:scrollView];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [self loadLargeImageForCurrentPage];
}

#pragma mark - gesture Delegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if ([gestureRecognizer.view isKindOfClass:[UIBigButton class]]) {
        return NO;
    }
    if (gestureRecognizer.view == _bgScrollView && [otherGestureRecognizer.view isKindOfClass:[UIBigButton class]]) {
        return NO;
    }
    if (gestureRecognizer.view == _bgScrollView && self.navigationControllerDelegate.interactive) {
        return NO;
    }
    return YES;
}

#pragma mark - tool function

- (void)playItem {
    if (self.navigationControllerDelegate.interactive) {
        return;
    }
    if (_delegate && [_delegate respondsToSelector:@selector(imageGallery:selectePlayVideoAtIndex:)]) {
        if ([_delegate imageGallery:self selectePlayVideoAtIndex:_page]){ }
    }
}

#pragma mark - public function

- (void)updatePages:(NSIndexSet *)pages {
    if (!pages.count) {
        return;
    }
    
    [pages enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
        for (RGIGViewIndex i = 0; i < self.scrollViewArr.count; i++) {
            if (self.page - RGIGViewIndexM + i == idx) {
                if (i == RGIGViewIndexM) {
                    [self loadInfoWhenPageChanged:YES];
                    if (self.delegate && [self.delegate respondsToSelector:@selector(imageGallery:middleImageHasChangeAtIndex:)]) {
                        [self.delegate imageGallery:self middleImageHasChangeAtIndex:idx];
                    }
                } else {
                    [self loadThumbnail:self.imageViewArr[i] withScrollView:self.scrollViewArr[i] atPage:idx];
                }
            }
        }
    }];
}

- (void)insertPages:(NSIndexSet *)pages {
    if (!pages.count) {
        return;
    }
    
    __block NSInteger forwardPage = 0;
    __block BOOL containCurrentPage = NO;
    
    [pages enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
        if (idx <= self.page) {
            forwardPage ++;
            self->_page ++;
        }
        if (idx == self.page) {
            containCurrentPage = YES;
        }
    }];
    
    if (forwardPage > 0) {
        if (_delegate && [_delegate respondsToSelector:@selector(imageGallery:middleImageHasChangeAtIndex:)]) {
            [_delegate imageGallery:self middleImageHasChangeAtIndex:_page];
        }
        
        // scroll
        [self setPositionAtPage:_page ignoreIndex:-1];
        [self.bgScrollView setDelegate:nil];
        [self.bgScrollView setContentOffset:CGPointMake(_page*pageWidth, 0) animated:NO];
        [self.bgScrollView setDelegate:self];
    }
    
    [self getCountWithSetContentSize:YES];
    [self loadInfoWhenPageChanged:NO];
    
    for (RGIGViewIndex i = 0; i < self.scrollViewArr.count; i++) {
        if (i == RGIGViewIndexM) {
            continue;
        }
        // reload insert pages
        NSInteger newPage = _page - RGIGViewIndexM + i;
        if ([pages containsIndex:newPage]) {
            [self loadThumbnail:self.imageViewArr[i] withScrollView:self.scrollViewArr[i] atPage:newPage];
        }
    }
    _oldPage = _page;
}

- (void)deletePages:(NSIndexSet *)pages {
    if (!pages.count) {
        return;
    }
    
    NSInteger newCount = [self getCountWithSetContentSize:NO];
    NSInteger oldCount = self.bgScrollView.contentSize.width / pageWidth;
    
    BOOL hasDataAfterCurrentPage = self.page < (oldCount - 1);
    
    __block NSInteger forwardPage = 0;
    __block BOOL containCurrentPage = NO;
    [pages enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
        if (idx < self.page) {
            forwardPage ++;
        }
        if (idx == self.page) {
            containCurrentPage = YES;
        }
    }];
    
    _page -= forwardPage;
    
    if (_page > newCount - 1) {
        _page = newCount - 1;
        hasDataAfterCurrentPage = NO;
    }
    if (_page < 0) {
        _page = 0;
    }
    
    if (forwardPage > 0 || containCurrentPage) {
        if (_delegate && [_delegate respondsToSelector:@selector(imageGallery:middleImageHasChangeAtIndex:)]) {
            [_delegate imageGallery:self middleImageHasChangeAtIndex:_page];
        }
        
        // forward
        [self setPositionAtPage:_page ignoreIndex:-1];
        [self.bgScrollView setDelegate:nil];
        [self.bgScrollView setContentOffset:CGPointMake(_page*pageWidth, 0) animated:NO];
        [self.bgScrollView setDelegate:self];
    }
    
    if (!containCurrentPage) {
        [self getCountWithSetContentSize:YES]; // adjust contentsize
        [self loadInfoWhenPageChanged:NO];
    }
    
    for (RGIGViewIndex i = 0; i < self.scrollViewArr.count; i++) {
        if (i == RGIGViewIndexM) {
            continue;
        }
        // reload deleted pages
        NSInteger oldPage = _oldPage - RGIGViewIndexM + i;
        if ([pages containsIndex:oldPage]) {
        
            NSInteger newPage = _page - RGIGViewIndexM + i;
            if (containCurrentPage) {
                if (hasDataAfterCurrentPage) {
                    if (i > RGIGViewIndexM) {
                        newPage -= 1;
                    }
                } else {
                    if (i < RGIGViewIndexM) {
                        newPage += 1;
                    }
                }
            }
            
            [self loadThumbnail:self.imageViewArr[i] withScrollView:self.scrollViewArr[i] atPage:newPage];
        }
    }
    _oldPage = _page;
    
    if (!containCurrentPage) {
        return;
    }
    
    UIImageView *deleteImageView = self.imageViewArr[RGIGViewIndexM];
    UIScrollView *deleteScrollView = self.scrollViewArr[RGIGViewIndexM];
    
    if (newCount == 0) {
        UIImageView *deleteImageView = self.imageViewArr[RGIGViewIndexM];
        UIButton *deleteButton = self.playButtonArr[RGIGViewIndexM];
        [UIView animateWithDuration:0.3 animations:^{
            deleteImageView.alpha = 0.0f;
            deleteImageView.transform =  CGAffineTransformMakeScale(0.5f, 0.5f);
            deleteButton.alpha = 0.0f;
        }completion:^(BOOL finished) {
            deleteImageView.image = nil;
            deleteImageView.alpha = 1.0f;
            deleteImageView.transform =  CGAffineTransformMakeScale(1.0f, 1.0f);
            deleteButton.alpha = 1.0f;
            
            self.navigationController.delegate = nil;
            [self.navigationController popViewControllerAnimated:YES];
            [self __setNavigationBarAndTabBarForImageGallery:NO];
            UINavigationController *ngv = self.navigationController;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (ngv.navigationBarHidden) {
                    [ngv setNavigationBarHidden:NO animated:NO];
                }
            });
        }];
    } else if (hasDataAfterCurrentPage) { // 后面还有数据，把后面的数据挪到前面
        
        [self.imageViewArr exchangeObjectAtIndex:RGIGViewIndexM withObjectAtIndex:RGIGViewIndexCount - 1];
        [self.scrollViewArr exchangeObjectAtIndex:RGIGViewIndexM withObjectAtIndex:RGIGViewIndexCount - 1];

        [UIView animateWithDuration:0.3 animations:^{
            deleteScrollView.alpha = 0.0f;
            deleteImageView.transform =  CGAffineTransformMakeScale(0.5f, 0.5f);
            [self setPositionAtPage:self.page ignoreIndex:RGIGViewIndexCount - 1];
        } completion:^(BOOL finished) {
            [self setPositionAtPage:self.page ignoreIndex:-1];
            
            deleteScrollView.alpha = 1.0f;
            deleteImageView.transform =  CGAffineTransformMakeScale(1.0f, 1.0f);
            
            [self getCountWithSetContentSize:YES];
            
            [self loadThumbnail:deleteImageView withScrollView:deleteScrollView atPage:self.page+RGIGViewIndexM];
            [self loadInfoWhenPageChanged:YES];
            if (self.delegate && [self.delegate respondsToSelector:@selector(imageGallery:middleImageHasChangeAtIndex:)]) {
                [self.delegate imageGallery:self middleImageHasChangeAtIndex:self.page];
            }
        }];
        
    } else {
        
        [self.imageViewArr exchangeObjectAtIndex:RGIGViewIndexM withObjectAtIndex:0];
        [self.scrollViewArr exchangeObjectAtIndex:RGIGViewIndexM withObjectAtIndex:0];
        
        [UIView animateWithDuration:0.3 animations:^{
            deleteScrollView.alpha = 0.0f;
            deleteImageView.transform =  CGAffineTransformMakeScale(0.5f, 0.5f);
            [self setPositionAtPage:self.page ignoreIndex:0];
        } completion:^(BOOL finished) {
            [self setPositionAtPage:self.page ignoreIndex:-1];
            
            deleteScrollView.alpha = 1.0f;
            deleteImageView.transform =  CGAffineTransformMakeScale(1.0f, 1.0f);
            
            [self getCountWithSetContentSize:YES];
            
            [self loadThumbnail:deleteImageView withScrollView:deleteScrollView atPage:self.page-RGIGViewIndexM];
            [self loadInfoWhenPageChanged:YES];
            if (self.delegate && [self.delegate respondsToSelector:@selector(imageGallery:middleImageHasChangeAtIndex:)]) {
                [self.delegate imageGallery:self middleImageHasChangeAtIndex:self.page];
            }
        }];
    }
}

- (void)showMessage:(NSString *)message atPercentY:(CGFloat)percentY{
    UILabel *label = [[UILabel alloc]initWithFrame:CGRectMake(10, 5, 0, 0)];
    label.textColor = [UIColor whiteColor];
    label.textAlignment = 1;
    label.backgroundColor = [UIColor clearColor];
    label.font = [UIFont boldSystemFontOfSize:TEXTFONTSIZE];
    label.text = message;
    [label sizeToFit];
    
    UIView *showview =  [[UIView alloc]init];
    showview.backgroundColor = [UIColor blackColor];
    
    CGRect rect = label.frame;
    rect.size.width+=20;
    rect.size.height+=10;
    showview.frame = rect;
    showview.center = CGPointMake(self.view.frame.size.width/2.0f, self.view.frame.size.height * percentY);

    showview.alpha = 1.0f;
    showview.layer.cornerRadius = 5.0f;
    showview.layer.masksToBounds = YES;
    
    [self.view addSubview:showview];
    [showview addSubview:label];
    
    [UIView animateWithDuration:2.5 animations:^{
        showview.alpha = 0;
    } completion:^(BOOL finished) {
        [showview removeFromSuperview];
    }];
}

+ (UIImage *)imageForTranslucentNavigationBar:(UINavigationBar *)navigationBar backgroundImage:(UIImage *)image {
    if (SYSTEM_LESS_THAN(@"10")) {
        if (image!=nil) {
            CGRect rect = navigationBar.frame;
            rect.origin.y = 0;
            rect.size.height += 20;
            CGFloat scale = image.size.width/rect.size.width;
            
            rect.size.height *= scale*[[UIScreen mainScreen] scale];
            rect.size.width  *= scale*[[UIScreen mainScreen] scale];
            
            CGImageRef subImageRef = CGImageCreateWithImageInRect(image.CGImage, rect);
            UIImage* smallImage = [UIImage imageWithCGImage:subImageRef];
            CGImageRelease(subImageRef);
            return smallImage;
        }
    }
    return image;
}

@end

#pragma mark - Push And Pop Animate

#define animateTtransitionDuration 2.35f
#define animatePopTtransitionDuration 0.2f
#define interationTtransitionDuration 0.2f

#define DampingRatio    0.7     //弹性的阻尼值
#define Velocity        0.01    //弹簧的修正速度

@implementation IGNavigationControllerDelegate

- (id<UIViewControllerAnimatedTransitioning>)navigationController:(UINavigationController *)navigationController animationControllerForOperation:(UINavigationControllerOperation)operation fromViewController:(UIViewController *)fromVC toViewController:(UIViewController *)toVC {
    if (operation == UINavigationControllerOperationPush && [fromVC isKindOfClass:RGImageGallery.class]) {
        return nil;
    }
    if (operation == UINavigationControllerOperationPop && [toVC isKindOfClass:RGImageGallery.class]) {
        return nil;
    }
    _animationController = [[IGPushAndPopAnimationController alloc] initWithNavigationControllerOperation:operation];
    _animationController.transitionDelegate = self;
    return _animationController;
}

- (id<UIViewControllerInteractiveTransitioning>)navigationController:(UINavigationController *)navigationController interactionControllerForAnimationController:(id<UIViewControllerAnimatedTransitioning>)animationController {
    if (self.interactive) {
        self.leftProgress = 1.0f;
        return _interactionController;
    }
    self.leftProgress = 0.0f;
    self.operateSucceed = YES;
    return nil;
}

- (NSMutableArray<IGInteractionController *> *)interactionControllers {
    if (!_interactionControllers) {
        _interactionControllers = [NSMutableArray array];
    }
    return _interactionControllers;
}

- (IGInteractionController *)addPinchGestureOnView:(UIView *)view FromVC:(UIViewController *)fromVC toVC:(UIViewController *)toVC  {
    for (IGInteractionController *interactionController in self.interactionControllers) {
        if (interactionController.view == view) {
            return interactionController;
        }
    }
    IGInteractionController *interactionController = [[IGInteractionController alloc] init];
    interactionController.toVC = toVC;
    interactionController.fromVC = fromVC;
    interactionController.transitionDelegate = self;
    [interactionController addPinchGestureOnView:view];
    [self.interactionControllers addObject:interactionController];
    return interactionController;
}

@end

@implementation IGInteractionController

- (UIPinchGestureRecognizer *)pinchGestureRecognizer {
    if (!_pinchGestureRecognizer) {
        _pinchGestureRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(pinchGesture:)];
        _pinchGestureRecognizer.delegate = self;
    }
    return _pinchGestureRecognizer;
}

- (UIPanGestureRecognizer *)panGestureRecognizer {
    if (!_panGestureRecognizer) {
        _panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(moveGesture:)];
        [_panGestureRecognizer setMinimumNumberOfTouches:1];
        [_panGestureRecognizer setMaximumNumberOfTouches:4];
        _panGestureRecognizer.delegate = self;
    }
    return _panGestureRecognizer;
}

- (void)setMaxScale:(CGFloat)maxScale {
    if (maxScale < 0) {
        _maxScale = -1;
    } else {
        _maxScale = maxScale;
    }
}

- (void)addPinchGestureOnView:(UIView *)view {
    self.view = view;
    self.index = -1;
    self.maxScale = -1;
    [view addGestureRecognizer:self.pinchGestureRecognizer];
    [view addGestureRecognizer:self.panGestureRecognizer];
}

- (void)pinchGesture:(UIPinchGestureRecognizer *)gesture {
    
    RGImageGallery *imageGallery;
    if ([self.fromVC isKindOfClass:[RGImageGallery class]]) {
        imageGallery = (RGImageGallery *)self.fromVC;
    }
    
    if ([self.toVC isKindOfClass:[RGImageGallery class]]) {
        imageGallery = (RGImageGallery *)self.toVC;
    }
    
    BOOL selfGesture = gesture == self.gestureRecognizer;
    if (selfGesture) {
        self.scale = gesture.scale;
    }
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan: {
            if (!SYSTEM_LESS_THAN(@"8") &&
                !self.transitionDelegate.interactive &&
                gesture.scale >= 1.0f &&
                self.operation == UINavigationControllerOperationPush &&
                ![self.fromVC.navigationController.viewControllers containsObject:self.toVC]) {
                
                self.gestureRecognizer = gesture;
                self.transitionDelegate.interactionController = self;
                self.transitionDelegate.interactive = YES;
                
                [imageGallery __showImageGalleryWithPingInteractionController:self];
                
                self.originalFrame = imageGallery.imageViewArr[RGIGViewIndexM].frame;
                self.originalCenter = imageGallery.imageViewArr[RGIGViewIndexM].center;

            } else if (!self.transitionDelegate.interactive &&
                       self.operation == UINavigationControllerOperationPop &&
                       [self.toVC.navigationController.viewControllers containsObject:self.fromVC]) {
                
                self.gestureRecognizer = gesture;
                self.transitionDelegate.interactionController = self;
                self.transitionDelegate.interactive = YES;
                [imageGallery hide:NO topbarWithAnimateDuration:0.3 backgroundChange:NO];
                [self.fromVC.navigationController popViewControllerAnimated:YES];
            }
            break;
        }
        case UIGestureRecognizerStateChanged: {
            if (!self.transitionDelegate.interactive) {
                return;
            }
            if (self.operation == UINavigationControllerOperationPush) {
                [imageGallery setMiddleImageViewForPushSetScale:self.scale setCenter:NO orignalFrame:self.originalFrame centerX:0 cencentY:0];
            }
            if (self.operation == UINavigationControllerOperationPop) {
                if (self.scale <= 3) {
                    [imageGallery setMiddleImageViewForPopSetScale:self.scale setCenter:NO centerX:0 cencentY:0];
                }
            }
            if (selfGesture) {
                [self updateInteractiveTransition:[self getProgressWithScale:self.scale limit:YES]];
            }
            break;
        }
        case UIGestureRecognizerStateEnded: case UIGestureRecognizerStateCancelled: {
            if (!self.transitionDelegate.interactive) {
                return;
            }
            if (selfGesture) {
                CGFloat progress = [self getProgressWithScale:self.scale limit:YES];
                BOOL isSucceed = NO;
                if (self.operation == UINavigationControllerOperationPush) {
                    isSucceed = (progress > 0.0f);
                }
                if (self.operation == UINavigationControllerOperationPop) {
                    isSucceed = (progress >= 0.2f);
                }
                [self finishInteractiveTransitionWithSucceed:isSucceed progress:progress];
            }
            break;
        }
        default: {
            NSLog(@"%ld", (long)gesture.state);
        }
    }
}

- (void)moveGesture:(UIPanGestureRecognizer *)gesture {
    
    CGPoint translatedPoint = [gesture translationInView:gesture.view];
    
    RGImageGallery *imageGallery;
    if ([self.fromVC isKindOfClass:[RGImageGallery class]]) {
        imageGallery = (RGImageGallery *)self.fromVC;
    }
    
    if ([self.toVC isKindOfClass:[RGImageGallery class]]) {
        imageGallery = (RGImageGallery *)self.toVC;
    }
    
    BOOL selfGesture = gesture == self.gestureRecognizer;
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan: {
            if (self.operation == UINavigationControllerOperationPop) {
                self.originalFrame = imageGallery.imageViewArr[RGIGViewIndexM].frame;
                self.originalCenter = imageGallery.imageViewArr[RGIGViewIndexM].center;
                if (!self.transitionDelegate.interactive) {
                    self.gestureRecognizer = gesture;
                    self.transitionDelegate.interactionController = self;
                    self.transitionDelegate.interactive = YES;
                    [imageGallery hide:NO topbarWithAnimateDuration:0.3 backgroundChange:NO];
                    [self.fromVC.navigationController popViewControllerAnimated:YES];
                }
            }
            if (self.operation == UINavigationControllerOperationPush) {
                if (!self.transitionDelegate.interactive) {
                    self.gestureRecognizer = gesture;
                    self.originalFrame = imageGallery.imageViewArr[RGIGViewIndexM].frame;
                    self.originalCenter = imageGallery.imageViewArr[RGIGViewIndexM].center;
                }
            }
            break;
        }
        case UIGestureRecognizerStateChanged: {
            if (!self.transitionDelegate.interactive) {
                return;
            }
            if (selfGesture) {
                self.scale = (1 - translatedPoint.y / (self.fromVC.view.frame.size.height / 2.0f));
            }
            
            translatedPoint = CGPointMake(self.originalCenter.x + translatedPoint.x, self.originalCenter.y + translatedPoint.y);
            if (self.operation == UINavigationControllerOperationPop) {
                if ((selfGesture && self.scale <= 1) || (!selfGesture)) {
                    [imageGallery setMiddleImageViewForPopSetScale:self.scale setCenter:YES centerX:translatedPoint.x cencentY:translatedPoint.y];
                }
            }
            
            if (self.operation == UINavigationControllerOperationPush) {
                [imageGallery setMiddleImageViewForPushSetScale:self.scale setCenter:YES orignalFrame:self.originalFrame centerX:translatedPoint.x cencentY:translatedPoint.y];
            }
            
            if (selfGesture) {
                [self updateInteractiveTransition:[self getProgressWithScale:self.scale limit:YES]];
            }
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            if (!self.transitionDelegate.interactive) {
                return;
            }
            if (selfGesture) {
                CGFloat progress = [self getProgressWithScale:self.scale limit:YES];
                BOOL isSucceed = NO;
                if (self.operation == UINavigationControllerOperationPush) {
                    isSucceed = (progress > 0.0f);
                }
                if (self.operation == UINavigationControllerOperationPop) {
                    isSucceed = (progress >= 0.02f);
                }
                [self finishInteractiveTransitionWithSucceed:isSucceed progress:progress];
            }
            break;
        }
        default: {
            NSLog(@"%ld", (long)gesture.state);
        }
    }
}

- (CGFloat)getProgressWithScale:(CGFloat)scale limit:(BOOL)limit{
    CGFloat progress = scale;
    if (self.operation == UINavigationControllerOperationPush) {
        progress = (progress - 1) / (self.maxScale - 1);
    } else if (self.operation == UINavigationControllerOperationPop) {
        progress = 1.0f - scale;
    } else {
        progress = 0;
    }
    if (limit) {
        if (progress < 0) {
            progress = 0;
        }
        if (progress > 1) {
            progress = 1;
        }
    }
    return progress/2;
}

- (void)finishInteractiveTransitionWithSucceed:(BOOL)succeed progress:(CGFloat)progress {
    
    if (!self.transitionDelegate.interactive) {
        return;
    }

    self.transitionDelegate.operateSucceed = succeed;
    self.transitionDelegate.interactive = NO;
    
    RGImageGallery *imageGallery = nil;
    if ([self.fromVC isKindOfClass:[RGImageGallery class]]) {
        imageGallery = (RGImageGallery *)self.fromVC;
    }
    if ([self.toVC isKindOfClass:[RGImageGallery class]]) {
        imageGallery = (RGImageGallery *)self.toVC;
    }
    
    if (succeed) {
        [self finishInteractiveTransition];
    } else {
        [self cancelInteractiveTransition];
    }
    
    if (succeed) {
        progress = 1 - progress;
    }
    self.transitionDelegate.leftProgress = progress;
    if (self.operation == UINavigationControllerOperationPush) {
        if (!succeed && progress <= 0) {
            progress = -[self getProgressWithScale:self.scale limit:NO];
            self.transitionDelegate.leftProgress = progress;
        }
        [UIView animateKeyframesWithDuration:progress * interationTtransitionDuration delay:0 options:UIViewAnimationOptionCurveEaseOut|UIViewAnimationOptionTransitionNone animations:^{
            if (succeed) {
                [imageGallery setMiddleImageViewWhenPushFinished];
            } else {
                [imageGallery setMiddleImageViewWhenPopFinished];
            }
        } completion:nil];
    }
    
    if (self.operation == UINavigationControllerOperationPop) {
        if (progress == 0) {
            progress = [self getProgressWithScale:self.scale limit:NO];
        }
        [UIView animateKeyframesWithDuration:progress * interationTtransitionDuration delay:0 options:UIViewAnimationOptionCurveEaseOut|UIViewAnimationOptionTransitionNone animations:^{
            if (succeed) {
                [imageGallery setMiddleImageViewWhenPopFinished];
            } else {
                [imageGallery setMiddleImageViewWhenPushFinished];
            }
        } completion:nil];
    }
}

#pragma mark - Gesture Delegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if (gestureRecognizer == self.pinchGestureRecognizer && otherGestureRecognizer == self.panGestureRecognizer) {
        return YES;
    }
    if (gestureRecognizer == self.panGestureRecognizer && otherGestureRecognizer == self.pinchGestureRecognizer) {
        return YES;
    }
    return NO;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer == self.panGestureRecognizer && [gestureRecognizer.view isKindOfClass:[UICollectionViewCell class]]
         && !self.transitionDelegate.interactive) {
        return NO;
    }
    return YES;
}

@end

@implementation IGPushAndPopAnimationController

- (instancetype)initWithNavigationControllerOperation:(UINavigationControllerOperation)operation {
    self = [super init];
    if (self) {
        self.operation = operation;
    }
    return self;
}

#pragma mark - UIViewControllerAnimatedTransitioning

- (NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)transitionContext {
    if (self.transitionDelegate.interactive) {
        return interationTtransitionDuration;
    }
    if (self.operation == UINavigationControllerOperationPop) {
        return animatePopTtransitionDuration;
    }
    return 0.4;
}

- (void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext {
    switch (_operation) {
        case UINavigationControllerOperationPush:{
            UIView *containerView       = [transitionContext containerView];
            RGImageGallery *toVC          = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
            UIView *toView              = SYSTEM_LESS_THAN(@"8")?toVC.view:[transitionContext viewForKey:UITransitionContextToViewKey];
            UIViewController *fromVC    = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
            NSTimeInterval duration     = [self transitionDuration:transitionContext];
            
            [containerView addSubview:toView];
            
            RGIMGalleryTransitionCompletion com = nil;
            if ([toVC.delegate respondsToSelector:@selector(imageGallery:willBePushedWithParentViewController:)]) {
                com = [toVC.delegate imageGallery:toVC willBePushedWithParentViewController:fromVC];
            }
            
            void(^completion)(BOOL finished) = ^(BOOL finished) {
                BOOL operateSucceed = self.transitionDelegate.operateSucceed;
                
                if (com) {
                    com(operateSucceed);
                }
                
                CGFloat leftTime = self.transitionDelegate.leftProgress * duration;
                
                if (!operateSucceed) {
                    [toVC __setNavigationBarAndTabBarForImageGallery:NO];
                }
                
                void (^operateBlock)(BOOL operateSucceed) = ^(BOOL operateSucceed) {
                    [transitionContext completeTransition:operateSucceed];
                    if (!operateSucceed) {
                        fromVC.navigationController.delegate = nil;
                    }
                };
                
                if (SYSTEM_LESS_THAN(@"8") || operateSucceed || leftTime == 0) { // iOS 7 will crash if delay completeTransition:
                    operateBlock(operateSucceed);
                } else {
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(leftTime * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        operateBlock(operateSucceed);
                    });
                }
            };
            
            [toVC.view setBackgroundColor:[UIColor colorWithWhite:1 alpha:0]];
            if (!self.transitionDelegate.interactive) {
                [UIView animateWithDuration:duration*0.6 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
                    [toVC setMiddleImageViewWhenPushAnimate];
                    [self addAnimationForBackgroundColorInPushToVC:toVC];
                } completion:^(BOOL finished) {
                    
                }];
                [UIView animateWithDuration:duration*0.4 delay:duration*0.6 options:UIViewAnimationOptionCurveEaseInOut animations:^{
                    [toVC setMiddleImageViewWhenPushFinished];
                } completion:completion];
                [UIView animateWithDuration:duration animations:^{
                    [self addAnimationForBarFrom:toVC isPush:YES];
                } completion:nil];
            } else {
                [UIView animateKeyframesWithDuration:duration delay:0.0 options:UIViewKeyframeAnimationOptionCalculationModeCubic animations:^{
                    [self addKeyFrameAnimationOnCellPushToVC:toVC];
                    [UIView addKeyframeWithRelativeStartTime:0 relativeDuration:1 animations:^{
                        [self addAnimationForBarFrom:toVC isPush:YES ];
                        [self addAnimationForBackgroundColorInPushToVC:toVC];
                    }];
                } completion:completion];
            }
            break;
        }
        case UINavigationControllerOperationPop:{
            UIView *containerView       = [transitionContext containerView];
            RGImageGallery *fromVC        = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
            UIViewController *toVC      = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
            
            UIView *fromView            = SYSTEM_LESS_THAN(@"8")?fromVC.view:[transitionContext viewForKey:UITransitionContextFromViewKey];
            UIView *toView              = SYSTEM_LESS_THAN(@"8")?toVC.view:[transitionContext viewForKey:UITransitionContextToViewKey];
            NSTimeInterval duration     = [self transitionDuration:transitionContext];
            
            [containerView insertSubview:toView belowSubview:fromView];
            [fromView bringSubviewToFront:toView];
            
            RGIMGalleryTransitionCompletion com = nil;
            if ([fromVC.delegate respondsToSelector:@selector(imageGallery:willPopToParentViewController:)]) {
                com = [fromVC.delegate imageGallery:fromVC willPopToParentViewController:toVC];
            }
            
//            [UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
            [UIView animateKeyframesWithDuration:duration delay:0.0 options:UIViewKeyframeAnimationOptionCalculationModeLinear animations:^{
                
                if (toVC.navigationController.navigationBarHidden) {
                    [fromVC hide:NO topbarWithAnimateDuration:0 backgroundChange:NO];
                }
                
                if (!self.transitionDelegate.interactive) {
                    [self addKeyFrameAnimationOnCellPopFromVC:fromVC];
                }
                [UIView addKeyframeWithRelativeStartTime:0 relativeDuration:1 animations:^{
                    [self addAnimationForBarFrom:fromVC isPush:NO];
                    [self addAnimationForBackgroundColorInPopWithFakeBackground:fromView];
                }];
            } completion:^(BOOL finished) {
                [fromVC __setNavigationBarAndTabBarForImageGallery:!self.transitionDelegate.operateSucceed];
                if (self.transitionDelegate.operateSucceed) {
                    toVC.navigationController.delegate = nil;
                    fromVC.navigationController.delegate = nil;
                    [transitionContext completeTransition:YES];
                    [fromVC showParentViewControllerNavigationBar:YES];
                    if (com) {
                        com(YES);
                    }
                } else {
                    [transitionContext completeTransition:NO];
                    if (com) {
                        com(NO);
                    }
                }
            }];
            break;
        }
        default:{}
        break;
    }
}

- (void)addKeyFrameAnimationOnCellPushToVC:(RGImageGallery *)toVC {
    [UIView addKeyframeWithRelativeStartTime:0 relativeDuration:0.7 animations:^{
        [toVC setMiddleImageViewWhenPushAnimate];
    }];
    [UIView addKeyframeWithRelativeStartTime:0.7 relativeDuration:0.3 animations:^{
        [toVC setMiddleImageViewWhenPushFinished];
    }];
}

- (void)addKeyFrameAnimationOnCellPopFromVC:(RGImageGallery *)fromVC {
    [UIView addKeyframeWithRelativeStartTime:0 relativeDuration:1 animations:^{
        [fromVC setMiddleImageViewWhenPopFinished];
    }];
}

- (void)addAnimationForBackgroundColorInPushToVC:(RGImageGallery *)toVC {
    [toVC.view setBackgroundColor:[UIColor colorWithWhite:1 alpha:1]];
}

- (void)addAnimationForBackgroundColorInPopWithFakeBackground:(UIView *)toView {
    [toView setBackgroundColor:[UIColor colorWithWhite:1 alpha:0]];
}

- (void)addAnimationForBarFrom:(RGImageGallery *)imageGallery isPush:(BOOL)isPush {
    if (isPush) {
        [imageGallery hide:NO toolbarWithAnimateDuration:0];
    } else {
        [imageGallery hide:YES toolbarWithAnimateDuration:0];
    }
}

@end

