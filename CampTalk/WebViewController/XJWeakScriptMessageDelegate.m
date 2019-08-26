//
//  XJWeakScriptMessageDelegate.m
//  liangbo-ios
//
//  Created by renge on 2018/9/7.
//  Copyright © 2018年 tong zhang. All rights reserved.
//

#import "XJWeakScriptMessageDelegate.h"
#import <WebKit/WebKit.h>

@implementation XJWeakScriptMessageDelegate

- (instancetype)initWithDelegate:(id<WKScriptMessageHandler>)scriptDelegate {
    self = [super init];
    if (self) {
        _scriptDelegate = scriptDelegate;
    }
    return self;
}

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    [self.scriptDelegate userContentController:userContentController didReceiveScriptMessage:message];
}

@end
