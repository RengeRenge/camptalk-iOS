//
//  DeviceMenuTableViewController.h
//  liangbo-ios
//
//  Created by renge on 2018/7/22.
//  Copyright © 2018年 tong zhang. All rights reserved.
//

#import <UIKit/UIKit.h>

@class XJMenuTableViewController;

@protocol XJMenuDelegate <NSObject>

- (UIImage *)menuViewController:(XJMenuTableViewController *)viewController menuImageWithMenuId:(NSInteger)menuId;

- (CGSize)menuViewController:(XJMenuTableViewController *)viewController menuImageSizeWithMenuId:(NSInteger)menuId;

- (NSAttributedString *)menuViewController:(XJMenuTableViewController *)viewController menuTitleWithMenuId:(NSInteger)menuId;

- (void)menuViewController:(XJMenuTableViewController *)viewController didSelecteMenuId:(NSInteger)menuId;

@end

@interface XJMenuTableViewController : UITableViewController

@property (nonatomic, strong) NSArray <NSNumber *> *items;
@property (nonatomic, weak) id <XJMenuDelegate> delegate;
@property (nonatomic, assign) BOOL hideIcon;

- (void)presentFromViewController:(UIViewController *)viewController sourceView:(id)sourceView;

@end
