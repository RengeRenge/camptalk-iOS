//
//  CTChatModel.m
//  CampTalk
//
//  Created by LD on 2018/4/20.
//  Copyright © 2018年 yuru. All rights reserved.
//

#import "RGMessage.h"
#import "RGRealmManager.h"

@implementation RGMessage

+ (NSString *)primaryKey {
    return @"msgId";
}

+ (NSDictionary *)defaultPropertyValues {
    return @{
             @"msgId": [[NSUUID UUID] UUIDString],
             @"unread": @YES,
             };
}

+ (RLMResults<RGMessage *> *)messageWithRoomId:(NSString *)roomId username:(NSString *)username {
    RLMRealm *reaml = [RGRealmManager messageRealm];
    return [[RGMessage objectsInRealm:reaml withPredicate:[NSPredicate predicateWithFormat:@"roomId=%@", roomId]] sortedResultsUsingKeyPath:@"sendTime" ascending:YES];
}

+ (RLMResults<RGMessage *> *)unreadMessageWithRoomId:(NSString *)roomId username:(NSString *)username {
    RLMRealm *reaml = [RGRealmManager messageRealm];
    return [RGMessage objectsInRealm:reaml withPredicate:[NSPredicate predicateWithFormat:@"roomId=%@ && unread=%@", roomId, @YES]];
}

+ (NSMutableArray<RGMessage *> *)fakeList {
    NSMutableArray *data = [NSMutableArray array];
    int i = 10;
    NSMutableString *string = [[NSMutableString alloc] init];
    while (i--) {
        [string appendString:@"啊"];
        RGMessage *model = [RGMessage new];
        [data addObject:model];
        
        if (i > 0 && i <= 3) {
            NSString *size = [NSString stringWithFormat:@"@{%f,%f}", powf(15, i), powf(15, i)];
            model.thumbSize = size;
            NSString *filePath = [[NSBundle mainBundle] pathForResource:@"chatBg_1" ofType:@"jpg"];
            model.thumbUrl = [NSURL fileURLWithPath:filePath].absoluteString;
        } else {
            model.message = string;
        }
        model.userId = @"lin";
    }
    data = [NSMutableArray arrayWithArray:[[data reverseObjectEnumerator] allObjects]];
    
    RGMessage *model = [RGMessage new];
    model.message = @"请、请让我分15期付款";
    
    [data insertObject:model atIndex:data.count - 3];
    return data;
}

@end

@implementation RGMessage (GET)

- (CGSize)g_thumbSize {
    return CGSizeFromString(self.thumbSize);
}

- (CGSize)g_originalImageSize {
    return CGSizeFromString(self.originalImageSize);
}

@end
