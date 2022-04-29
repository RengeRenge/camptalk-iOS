//
//  CTSocket.h
//  CampTalk
//
//  Created by renge on 2018/5/29.
//  Copyright © 2018年 yuru. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const kNeedPayOrderNote;
extern NSString * const kWebSocketDidOpenNote;
extern NSString * const kWebSocketDidCloseNote;
extern NSString * const kWebSocketdidReceiveMessageNote;

@interface CTSocket : NSObject

+ (CTSocket *)sharedInstance;

- (void)openWithToken:(NSString *)token;
- (void)close;
- (void)sendMessage:(NSData *)data;

@end
