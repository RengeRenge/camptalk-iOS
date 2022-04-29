//
//  RGSocketIOManager.h
//  CampTalk
//
//  Created by renge on 2019/10/19.
//  Copyright © 2019 yuru. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/*
 code:
    200    OK
    401    unauthorized
    404    not found
    408    Request Timeout
    500    internal sever error
    ……
 */
typedef void(^RGSocketIOResponse)(int code, id _Nullable response);

@protocol RGSocketIOManagerDelegate;

@interface RGSocketIOManager : NSObject

@property (atomic, strong, readonly, nullable) NSString *token;

+ (RGSocketIOManager *)shared;

- (void)addDelegate:(id<RGSocketIOManagerDelegate>)delegate;
- (void)removeDelegate:(id<RGSocketIOManagerDelegate>)delegate;

- (void)startWithToken:(NSString *_Nullable)token;

- (void)requestUrl:(NSString *)url data:(NSDictionary *_Nullable)data response:(RGSocketIOResponse)response;

- (void)test;

@end


@protocol RGSocketIOManagerDelegate <NSObject>

- (void)socketIOManager:(RGSocketIOManager*)manager on:(NSString *)event json:(id)json;

@end

NS_ASSUME_NONNULL_END
