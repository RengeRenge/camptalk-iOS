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

+ (void)configCell:(UITableViewCell *)aCell withMessage:(RGMessage *)message async:(BOOL)async {
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
    
    if (message.hasImage) {
        [self loadThumbWithCell:cell withMessage:message async:async];
    } else if (message.message.length) {
        [cell.thumbWapper.imageView sd_cancelCurrentImageLoad];
        [cell.thumbWapper.imageView rg_cancelSetImagePath];
        [self loadTextWithCell:cell withMessage:message];
    }
    [cell setNeedsLayout];
}

+ (void)loadThumbWithCell:(CTChatTableViewCell *)cell withMessage:(RGMessage *)message async:(BOOL)async {
    
    NSString *cellId = cell.cellId;
    
    cell.chatBubbleLabel.label.text = nil;
    cell.displayThumb = YES;
    cell.thumbPixSize = message.g_thumbSize;
    NSURL *url = [message imageUrlForThumb:YES];
    
//    url = [NSURL URLWithString:@"https://timgsa.baidu.com/timg?image&quality=80&size=b9999_10000&sec=11566704414981&di=43b40492bcb99148a9e8dfd280f4a364&imgtype=0&src=http%3A%2F%2Fi1.17173.itc.cn%2F2015%2Fnews%2F2015%2F06%2F09%2Fmsh0609xl03.gif"];
    if ([url.scheme hasPrefix:@"http"]) {
        cell.displayLocalThumb = NO;
        [cell.thumbWapper.imageView
         sd_setImageWithURL:url
         placeholderImage:nil
//         options:SDWebImageFromLoaderOnly
         options:0
         progress:^(NSInteger receivedSize, NSInteger expectedSize, NSURL * _Nullable targetURL) {
             dispatch_async(dispatch_get_main_queue(), ^{
                 if (![cellId isEqual:cell.cellId]) {
                     return;
                 }
                 cell.loadThumbProresss = 1.0 * receivedSize / expectedSize;
             });
         } completed:^(UIImage * _Nullable image, NSError * _Nullable error, SDImageCacheType cacheType, NSURL * _Nullable imageURL) {
             if (![cellId isEqual:cell.cellId]) {
                 return;
             }
             cell.loadThumbProresss = 1;
             [cell doAnimateOnLoadImageFinishIfNeed];
         }];
    } else {
        cell.displayLocalThumb = YES;
        cell.loadThumbProresss = 1;
        [cell.thumbWapper.imageView rg_setImagePath:url.path
                                              async:async
                                           delayGif:1.0
                                       continueLoad:nil];
    }
}

+ (void)loadTextWithCell:(CTChatTableViewCell *)cell withMessage:(RGMessage *)message {
    cell.displayThumb = NO;
    cell.thumbWapper.image = nil;
    cell.loadThumbProresss = 1;
    cell.chatBubbleLabel.label.text = message.message;
}

@end
