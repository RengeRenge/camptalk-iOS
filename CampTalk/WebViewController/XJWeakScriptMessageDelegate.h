//
//  XJWeakScriptMessageDelegate.h
//  liangbo-ios
//
//  Created by renge on 2018/9/7.
//  Copyright © 2018年 tong zhang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

@interface XJWeakScriptMessageDelegate : NSObject <WKScriptMessageHandler>

@property (nonatomic, assign) id<WKScriptMessageHandler> scriptDelegate;

- (instancetype)initWithDelegate:(id<WKScriptMessageHandler>)scriptDelegate;

@end
