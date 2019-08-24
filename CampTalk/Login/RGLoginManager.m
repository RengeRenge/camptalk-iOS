//
//  RGLoginManager.m
//  CampTalk
//
//  Created by renge on 2019/8/24.
//  Copyright © 2019 yuru. All rights reserved.
//

#import "RGLoginManager.h"
#import "CTFileManger.h"

@implementation RGLoginManager

+ (RGLoginManager *)shared {
    static RGLoginManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[RGLoginManager alloc] init];
        manager.username = @"Renge";
        [CTFileManger cacheManager].user = manager.username;
        [CTFileManger documentManager].user = manager.username;
    });
    return manager;
}

- (BOOL)isLogin {
    return YES;
}

@end
