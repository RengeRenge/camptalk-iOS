//
//  RGMessageViewModel.m
//  CampTalk
//
//  Created by renge on 2019/8/24.
//  Copyright © 2019 yuru. All rights reserved.
//

#import "RGMessageViewModel.h"
#import <RGUIKit/RGUIKit.h>
#import "UIImageView+RGGif.h"
#import "CTFileManger.h"
#import "CTUserConfig.h"

static NSPointerArray *array;

@implementation RGMessageViewModel

+ (NSPointerArray *)cellCache {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        array = [[NSPointerArray alloc] initWithOptions:NSPointerFunctionsWeakMemory];
    });
    return array;
}

+ (void)configCell:(UITableViewCell *)aCell withMessage:(RGMessage *)message {
    if (![aCell isKindOfClass:CTChatTableViewCell.class]) {
        return;
    }
    CTChatTableViewCell *cell = (CTChatTableViewCell *)aCell;
    
    NSString *loadId = message.msgId;
    if ([cell.cellId isEqualToString:loadId]) {
        return;
    }
    
    cell.cellId = loadId;
    
    if ([message.userId isEqualToString:@"lin"]) {
        cell.myDirection = NO;
        cell.iconImage = [UIImage imageNamed:@"zhimalin"];
    } else {
        cell.myDirection = YES;
        cell.iconImage = [UIImage rg_imageWithName:@"fuzi_hd"];
    }
    
    if (message.thumbUrl) {
        cell.chatBubbleLabel.label.text = nil;
        cell.displayThumb = YES;
        cell.thumbPixSize = message.g_thumbSize;
        NSURL *url = [NSURL URLWithString:message.thumbUrl];
        if ([url.scheme hasPrefix:@"http://"]) {
            // TODO: load from server
        } else {
            NSString *path = [CTFileManger.cacheManager pathWithFileName:message.thumbUrl folderName:UCChatDataFolderName];
            [cell.thumbView rg_setImagePath:path
                                      async:YES
                                   delayGif:0.5
                                 completion:nil];
        }
    } else if (message.message.length) {
        cell.displayThumb = NO;
        cell.thumbView.image = nil;
        cell.chatBubbleLabel.label.text = message.message;
    }
    [cell setNeedsLayout];
}

@end
