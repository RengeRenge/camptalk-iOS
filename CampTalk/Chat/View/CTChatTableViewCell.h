//
//  CTChatTableViewCell.h
//  CampTalk
//
//  Created by kikilee on 2018/4/20.
//  Copyright © 2018年 yuru. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CTChatBubbleLabel.h"
#import "CTBubbleImageView.h"

@class CTChatTableViewCell;

@protocol CTChatTableViewCellActionDelegate <NSObject>

- (void)deleteChatTableViewCell:(CTChatTableViewCell *)cell;
- (void)lookupChatTableViewCell:(CTChatTableViewCell *)cell;
- (void)shareChatTableViewCell:(CTChatTableViewCell *)cell;

@end

extern NSString *const CTChatTableViewCellId;

@interface CTChatTableViewCell : UITableViewCell

@property (weak, nonatomic) IBOutlet CTBubbleImageView *thumbWapper;

@property (weak, nonatomic) IBOutlet CTChatBubbleLabel *chatBubbleLabel;

@property (weak, nonatomic) IBOutlet UILabel *timeLabel;

@property (copy, nonatomic) NSString *cellId;

@property (nonatomic, weak) id <CTChatTableViewCellActionDelegate> delegate;

@property (copy, nonatomic) UIImage *iconImage;

@property (assign, nonatomic) BOOL myDirection;

@property (assign, nonatomic) BOOL displayThumb;
@property (assign, nonatomic) BOOL displayLocalThumb;
@property (assign, nonatomic) CGFloat loadThumbProresss;
@property (assign, nonatomic) CGSize thumbPixSize;

+ (void)registerForTableView:(UITableView *)tableView;

+ (CGFloat)heightWithText:(NSString *)string width:(CGFloat)width;
+ (CGFloat)estimatedHeightWithText:(NSString *)string width:(CGFloat)width;

+ (CGFloat)heightWithThumbSize:(CGSize)thumbSize width:(CGFloat)width;

- (void)lookMe:(void(^)(BOOL flag))completion;
- (void)doAnimateOnLoadImageFinishIfNeed;

@end
