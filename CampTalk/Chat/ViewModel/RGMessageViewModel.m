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
#import <SDWebImage/SDWebImage.h>
#import "CTFileManger.h"
#import "CTUserConfig.h"

@implementation RGMessageViewModel

+ (void)configCell:(UITableViewCell *)aCell withMessage:(RGMessage *)message {
    if (![aCell isKindOfClass:CTChatTableViewCell.class]) {
        return;
    }
    CTChatTableViewCell *cell = (CTChatTableViewCell *)aCell;
    
    cell.cellId = message.msgId;
    
    if ([message.userId isEqualToString:@"lin"]) {
        cell.myDirection = NO;
        cell.iconImage = [UIImage imageNamed:@"zhimalin"];
    } else {
        cell.myDirection = YES;
        cell.iconImage = [UIImage rg_imageWithName:@"fuzi_hd"];
    }
    
    if (message.thumbUrl) {
        [self loadThumbWithCell:cell withMessage:message];
    } else if (message.message.length) {
        [cell.thumbView sd_cancelCurrentImageLoad];
        [cell.thumbView rg_cancelSetImagePath];
        [self loadTextWithCell:cell withMessage:message];
    }
    [cell setNeedsLayout];
}

+ (void)loadThumbWithCell:(CTChatTableViewCell *)cell withMessage:(RGMessage *)message {
    
    NSString *cellId = cell.cellId;
    
    cell.chatBubbleLabel.label.text = nil;
    cell.displayThumb = YES;
    cell.thumbPixSize = message.g_thumbSize;
    NSURL *url = [NSURL URLWithString:message.thumbUrl];
//    url = [NSURL URLWithString:@"https://timgsa.baidu.com/timg?image&quality=80&size=b9999_10000&sec=11566704414981&di=43b40492bcb99148a9e8dfd280f4a364&imgtype=0&src=http%3A%2F%2Fi1.17173.itc.cn%2F2015%2Fnews%2F2015%2F06%2F09%2Fmsh0609xl03.gif"];
    if ([url.scheme hasPrefix:@"http"]) {
        cell.loadThumbProresss = 1;
        [cell.thumbView
         sd_setImageWithURL:url
         placeholderImage:nil
//         options:SDWebImageFromLoaderOnly
         options:0
         progress:^(NSInteger receivedSize, NSInteger expectedSize, NSURL * _Nullable targetURL) {
             dispatch_async(dispatch_get_main_queue(), ^{
                 if (![cellId isEqual:cell.cellId]) {
                     return;
                 }
                 cell.loadThumbProresss = 1.0*receivedSize/expectedSize;
             });
         } completed:^(UIImage * _Nullable image, NSError * _Nullable error, SDImageCacheType cacheType, NSURL * _Nullable imageURL) {
             if (![cellId isEqual:cell.cellId]) {
                 return;
             }
             cell.loadThumbProresss = 1;
         }];
    } else {
        cell.loadThumbProresss = 1;
        NSString *path = [CTFileManger.cacheManager pathWithFileName:message.thumbUrl folderName:UCChatDataFolderName];
        [cell.thumbView rg_setImagePath:path
                                  async:YES
                               delayGif:1.0
                           continueLoad:nil];
    }
}

+ (void)loadTextWithCell:(CTChatTableViewCell *)cell withMessage:(RGMessage *)message {
    cell.displayThumb = NO;
    cell.thumbView.image = nil;
    cell.loadThumbProresss = 1;
    cell.chatBubbleLabel.label.text = message.message;
}

@end
