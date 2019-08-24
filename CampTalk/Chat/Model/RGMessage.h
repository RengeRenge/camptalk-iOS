//
//  CTChatModel.h
//  CampTalk
//
//  Created by LD on 2018/4/20.
//  Copyright © 2018年 yuru. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Realm/Realm.h>

@interface RGMessage : RLMObject

// place
@property NSString *msgId;
@property NSString *roomId;

// text
@property NSString *message;

// url
@property NSString *url;
@property NSString *title;
@property NSString *subTitle;

// image
@property NSString *thumbSize; // "4.5,2" //  pix
@property NSString *thumbUrl; // localPhoto use File://

@property NSString *originalImageSize; // "45,20" pix
@property NSString *originalImageUrl; // localPhoto use File://

// audio
@property NSString *audioUrl;
@property NSTimeInterval audioDuration;

// extra
@property NSString *notifyUsers; // "[Mike,John,Lily,WuYiFan]"
@property NSInteger rollback;
@property BOOL unread;

// userInfo
@property NSString *userId;
@property NSString *userName; // nickname
@property NSString *groupUserName; // nickname
@property NSString *userIconUrl;

// deviceInfo
@property NSInteger sendTime;
@property NSInteger version;

+ (RLMResults<RGMessage *> *)messageWithRoomId:(NSString *)roomId username:(NSString *)username;
+ (RLMResults<RGMessage *> *)unreadMessageWithRoomId:(NSString *)roomId username:(NSString *)username;
+ (NSMutableArray <RGMessage *> *)fakeList;

@end
RLM_ARRAY_TYPE(RGMessage)


@interface RGMessage (GET)

- (CGSize)g_thumbSize;
- (CGSize)g_originalImageSize;

@end
