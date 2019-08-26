//
//  XJWebViewController.h
//  liangbo-ios
//
//  Created by renge on 2018/8/27.
//  Copyright © 2018年 tong zhang. All rights reserved.
//

@protocol XJWebViewControllerDelegate;

#import <UIKit/UIKit.h>

@interface XJWebViewController : UIViewController

@property (nonatomic, copy) NSString *urlString;
@property (nonatomic, copy) NSURL *url;

@property (nonatomic, strong) NSArray <NSString *> *linkUrls; // 检测到次链接后自动用Safari打开

@property (nonatomic, strong) UIBarButtonItem *customRightItem;

@property (nonatomic, copy) NSString *shareTitle;
@property (nonatomic, strong) UIImage *shareImage;

@property (nonatomic, strong) UIColor *loadingProgressColor;

@property (nonatomic, assign) id <XJWebViewControllerDelegate> urlDelegate;

@property (nonatomic, assign) BOOL autoTitle;
@property (nonatomic, assign) BOOL hideNavigationBarWhenAppear;

+ (void)showPopoverFrom:(UIView *)sender withUrl:(NSString *)url;

@end

@protocol XJWebViewControllerDelegate <NSObject>
    
- (BOOL)webViewController:(XJWebViewController *)webViewController decidePolicyForAction:(NSURL *)url;

@end
