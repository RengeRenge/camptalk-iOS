//
//  XJWebViewController.m
//  liangbo-ios
//
//  Created by renge on 2018/8/27.
//  Copyright © 2018年 tong zhang. All rights reserved.
//

#define AppJumpJinDongFormat @"openapp.jdmobile://virtual?params=%%7B%%22sourceValue%%22:%%220_productDetail_97%%22,%%22des%%22:%%22productDetail%%22,%%22skuId%%22:%%22%@%%22,%%22category%%22:%%22jump%%22,%%22sourceType%%22:%%22PCUBE_CHANNEL%%22%%7D"

#define AppJumpTaoBaoFormat @"taobao://item.taobao.com/item.htm?id=%@"
#define AppJumpTmallFormat @"tmall://tmallclient/?{\"action\":\"item:id=%@\"}"

#define JSFuntionUserId @"app"
#define JSFuntionGoBack @"goback"

#import "XJWebViewController.h"
#import "XJMenuTableViewController.h"
#import <WebKit/WebKit.h>
#import <RGUIKit/RGUIKit.h>

#import "XJWeakScriptMessageDelegate.h"

typedef enum : NSUInteger {
    XJWebMenuIdRefresh,
    XJWebMenuIdSafari,
    XJWebMenuIdShare,
} XJWebMenuId;

@interface XJWebViewController () <WKNavigationDelegate, XJMenuDelegate, RGUINavigationControllerShouldPopDelegate, UIPopoverPresentationControllerDelegate, WKScriptMessageHandler, WKUIDelegate>

@property (nonatomic,strong) WKWebView *webView;

@property (nonatomic,strong) UIProgressView *progress;
@property (nonatomic, assign) BOOL progressObserver;

@property (nonatomic,strong) UIButton *reloadBtn;  //重新加载按钮

@end

@implementation XJWebViewController

+ (void)showPopoverFrom:(UIView *)sender withUrl:(NSString *)url {
    
    XJWebViewController *vc = [[XJWebViewController alloc] init];
    vc.urlString = url;
    vc.loadingProgressColor = [UIColor blackColor];
    
    RGNavigationController *oneCtr = [RGNavigationController navigationWithRoot:vc];
    oneCtr.tintColor = [UIColor blackColor];
    oneCtr.modalPresentationStyle = UIModalPresentationPopover;
    oneCtr.popoverPresentationController.delegate = vc;
    oneCtr.popoverPresentationController.sourceView = sender;
    oneCtr.popoverPresentationController.sourceRect = sender.bounds;
    oneCtr.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionUp|UIPopoverArrowDirectionDown;
    [[self rg_topViewControllerByWindow:sender.window] presentViewController:oneCtr animated:YES completion:^{
        
    }];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    if (self.customRightItem) {
        self.navigationItem.rightBarButtonItem = self.customRightItem;
    } else {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"webVC-more"] style:UIBarButtonItemStylePlain target:self action:@selector(more:)];
    }
    
    self.webView.frame = self.view.bounds;
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    
    [self.view addSubview:self.webView];
    [self.view addSubview:self.progress];
    [self.view addSubview:self.reloadBtn];
    
    self.view.backgroundColor = [UIColor whiteColor];
    [self loadRequest];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.hideNavigationBarWhenAppear) {
        [self.navigationController setNavigationBarHidden:YES animated:YES];
        [UIView animateWithDuration:0
                         animations:^{
                         }
                         completion:^(BOOL finished) {
                             if (self.navigationController.navigationBarHidden) {
                                 [self.navigationController setNavigationBarHidden:YES animated:NO];
                             }
                         }];
        self.navigationController.interactivePopGestureRecognizer.delegate = (id)self;
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (self.hideNavigationBarWhenAppear) {
        [self.navigationController setNavigationBarHidden:NO animated:YES];
        [UIView animateWithDuration:0
                         animations:^{
                         }
                         completion:^(BOOL finished) {
                             if (self.navigationController.navigationBarHidden) {
                                 [self.navigationController setNavigationBarHidden:NO animated:NO];
                             }
                         }];
        self.navigationController.interactivePopGestureRecognizer.delegate = nil;
    }
}

- (void)dealloc {
    [[_webView configuration].userContentController removeScriptMessageHandlerForName:JSFuntionUserId];
    [[_webView configuration].userContentController removeScriptMessageHandlerForName:JSFuntionGoBack];
}

- (void)more:(id)sender {
    XJMenuTableViewController *vc = [[XJMenuTableViewController alloc] initWithStyle:UITableViewStylePlain];
    vc.delegate = self;
    vc.items = @[
                 @(XJWebMenuIdRefresh),
                 @(XJWebMenuIdSafari),
                 ];
    vc.preferredContentSize = CGSizeMake(170, vc.items.count * 40);
    
    [vc presentFromViewController:self sourceView:sender];
}

- (void)loadRequest {
    NSURLRequest *request = nil;
    if (_url) {
        request = [[NSURLRequest alloc] initWithURL:_url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
    } else {
        NSString *urlEncode = [_urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:urlEncode] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
    }
    if (request) {
        [_webView loadRequest:request];
    }
}

- (void)reload {
    [_webView reload];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    CGRect bounds = self.view.bounds;
    _progress.frame = CGRectMake(0, self.rg_layoutOriginY, bounds.size.width, 2);
    self.webView.frame = UIEdgeInsetsInsetRect(self.view.bounds, UIEdgeInsetsMake(self.rg_layoutOriginY, 0, 0, 0));
    _reloadBtn.center = CGPointMake(bounds.size.width / 2.f, bounds.size.height / 2.f);
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.progressObserver = YES;
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    self.progressObserver = NO;
}

- (UIProgressView *)progress {
    if (!_progress) {
        _progress = [[UIProgressView alloc] init];
        _progress.trackTintColor = [UIColor clearColor];
        _progress.progressTintColor = _loadingProgressColor ? _loadingProgressColor : self.view.tintColor;
    }
    return _progress;
}

- (UIButton *)reloadBtn{
    if (!_reloadBtn) {
        self.reloadBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        _reloadBtn.frame = CGRectMake(0, 0, 200, 140);
        [_reloadBtn setBackgroundImage:[UIImage imageNamed:@"loadingError"] forState:UIControlStateNormal];
        [_reloadBtn setTitle:@"网络异常，点击重新加载" forState:UIControlStateNormal];
        [_reloadBtn addTarget:self action:@selector(reload) forControlEvents:(UIControlEventTouchUpInside)];
        [_reloadBtn setTitleColor:[UIColor lightGrayColor] forState:UIControlStateNormal];
        _reloadBtn.titleLabel.font = [UIFont systemFontOfSize:15];
        [_reloadBtn setTitleEdgeInsets:UIEdgeInsetsMake(200, -50, 0, -50)];
        _reloadBtn.titleLabel.numberOfLines = 0;
        _reloadBtn.titleLabel.textAlignment = NSTextAlignmentCenter;
        _reloadBtn.hidden = YES;
    }
    return _reloadBtn;
}

- (WKWebView *)webView {
    if (!_webView) {
        
        WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
        configuration.preferences = [[WKPreferences alloc] init];
        configuration.allowsInlineMediaPlayback = YES;
        configuration.selectionGranularity = YES;
        
        XJWeakScriptMessageDelegate *delegate = [[XJWeakScriptMessageDelegate alloc] initWithDelegate:self];
        [configuration.userContentController addScriptMessageHandler:delegate name:JSFuntionUserId];
        [configuration.userContentController addScriptMessageHandler:delegate name:JSFuntionGoBack];
        
        _webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:configuration];
        
        _webView.UIDelegate = self;
        _webView.navigationDelegate = self;
        
        _webView.allowsBackForwardNavigationGestures = YES;
        self.progressObserver = YES;
    }
    return _webView;
}

- (void)setProgressObserver:(BOOL)progressObserver {
    if (_progressObserver == progressObserver) {
        return;
    }
    _progressObserver = progressObserver;
    if (_progressObserver) {
        [_webView addObserver:self forKeyPath:@"estimatedProgress" options:(NSKeyValueObservingOptionNew) context:nil];
    } else {
        [_webView removeObserver:self forKeyPath:@"estimatedProgress"];
    }
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    _progress.hidden = NO;
    _webView.hidden = NO;
    _reloadBtn.hidden = YES;
    
    NSURL *requestURL = webView.URL;
    
    // 看是否加载空网页
    if ([requestURL.scheme isEqual:@"about"]) {
        webView.hidden = YES;
    } else if ([self.linkUrls containsObject:requestURL.absoluteString]) {
        requestURL = [self handleAppJump:requestURL];
        [[UIApplication sharedApplication] openURL:requestURL];
    }
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    //执行JS方法获取导航栏标题
    if (self.autoTitle) {
        [webView evaluateJavaScript:@"document.title" completionHandler:^(id _Nullable title, NSError * _Nullable error) {
            self.navigationItem.title = title;
        }];
    }
}

// 在收到响应后，决定是否跳转
- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler {
    decisionHandler(WKNavigationResponsePolicyAllow);
}

// 在请求发送之前，决定是否跳转
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    BOOL allow = YES;
    if ([self.urlDelegate respondsToSelector:@selector(webViewController:decidePolicyForAction:)]) {
        allow = [self.urlDelegate webViewController:self decidePolicyForAction:navigationAction.request.URL];
    }
//    if (navigationAction.targetFrame == nil) {
//        [webView loadRequest:navigationAction.request];
//    }
    decisionHandler(allow ? WKNavigationActionPolicyAllow : WKNavigationActionPolicyCancel);
}

//页面加载失败
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error {
    webView.hidden = YES;
    _reloadBtn.hidden = NO;
}

#pragma mark - WKUIDelegate

- (WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures {
    if (!navigationAction.targetFrame.isMainFrame) {
        [webView loadRequest:navigationAction.request];
    }
    return nil;
}

#pragma mark - WKScriptMessageHandler

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    NSString *jsSignalName = message.name;
    if ([jsSignalName isEqualToString:JSFuntionUserId]) {
        
    } else if ([jsSignalName isEqualToString:JSFuntionGoBack]) {
        if (self.navigationController) {
            [self.navigationController popViewControllerAnimated:YES];
        } else if (self.presentingViewController) {
            [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
        }
    }
}

#pragma mark - UINavigationControllerShouldPopDelegate

- (BOOL)rg_navigationControllerShouldPop:(UINavigationController *)navigationController isInteractive:(BOOL)isInteractive {
    if (isInteractive) {
        return !self.webView.canGoBack;
    }
    if (self.webView.canGoBack) {
        [self.webView goBack];
        return NO;
    }
    return YES;
}

- (void)rg_navigationController:(UINavigationController *)navigationController interactivePopResult:(BOOL)finished {
    
}

#pragma mark - XJMenuDelegate

- (UIImage *)menuViewController:(XJMenuTableViewController *)viewController menuImageWithMenuId:(NSInteger)menuId {
    switch (menuId) {
        case XJWebMenuIdRefresh:
            return [UIImage imageNamed:@"webVC-refresh"];
        case XJWebMenuIdSafari:
            return [UIImage imageNamed:@"webVC-safari"];
        default:
            return nil;
    }
}

- (NSAttributedString *)menuViewController:(XJMenuTableViewController *)viewController menuTitleWithMenuId:(NSInteger)menuId {
    switch (menuId) {
        case XJWebMenuIdRefresh:
            return [[NSAttributedString alloc] initWithString:@"刷新"];
        case XJWebMenuIdSafari:
            return [[NSAttributedString alloc] initWithString:@"浏览器打开"];
        default:
            return nil;
    }
}

- (void)menuViewController:(XJMenuTableViewController *)viewController didSelecteMenuId:(NSInteger)menuId {
    [self dismissViewControllerAnimated:YES completion:^{
        switch (menuId) {
            case XJWebMenuIdSafari: {
                NSURL *requestURL = self.webView.URL;
                [[UIApplication sharedApplication] openURL:requestURL];
                break;
            }
            case XJWebMenuIdRefresh: {
                [self reload];
                break;
            }
            default:
                break;
        }
    }];
}

- (CGSize)menuViewController:(XJMenuTableViewController *)viewController menuImageSizeWithMenuId:(NSInteger)menuId {
    return CGSizeMake(20, 20);
}

#pragma mark - KVO
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context{
    if ([keyPath isEqualToString:@"estimatedProgress"]) {
        self.progress.progress = [(NSString *)change[@"new"] floatValue];
        if (self.progress.progress == 1.0) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                self.progress.hidden = YES;
            });
        }
    }
}

- (NSURL *)handleAppJump:(NSURL *)url {
    if ([url.host containsString:@"jd.com"]) {
        __block NSString *productId = nil;
        [url.pathComponents enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([obj containsString:@".html"]) {
                NSRange range = [obj rangeOfString:@".html"];
                if (range.length) {
                    productId = [obj substringToIndex:range.location];
                    *stop = YES;
                }
            }
        }];
        
        if (productId.length) {
            NSString *appUrl = [NSString stringWithFormat:AppJumpJinDongFormat, productId];
            NSURL *jumpUrl = [NSURL URLWithString:appUrl];
            if ([[UIApplication sharedApplication] canOpenURL:jumpUrl]) {
                return jumpUrl;
            }
        }
    }
    
    if ([url.host containsString:@"detail.tmall.com"]) {
        NSString *urlString = url.absoluteString;
        NSRange range = [urlString rangeOfString:@"?id="];
        
        if (range.location == NSNotFound) {
            range = [urlString rangeOfString:@"&id="];
        }
        
        if (range.location != NSNotFound) {
            NSInteger length = 0;
            for (NSInteger i = range.location + range.length; i < urlString.length; i++) {
                if ([urlString characterAtIndex:i] == '&') {
                    break;
                }
                length++;
            }
            
            NSString *productID = [urlString substringWithRange:NSMakeRange(range.location + range.length, length)];
            
            NSString *appUrl = [NSString stringWithFormat:AppJumpTaoBaoFormat, productID];
            NSURL *jumpUrl = [NSURL URLWithString:[appUrl stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
            if ([[UIApplication sharedApplication] canOpenURL:jumpUrl]) {
                return jumpUrl;
            }
            
            appUrl = [NSString stringWithFormat:AppJumpTmallFormat, productID];
            jumpUrl = [NSURL URLWithString:[appUrl stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
            if ([[UIApplication sharedApplication] canOpenURL:jumpUrl]) {
                return jumpUrl;
            }
        }
    }
    
    if ([url.host containsString:@"item.taobao.com"]) {
        NSString *urlString = url.absoluteString;
        NSRange range = [urlString rangeOfString:@"?id="];
        
        if (range.location == NSNotFound) {
            range = [urlString rangeOfString:@"&id="];
        }
        
        if (range.location != NSNotFound) {
            NSInteger length = 0;
            for (NSInteger i = range.location + range.length; i < urlString.length; i++) {
                if ([urlString characterAtIndex:i] == '&') {
                    break;
                }
                length++;
            }
            
            NSString *productID = [urlString substringWithRange:NSMakeRange(range.location + range.length, length)];
            
            NSString *appUrl = [NSString stringWithFormat:AppJumpTaoBaoFormat, productID];
            NSURL *jumpUrl = [NSURL URLWithString:[appUrl stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
            if ([[UIApplication sharedApplication] canOpenURL:jumpUrl]) {
                return jumpUrl;
            }
        }
    }
    
    return url;
}

#pragma mark - <UIPopoverPresentationControllerDelegate>

- (UIModalPresentationStyle)adaptivePresentationStyleForPresentationController:(UIPresentationController *)controller {
    return UIModalPresentationNone;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

@end
