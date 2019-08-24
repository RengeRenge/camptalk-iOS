//
//  RGRealmManager.h
//  CampTalk
//
//  Created by renge on 2019/8/23.
//  Copyright © 2019 yuru. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <Realm/RLMRealm.h>

NS_ASSUME_NONNULL_BEGIN

@interface RGRealmManager : NSObject

+ (RLMRealm *)messageRealm;

@end

NS_ASSUME_NONNULL_END
