//
//  DeviceMenuTableViewController.m
//  liangbo-ios
//
//  Created by renge on 2018/7/22.
//  Copyright © 2018年 tong zhang. All rights reserved.
//

#import "XJMenuTableViewController.h"
#import <RGUIKit/RGUIKit.h>

@interface XJMenuTableViewController () <UIPopoverPresentationControllerDelegate>

@end

@implementation XJMenuTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.tableView registerClass:RGIconCell.class forCellReuseIdentifier:RGCellID];
    
//    [self.tableView layoutIfNeeded];
//    
//    self.preferredContentSize = CGSizeMake(self.preferredContentSize.width, self.tableView.contentSize.height);
}

- (void)presentFromViewController:(UIViewController *)viewController sourceView:(id)sourceView {
    self.modalPresentationStyle = UIModalPresentationPopover;
    
    UIPopoverPresentationController * popover = [self popoverPresentationController];
    popover.permittedArrowDirections = UIPopoverArrowDirectionUp;
    if ([sourceView isKindOfClass:UIBarButtonItem.class]) {
        popover.barButtonItem = sourceView;
    } else if ([sourceView isKindOfClass:UIView.class]) {
        popover.sourceView = sourceView;
    }
    popover.backgroundColor = [UIColor whiteColor];
    popover.delegate = self;
    [viewController presentViewController:self animated:YES completion:nil];
}

#pragma mark - UIPopoverPresentationControllerDelegate

- (UIModalPresentationStyle)adaptivePresentationStyleForPresentationController:(UIPresentationController *)controller{
    return UIModalPresentationNone; //不适配
}

- (BOOL)popoverPresentationControllerShouldDismissPopover:(UIPopoverPresentationController *)popoverPresentationController{
    return YES;  //点击蒙版popover消失， 默认YES
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _items.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_items.count == 0) {
        return 0;
    }
    return self.preferredContentSize.height / _items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    RGIconCell *cell = [tableView dequeueReusableCellWithIdentifier:RGCellID forIndexPath:indexPath];
    
    NSInteger menuId = _items[indexPath.row].intValue;
    
    NSAttributedString *title = [_delegate menuViewController:self menuTitleWithMenuId:menuId];
    cell.textLabel.attributedText = title;
    
    if (!_hideIcon) {
        UIImage *icon = [_delegate menuViewController:self menuImageWithMenuId:menuId];
        cell.imageView.image = icon;
        cell.iconSize = [_delegate menuViewController:self menuImageSizeWithMenuId:menuId];
    } else {
        cell.imageView.image = nil;
        cell.iconSize = CGSizeZero;
    }
    
    
    cell.imageView.tintColor = cell.textLabel.textColor;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self.delegate respondsToSelector:@selector(menuViewController:didSelecteMenuId:)]) {
        int menuId = _items[indexPath.row].intValue;
        [self.delegate menuViewController:self didSelecteMenuId:menuId];
    }
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

@end
