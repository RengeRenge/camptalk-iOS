//
//  RGRealmManager.m
//  CampTalk
//
//  Created by renge on 2019/8/23.
//  Copyright © 2019 yuru. All rights reserved.
//

#import "RGRealmManager.h"
#import <Realm/RLMRealmConfiguration.h>
#import "CTFileManger.h"

#define OPEN_LOG
#ifdef  OPEN_LOG
//__LINE__ 代表行数,  __PRETTY_FUNCTION__ 代表当前的函数名
#define DLOG(fmt, ...)      NSLog((@"[Line %d] %s\n" fmt), __LINE__, __PRETTY_FUNCTION__, ##__VA_ARGS__);
#else
#define DLOG(fmt, ...)
#endif

#define kMessageRealmV 0

@implementation RGRealmManager

+ (RLMRealmConfiguration *)messageConfiguration {
    NSString *path = [[CTFileManger documentManager] userBasePath];
    path = [path stringByAppendingPathComponent:@"ct_message.realm"];
    
    RLMRealmConfiguration *newsConfiguration = [[RLMRealmConfiguration alloc] init];
    newsConfiguration.fileURL = [NSURL fileURLWithPath:path];
    newsConfiguration.schemaVersion = kMessageRealmV;
    newsConfiguration.deleteRealmIfMigrationNeeded = NO;
    newsConfiguration.migrationBlock = ^(RLMMigration *migration, uint64_t oldSchemaVersion) {
        if (oldSchemaVersion < 1) {
        }
        if (oldSchemaVersion < 2) {
        }
        if (oldSchemaVersion < 3) {
        }
    };
    return newsConfiguration;
}

+ (RLMRealm *)messageRealm {
    NSError *error = nil;
    RLMRealmConfiguration *configuration = [self messageConfiguration];
    RLMRealm *realm = nil;
    if (configuration) {
        realm = [RLMRealm realmWithConfiguration:configuration error:&error];
    }
    if (error) {
        DLOG("error=%s", error.description ? error.description.UTF8String : error.localizedFailureReason ? error.localizedFailureReason.UTF8String : "")
        realm = nil;
    }
    [realm refresh];
    return realm;
}

@end
