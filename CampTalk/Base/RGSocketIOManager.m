//
//  RGSocketIOManager.m
//  CampTalk
//
//  Created by renge on 2019/10/19.
//  Copyright © 2019 yuru. All rights reserved.
//

#import "RGSocketIOManager.h"
#import <SocketIO/SocketIO-Swift.h>
#import <RGUIKit/RGUIKit.h>

//CampTalk Protocol
static NSString *SocketIOEmitEvent = @"cp";
//CampTalk Protocol Response
static NSString *SocketIOEmitResponseEvent = @"cpr";
//CampTalk Protocol ClinentId
static NSString *SocketIOClientId = @"CampTalk";

@interface RGSocketIOManager ()

@property (nonatomic, strong) SocketManager *socketManager;

@property (nonatomic, strong) NSPointerArray *delegates;
@property (nonatomic, strong) NSMutableDictionary <NSString *, RGSocketIOResponse> *responseMap;

@end

@implementation RGSocketIOManager

+ (RGSocketIOManager *)shared {
    static RGSocketIOManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[RGSocketIOManager alloc] init];
    });
    return manager;
}

- (instancetype)init {
    if (self = [super init]) {
        [self responseMap];
        _delegates = [NSPointerArray weakObjectsPointerArray];
    }
    return self;
}

- (NSMutableDictionary *)responseMap {
    if (!_responseMap) {
        _responseMap = [NSMutableDictionary dictionary];
    }
    return _responseMap;
}

- (void)addDelegate:(id<RGSocketIOManagerDelegate>)delegate {
    if (delegate) {
        void(^mainBlock)(void) = ^{
            if (![[self.delegates allObjects] containsObject:delegate]) {
                [self.delegates addPointer:(__bridge void * _Nullable)(delegate)];
            }
        };
        if ([NSThread isMainThread]) {
            mainBlock();
        } else {
            dispatch_sync(dispatch_get_main_queue(), ^{
                mainBlock();
            });
        }
    }
}

- (void)removeDelegate:(id<RGSocketIOManagerDelegate>)delegate {
    void(^mainBlock)(void) = ^{
        NSInteger index = [[self.delegates allObjects] indexOfObject:delegate];
        if (index != NSNotFound) {
            [self.delegates removePointerAtIndex:index];
        }
    };
    if ([NSThread isMainThread]) {
        mainBlock();
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            mainBlock();
        });
    }
}

- (void)__enumerateDelegate:(void(NS_NOESCAPE^)(id<RGSocketIOManagerDelegate> delegate))block {
    NSArray <id<RGSocketIOManagerDelegate>> *delegates = [self.delegates allObjects];
    [delegates enumerateObjectsUsingBlock:^(id<RGSocketIOManagerDelegate>  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        block(obj);
    }];
}

- (void)startWithToken:(NSString *)token {
    _token = token;
    [self __start];
}

- (void)requestUrl:(NSString *)url data:(NSDictionary *)data response:(RGSocketIOResponse)response {
    SocketIOClient *socket = self.socketManager.defaultSocket;
    
    NSMutableDictionary *sendData = [NSMutableDictionary dictionary];
    if (data) {
        [sendData setValuesForKeysWithDictionary:data];
    }
    if (self.token.length) {
        sendData[@"token"] = self.token;
    }
    if (url.length) {
        sendData[@"type"] = url;
    }
    NSString *requestId = [NSUUID UUID].UUIDString;
    sendData[@"request_id"] = requestId;
    sendData[@"client_id"] = SocketIOClientId;
    
    self.responseMap[requestId] = response;
    [NSTimer rg_timerWithTimeInterval:15 repeats:NO block:^(NSTimer * _Nonnull timer) {
        RGSocketIOResponse callback = self.responseMap[requestId];
        if (callback) {
            [self.responseMap removeObjectForKey:requestId];
            callback(408, nil);
        }
    }];
    
    [socket emit:SocketIOEmitEvent with:@[sendData] completion:^{
        NSLog(@"completion");
    }];
}

- (void)__start {
    NSURL *url = [[NSURL alloc] initWithString:@"http://renged.xyz:11551"];
    NSDictionary *config = @{
        @"log": @YES,
        @"compress": @YES,
        @"connectParams": @{
                @"auth_key":@123123
        }
    };
    if (self.socketManager) {
        [self.socketManager disconnect];
    }
    self.socketManager = [[SocketManager alloc] initWithSocketURL:url config:config];
    
    SocketIOClient *socket = self.socketManager.defaultSocket;

    [socket on:@"connect_response" callback:^(NSArray* data, SocketAckEmitter* ack) {
        NSLog(@"socket connected --------->\n%@\n<---------------\n", data);
        if (data.firstObject) {
            [self __enumerateDelegate:^(id<RGSocketIOManagerDelegate> delegate) {
                if ([delegate respondsToSelector:@selector(socketIOManager:on:json:)]) {
                    [delegate socketIOManager:self on:@"connect_response" json:data.firstObject];
                }
            }];
        }
    }];

    [socket on:@"message" callback:^(NSArray* data, SocketAckEmitter* ack) {
        NSLog(@"msg callback --------->\n%@\n<---------------", data);
        if (data.firstObject) {
            [self __enumerateDelegate:^(id<RGSocketIOManagerDelegate> delegate) {
                if ([delegate respondsToSelector:@selector(socketIOManager:on:json:)]) {
                    [delegate socketIOManager:self on:@"message" json:data.firstObject];
                }
            }];
        }
        [ack with:@[@"Got your msg, ", @"stranger"]];
    }];
    
    [socket on:SocketIOEmitResponseEvent callback:^(NSArray* data, SocketAckEmitter* ack) {
        NSLog(@"socket cpr --------->\n%@\n<---------------", data);
        NSDictionary *res = data.firstObject;
        if ([res isKindOfClass:NSDictionary.class]) {
            NSString *requestId = res[@"request_id"];
            NSString *client_id = res[@"client_id"];
            if (![client_id isEqualToString:SocketIOClientId]) {
                return;
            }
            RGSocketIOResponse callback = self.responseMap[requestId];
            if (callback) {
                [self.responseMap removeObjectForKey:requestId];
                callback([res[@"code"] intValue], res[@"data"]);
            }
        }
    }];

    [socket connect];
}

- (void)test {
    NSLog(@"test");
    
    SocketIOClient *socket = self.socketManager.defaultSocket;
    
    NSDictionary *sendData = @{
        @"msg": @"不认识不认识"
    };
    
    [socket emit:@"msg" with:@[sendData] completion:^{
        NSLog(@"test completion");
    }];
}

@end
