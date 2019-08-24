//
//  RGLoginManager.h
//  CampTalk
//
//  Created by renge on 2019/8/24.
//  Copyright © 2019 yuru. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RGLoginManager : NSObject

@property (nonatomic, copy) NSString *username;

+ (RGLoginManager *)shared;

- (BOOL)isLogin;

@end

NS_ASSUME_NONNULL_END
