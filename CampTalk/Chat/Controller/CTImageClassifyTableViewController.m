//
//  CTImageClassifyTableViewController.m
//  CampTalk
//
//  Created by renge on 2019/8/25.
//  Copyright © 2019 yuru. All rights reserved.
//

#import "CTImageClassifyTableViewController.h"
#import <RGUIKit/RGUIKit.h>
#import <SDWebImage/SDWebImage.h>
#import "XJWebViewController.h"

@interface CTImageClassifyTableViewController () <UIPopoverPresentationControllerDelegate>

@end

@implementation CTImageClassifyTableViewController

+ (void)showPopoverFrom:(UIView *)sender withInfo:(NSArray <NSDictionary *> *)info {
    
    CTImageClassifyTableViewController *vc = [[CTImageClassifyTableViewController alloc] initWithStyle:UITableViewStylePlain];
    vc.infos = info;
    
    RGNavigationController *oneCtr = [RGNavigationController navigationWithRoot:vc style:RGNavigationBackgroundStyleNormal];
    oneCtr.tintColor = [UIColor blackColor];
    
    //设置这个后，popoverContentSize将无效
    //oneCtr.preferredContentSize = CGSizeMake(200, 200);
    //初始化
    oneCtr.modalPresentationStyle = UIModalPresentationPopover;
    oneCtr.popoverPresentationController.delegate = vc;
    oneCtr.popoverPresentationController.sourceView = sender;
    oneCtr.popoverPresentationController.sourceRect = sender.bounds;
    oneCtr.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionUp|UIPopoverArrowDirectionDown;
    [[self rg_topViewControllerByWindow:sender.window] presentViewController:oneCtr animated:YES completion:^{
        
    }];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.estimatedRowHeight = 0;
    self.tableView.estimatedSectionHeaderHeight = 0;
    self.tableView.estimatedSectionFooterHeight = 0;
    self.tableView.tableFooterView = [UIView new];
    [self.tableView registerClass:RGIconCell.class forCellReuseIdentifier:RGCellID];
    
    [self.tableView setNeedsLayout];
    [self.tableView layoutIfNeeded];
    self.preferredContentSize = CGSizeMake(self.preferredContentSize.width, self.tableView.contentSize.height);
    [self.tableView reloadData];
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:YES];
    [UIView animateWithDuration:0
                     animations:^{
                     }
                     completion:^(BOOL finished) {
                         if (self.navigationController.navigationBarHidden) {
                             [self.navigationController setNavigationBarHidden:YES animated:NO];
                         }
                     }];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    [UIView animateWithDuration:0
                     animations:^{
                     }
                     completion:^(BOOL finished) {
                         if (self.navigationController.navigationBarHidden) {
                             [self.navigationController setNavigationBarHidden:NO animated:NO];
                         }
                     }];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.infos.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *info = self.infos[indexPath.row];
    NSDictionary *baike = info[@"baike_info"];
    if (baike && baike.allKeys.count) {
        NSString *description = baike[@"description"];
        if (description.length > 100) {
            description = [[description substringToIndex:100] stringByAppendingString:@"..."];
        }
        CGFloat height = [description boundingRectWithSize:CGSizeMake(tableView.frame.size.width - 80 - 60, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:16]} context:nil].size.height;
        height += 40;
        return height;
    } else {
        return 70;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    RGIconCell *cell = [tableView dequeueReusableCellWithIdentifier:RGCellID forIndexPath:indexPath];
    cell.textLabel.numberOfLines = 10;
    cell.textLabel.font = [UIFont systemFontOfSize:16];
    cell.backgroundColor = [UIColor clearColor];
    
    NSDictionary *info = self.infos[indexPath.row];
    
    NSString *root = info[@"root"];
    NSString *keyword = info[@"keyword"];
    NSDictionary *baike = info[@"baike_info"];
    if (baike && baike.allKeys.count) {
        NSString *link = baike[@"baike_url"];
        NSString *description = baike[@"description"];
        NSString *image = baike[@"image_url"];
        
        image = [image stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        [cell.imageView sd_setImageWithURL:[NSURL URLWithString:image]];
        
        if (description.length > 100) {
            description = [[description substringToIndex:100] stringByAppendingString:@"..."];
        }
        cell.textLabel.text = description;
        cell.detailTextLabel.text = link;
        cell.iconSize = CGSizeMake(80, 80);
        cell.imageView.layer.cornerRadius = 4.f;
    } else {
        [cell.imageView sd_cancelCurrentImageLoad];
        cell.imageView.image = nil;
        cell.textLabel.text = keyword;
        cell.detailTextLabel.text = root;
        cell.iconSize = CGSizeZero;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSDictionary *info = self.infos[indexPath.row];
    
    NSString *keyword = info[@"keyword"];
    NSDictionary *baike = info[@"baike_info"];
    
    NSString *link = nil;
    if (baike && baike.allKeys.count) {
        link = baike[@"baike_url"];
    } else {
        link = [NSString stringWithFormat:@"https://www.baidu.com/s?wd=%@", keyword];
        link = [link stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    }
    
    XJWebViewController *vc = [[XJWebViewController alloc] init];
    vc.url = [NSURL URLWithString:link];
    vc.loadingProgressColor = [UIColor blackColor];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)configTitle {
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:CGPointMake(0, self.rg_layoutOriginY + self.tableView.contentOffset.y +1)];
    if (!indexPath) {
        return;
    }
    NSDictionary *info = self.infos[indexPath.row];
    NSString *keyword = info[@"keyword"];
    self.title = keyword;
}


#pragma mark - <UIPopoverPresentationControllerDelegate>

- (UIModalPresentationStyle)adaptivePresentationStyleForPresentationController:(UIPresentationController *)controller {
    return UIModalPresentationNone;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

@end
