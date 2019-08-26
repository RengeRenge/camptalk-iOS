//
//  CTImageClassifyTableViewController.h
//  CampTalk
//
//  Created by renge on 2019/8/25.
//  Copyright © 2019 yuru. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface CTImageClassifyTableViewController : UITableViewController

@property (nonatomic, strong) NSArray <NSDictionary *> *infos;

+ (void)showPopoverFrom:(UIView *)sender withInfo:(NSArray <NSDictionary *> *)info;

@end

NS_ASSUME_NONNULL_END
