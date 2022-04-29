//
//  RGMessageViewModel.h
//  CampTalk
//
//  Created by renge on 2019/8/24.
//  Copyright © 2019 yuru. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CTChatTableViewCell.h"
#import "RGMessage.h"

NS_ASSUME_NONNULL_BEGIN

@interface RGMessageViewModel : NSObject

+ (void)configCell:(UITableViewCell *)aCell
       withMessage:(RGMessage *)message
     showTimeLabel:(BOOL)showTimeLabel
         darkColor:(BOOL)darkColor
             async:(BOOL)async;

@end

NS_ASSUME_NONNULL_END
