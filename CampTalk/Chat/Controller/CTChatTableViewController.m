//
//  CTChatTableViewController.m
//  CampTalk
//
//  Created by renge on 2018/4/19.
//  Copyright © 2018年 yuru. All rights reserved.
//

#import "CTChatTableViewController.h"
#import "RGImagePicker.h"

#import "CTChatTableViewCell.h"
#import "CTChatInputView.h"
#import "CTStubbornView.h"
#import "CTCameraView.h"
#import "CTMusicButton.h"

#import "UIImageView+RGGif.h"

#import <RGUIKit/RGUIKit.h>
#import "UIViewController+DragBarItem.h"
#import "UIView+PanGestureHelp.h"

#import "CTUserConfig.h"
#import "CTFileManger.h"

#import "RGMessage.h"
#import "RGRealmManager.h"
#import "RGMessageViewModel.h"
#import "CTChatIconConfig.h"
#import <AFNetworking/AFNetworking.h>

#import "XJWebViewController.h"
#import "CTImageClassifyTableViewController.h"

static CGFloat kMinInputViewHeight = 60.f;

@interface CTChatTableViewController () <CTChatInputViewDelegate, RGUINavigationControllerShouldPopDelegate, CTCameraViewDelegate, UITableViewDataSource, UITableViewDelegate, CTChatTableViewCellActionDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) CTStubbornView *tableViewCover;
@property (nonatomic, strong) CTStubbornView *tableViewBackground;

@property (nonatomic, strong) CTChatInputView *mInputView;
@property (nonatomic, strong) CTCameraView *cameraView;

@property (nonatomic, assign) CGFloat keyboardHeight;
@property (nonatomic, assign) BOOL needScrollToBottom;
@property (nonatomic, assign) BOOL viewControllerWillPop;

@property (nonatomic, strong) NSIndexPath *recordMaxIndexPath;
@property (nonatomic, assign) CGPoint recordOffSet;

@property (nonatomic, strong) RLMResults <RGMessage *> *messages;
@property (nonatomic, strong) RLMNotificationToken *messagesToken;
@property (nonatomic, strong) RLMResults <RGMessage *> *unReadMessages;

@property (nonatomic, strong) CTMusicButton *dragButton;

@end

@implementation CTChatTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationItem.title = @"CampTalk";
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.estimatedRowHeight = 0;
    self.tableView.estimatedSectionFooterHeight = 0;
    self.tableView.estimatedSectionHeaderHeight = 0;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.view.backgroundColor = [UIColor whiteColor];
    
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    UILongPressGestureRecognizer *longeTap = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(__changeBg:)];
    [self.tableView addGestureRecognizer:longeTap];
    [self.view addSubview:self.tableView];
    
    // Config TableView
    [CTChatTableViewCell registerForTableView:self.tableView];
    
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.tableView.delaysContentTouches = NO;
    
    // data
    __weak typeof(self) wSelf = self;
    _messages = [RGMessage messageWithRoomId:self.roomId username:self.mUserId];
    self.messagesToken = [_messages addNotificationBlock:^(RLMResults<RGMessage *> * _Nullable results, RLMCollectionChange * _Nullable change, NSError * _Nullable error) {
        if (!wSelf) {
            return;
        }
        [wSelf __realmResults:results change:change error:error];
    }];
    
    _unReadMessages = [RGMessage unreadMessageWithRoomId:self.roomId username:self.mUserId];
    
    [self setNeedScrollToBottom:YES];
    
    _mInputView = [[CTChatInputView alloc] initWithFrame:CGRectMake(0, self.view.frame.size.height - kMinInputViewHeight, self.view.bounds.size.width, kMinInputViewHeight)];
    _mInputView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [_mInputView.actionButton setImage:[UIImage rg_imageWithName:@"fuzi_hd"] forState:UIControlStateNormal];
    _mInputView.delegate = self;
    [self.view addSubview:_mInputView];
    [self __configInputViewLayout];
    
    _cameraView = [[CTCameraView alloc] init];
    _cameraView.delegate = self;
    _cameraView.hidden = YES;
    [_cameraView shadow:YES];
    [_cameraView showInView:self.view tintColorEffectView:nil];
    
    [self __configIconPlace];
    
    [self __addKeyboardNotification];
    
    [self __configBackgroundImage];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(__configBackgroundImage) name:UCChatBackgroundImagePathChangedNotification object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (_needScrollToBottom) {
        if (_messages.count <= 0) {
            _needScrollToBottom = NO;
            return;
        }
        self.tableView.alpha = 0;
        [self.tableView setNeedsLayout];
        [self.tableView layoutIfNeeded];
        [self.tableView rg_scrollViewToBottom:NO];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_needScrollToBottom = NO;
            
            NSArray<__kindof UITableViewCell *> *visibleCells = self.tableView.visibleCells;
            NSArray<NSIndexPath *> *indexPathsForVisibleRows = self.tableView.indexPathsForVisibleRows;
            [visibleCells enumerateObjectsUsingBlock:^(__kindof UITableViewCell * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                RGMessage *msg = self.messages[indexPathsForVisibleRows[idx].row];
                [self _configCell:obj withMessage:msg];
                [obj setNeedsLayout];
            }];
            
            [UIView animateWithDuration:0.5 animations:^{
                self.tableView.alpha = 1;
            }];
        });
    }
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    CGFloat recordTBHeight = self.tableView.frame.size.height;
    
    self.tableView.frame = self.view.bounds;
    UIEdgeInsets edge = UIEdgeInsetsMake(0, 0, self.tableView.contentInset.bottom, 0);
    [self rg_setFullFrameScrollView:self.tableView wtihAdditionalContentInset:edge];
    
    _cameraView.frame = self.rg_safeAreaBounds;
    
    [self __configStubbornViewLayout];
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(__configInputViewTintColor) object:nil];
    [self performSelector:@selector(__configInputViewTintColor) withObject:nil afterDelay:0.3];
    
    [NSObject cancelPreviousPerformRequestsWithTarget:_cameraView selector:@selector(adjustTintColor) object:nil];
    [_cameraView performSelector:@selector(adjustTintColor) withObject:nil afterDelay:0.3];
    
    if (!_needScrollToBottom) {
        
        if (recordTBHeight != self.tableView.frame.size.height) {
            
            if (!_recordMaxIndexPath || self.messages.count <= 0) {
                return;
            }
            
            [UIView performWithoutAnimation:^{
                if (self.recordMaxIndexPath.row >= self.messages.count) {
                    self.recordMaxIndexPath = [NSIndexPath indexPathForRow:self.messages.count - 1 inSection:0];
                }
                [self.tableView scrollToRowAtIndexPath:self.recordMaxIndexPath atScrollPosition:UITableViewScrollPositionBottom animated:NO];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [UIView performWithoutAnimation:^{
                        [self.tableView scrollToRowAtIndexPath:self.recordMaxIndexPath atScrollPosition:UITableViewScrollPositionBottom animated:NO];
                    }];
                });
            }];
        }
    }
}

- (void)viewSafeAreaInsetsDidChange {
    [super viewSafeAreaInsetsDidChange];
    [self __configInputViewLayout];
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(__configInputViewTintColor) object:nil];
    [self performSelector:@selector(__configInputViewTintColor) withObject:nil afterDelay:0.3];
}

- (void)__configIconPlace {
    
    [_mInputView removeAllToolBarItem];
    [self removeAllRightDragBarItem];
    
    NSArray <NSString *> *allkeys = [CTChatIconConfig.toolConfig allKeys];
    for (NSString *placeNumber in allkeys) {
        CTChatToolIconPlace place = placeNumber.integerValue;
        
        NSArray <NSNumber *> *allIcon = CTChatIconConfig.toolConfig[placeNumber];
        
        for (NSNumber *iconIdNumber in allIcon) {
            
            CTChatToolIconId iconId = iconIdNumber.integerValue;
            
            switch (place) {
                case CTChatToolIconPlaceInputView: {
                    UIView *icon = [self iconCopyWithIconId:iconId];
                    [_mInputView addToolBarItem:[CTChatInputViewToolBarItem itemWithIcon:icon identifier:iconId]];
                    if (iconId == CTChatToolIconIdCamara) {
                        _cameraView.hidden = YES;
                    }
                    break;
                }
                case CTChatToolIconPlaceNavigation: {
                    UIView *icon = [self iconCopyWithIconId:iconId];
                    [self addRightDragBarItemWithIcon:icon itemId:iconId];
                    if (iconId == CTChatToolIconIdCamara) {
                        _cameraView.hidden = YES;
                    }
                    break;
                }
                case CTChatToolIconPlaceMainView: {
                    switch (iconId) {
                        case CTChatToolIconIdCamara:
                            _cameraView.hidden = NO;
                            break;
                        default:
                            break;
                    }
                    break;
                }
                default:
                    break;
            }
        }
    }
}

- (void)__updateIconConfig {
    NSMutableDictionary *toolConfig = CTChatIconConfig.toolConfig;
    NSMutableArray <NSNumber *> *icons = [NSMutableArray arrayWithArray:@[@(CTChatToolIconIdCamara), @(CTChatToolIconIdMusic)]];
    
    for (CTChatToolIconPlace place = CTChatToolIconPlaceNavigation; place < CTChatToolIconPlaceCount; place ++) {
        NSMutableArray *newArray = [NSMutableArray array];
        switch (place) {
            case CTChatToolIconPlaceMainView:{
                [icons enumerateObjectsUsingBlock:^(NSNumber * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    if (obj.integerValue == CTChatToolIconIdCamara && !self.cameraView.isHidden) {
                        [newArray addObject:obj];
                        *stop = YES;
                    }
                }];
                break;
            }
            case CTChatToolIconPlaceInputView:{
                [self.mInputView.toolBarItems enumerateObjectsUsingBlock:^(CTChatInputViewToolBarItem * _Nonnull items, NSUInteger idx, BOOL * _Nonnull stop) {
                    [icons enumerateObjectsUsingBlock:^(NSNumber * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                        if (items.identifier == obj.integerValue) {
                            [newArray addObject:obj];
                        }
                    }];
                }];
                break;
            }
            case CTChatToolIconPlaceNavigation:{
                NSArray <NSNumber *> *items = self.rightDragBarItemIds;
                [items enumerateObjectsUsingBlock:^(NSNumber * _Nonnull itemId, NSUInteger idx, BOOL * _Nonnull stop) {
                    [icons enumerateObjectsUsingBlock:^(NSNumber * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                        if (itemId.integerValue == obj.integerValue) {
                            [newArray addObject:obj];
                        }
                    }];
                }];
            }
            default:
                break;
        }
        if (newArray.count) {
            [toolConfig setObject:newArray forKey:@(place).stringValue];
        } else {
            [toolConfig removeObjectForKey:@(place).stringValue];
        }
        [icons removeObjectsInArray:newArray];
    }
    [CTChatIconConfig updateConfig:toolConfig];
}

- (void)__changeBg:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        [RGImagePicker presentByViewController:self pickResult:^(NSArray<PHAsset *> *phassets, UIViewController *pickerViewController) {
            [RGImagePicker loadResourceFromAssets:phassets completion:^(NSArray<NSDictionary *> * _Nonnull imageData, NSError * _Nullable error) {
                if (error) {
                    return;
                }
                [pickerViewController.presentingViewController dismissViewControllerAnimated:YES completion:nil];
                if (!imageData.count) {
                    return;
                }
                [CTUserConfig setChatBackgroundImageData:imageData.firstObject[RGImagePickerResourceData]];
            }];
        }];
    }
}

- (void)__configBackgroundImage {
    NSString *path = [CTUserConfig chatBackgroundImagePath];
    if (!_tableViewBackground) {
        CTStubbornView *bgView = [[CTStubbornView alloc] initWithFrame:self.view.bounds];
        bgView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        bgView.contentMode = UIViewContentModeScaleAspectFill;
        bgView.clipsToBounds = YES;
        _cameraView.tintColorEffectView = bgView;
        _tableViewBackground = bgView;
        [self.view insertSubview:bgView atIndex:0];
    }
    if (!_tableViewCover) {
        _tableViewCover = [[CTStubbornView alloc] initWithFrame:self.view.bounds];
        _tableViewCover.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _tableViewCover.contentMode = UIViewContentModeScaleAspectFill;
        [_tableViewCover setGradientDirection:YES];
        [self.view addSubview:_tableViewCover];
    }
    
    [_tableViewBackground rg_setImagePath:path async:NO delayGif:0.3 continueLoad:nil];
    [_tableViewCover rg_setImagePath:path async:NO delayGif:0.3 continueLoad:nil];
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(__configInputViewTintColor) object:nil];
    [self performSelector:@selector(__configInputViewTintColor) withObject:nil afterDelay:0.3];
    
    [NSObject cancelPreviousPerformRequestsWithTarget:_cameraView selector:@selector(adjustTintColor) object:nil];
    [_cameraView performSelector:@selector(adjustTintColor) withObject:nil afterDelay:0.3];
}

- (UIView *)iconCopyWithIconId:(CTChatToolIconId)iconId {
    UIView *icon = nil;
    switch (iconId) {
        case CTChatToolIconIdCamara:
            _cameraView.hidden = YES;
            icon = [self createCameraButton];
            break;
        case CTChatToolIconIdMusic:
            icon = [self createMusicButton];
            break;
        default:
            break;
    }
    return icon;
}

- (void)__configStubbornViewLayout {
    self.tableViewCover.frame = self.view.bounds;
    [self __adjustTableViewCoverAlpha];
}

- (void)__adjustTableViewCoverAlpha {
    CGRect barFrame = self.navigationController.navigationBar.frame;
    
    CGFloat begain = (barFrame.origin.y + barFrame.size.height / 2.f) / _tableViewCover.bounds.size.height;
    
    CGFloat end = (barFrame.size.height + barFrame.origin.y + 10.f) / _tableViewCover.bounds.size.height;
    [_tableViewCover setGradientBegain:begain end:end];
}

#pragma mark - RGUINavigationControllerShouldPopDelegate

- (BOOL)rg_navigationControllerShouldPop:(UINavigationController *)navigationController isInteractive:(BOOL)isInteractive {
    _viewControllerWillPop = YES;
    _recordOffSet = self.tableView.contentOffset;
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(setViewControllerWillPop:) object:@(NO)];
    [self performSelector:@selector(setViewControllerWillPop:) withObject:@(NO) afterDelay:0.5f];
    
    return YES;
}

- (void)rg_navigationController:(UINavigationController *)navigationController interactivePopResult:(BOOL)finished {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(setViewControllerWillPop:) object:@(NO)];
    _viewControllerWillPop = finished;
    if (!finished) {
        self.tableView.contentOffset = _recordOffSet;
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _messages.count;
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    RGMessage *model = _messages[indexPath.row];
    if (model.thumbUrl) {
        return [CTChatTableViewCell heightWithThumbSize:model.g_thumbSize tableView:tableView];
    } else if (model.message.length) {
        return [CTChatTableViewCell heightWithText:model.message tableView:tableView];
    }
    return 0.f;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    CTChatTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CTChatTableViewCellId forIndexPath:indexPath];
    cell.delegate = self;
    RGMessage *message = _messages[indexPath.row];
    [self _configCell:cell withMessage:message];
    return cell;
}

- (void)_configCell:(CTChatTableViewCell *)cell withMessage:(RGMessage *)message {
    if (!cell) {
        return;
    }
    if (!_needScrollToBottom) {
        [RGMessageViewModel configCell:cell withMessage:message async:NO];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(__recordMaxIndexPathIfNeed) object:nil];
    [self performSelector:@selector(__recordMaxIndexPathIfNeed) withObject:nil afterDelay:0.3f inModes:@[NSRunLoopCommonModes]];
    
    RGMessage *message = self.messages[indexPath.row];
    if (message.unread) {
        [(CTChatTableViewCell *)cell lookMe:^(BOOL flag) {
            [[RGRealmManager messageRealm] transactionWithBlock:^{
                message.unread = NO;
            }];
        }];
    }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (!decelerate) {
        [self __endScroll];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [self __endScroll];
}

- (void)__endScroll {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(__recordMaxIndexPathIfNeed) object:nil];
    [self performSelector:@selector(__recordMaxIndexPathIfNeed) withObject:nil afterDelay:0.3f inModes:@[NSRunLoopCommonModes]];
}

- (void)__recordMaxIndexPathIfNeed {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(__recordMaxIndexPathIfNeed) object:nil];
    CGFloat pointY = self.tableView.contentOffset.y + self.tableView.frame.size.height - self.tableView.contentInset.bottom - 1;
    CGFloat height = self.tableView.frame.size.height * 2;
    NSIndexPath *indexPath = [self.tableView indexPathsForRowsInRect:CGRectMake(0, pointY-height, 1, height)].lastObject;
    _recordMaxIndexPath = indexPath.copy;
}

#pragma mark - CTChatInputViewDelegate

- (void)contentSizeDidChange:(CTChatInputView *)chatInputView size:(CGSize)size {
    [self __configInputViewLayout];
}

- (void)chatInputView:(CTChatInputView *)chatInputView willRemoveItem:(CTChatInputViewToolBarItem *)item syncAnimations:(void (^)(void))syncAnimations {
    
    __weak typeof(self) wSelf = self;
    
    UIView *icon = item.icon;
    
    CGPoint center = [chatInputView convertPoint:icon.center toView:self.navigationController.view];
    [icon removeFromSuperview];
    icon.tintColor = chatInputView.tintColor;
    [self.navigationController.view addSubview:icon];
    icon.center = center;
    
    [self addRightDragBarItemWithDragIcon:icon
                                   itmeId:item.identifier
                          ignoreIntersect:item.identifier == CTChatToolIconIdMusic
                                 copyIcon:^UIView *{
                                     return [wSelf iconCopyWithIconId:item.identifier];
                                 } syncAnimate:^(UIView *customView) {
                                     syncAnimations();
                                 } completion:^(BOOL added) {
                                     if (!added) {
                                         if (item.identifier == CTChatToolIconIdCamara) {
                                             wSelf.cameraView.hidden = NO;
                                             [wSelf.cameraView setCameraButtonCenterPoint:[icon.superview convertPoint:icon.center toView:wSelf.cameraView]];
                                             
                                             [wSelf.cameraView showCameraButtonWithAnimate:NO];
                                             [wSelf.cameraView performSelector:@selector(hideCameraButton) withObject:nil afterDelay:1];
                                             
                                             [UIView animateWithDuration:0.3 animations:^{
                                                 syncAnimations();
                                             } completion:^(BOOL finished) {
                                                 [wSelf __updateIconConfig];
                                             }];
                                         }
                                     }
                                     [icon removeFromSuperview];
                                     [NSObject cancelPreviousPerformRequestsWithTarget:wSelf selector:@selector(__configInputViewTintColor) object:nil];
                                     [wSelf performSelector:@selector(__configInputViewTintColor) withObject:nil afterDelay:0.3];
                                 }];
}

- (void)chatInputView:(CTChatInputView *)chatInputView didAddItem:(CTChatInputViewToolBarItem *)item {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(__configInputViewTintColor) object:nil];
    [self __configInputViewTintColor];
}

- (void)chatInputView:(CTChatInputView *)chatInputView didTapActionButton:(UIButton *)button {
    if (!chatInputView.text.length) {
        return;
    }
    RGMessage *model = [RGMessage new];
    model.message = chatInputView.text;
    
    [UIView performWithoutAnimation:^{
        chatInputView.text = nil;
        [chatInputView layoutIfNeeded];
    }];
    [self insertChatData:model];
}

- (void)__configInputViewLayout {
    if (_viewControllerWillPop) {
        return;
    }
    CGRect bounds = self.view.bounds;
    
    CGFloat inputHeight = MAX(kMinInputViewHeight, _mInputView.contentHeight);
    CGFloat bottomMargin = 10.f;
    
    //    CGFloat lastBottom = bounds.size.height - CGRectGetMinY(_inputView.frame) + bottomMargin - self.rg_viewSafeAreaInsets.bottom;
    
    _mInputView.frame = CGRectMake(0, bounds.size.height - inputHeight - _keyboardHeight, bounds.size.width, inputHeight);
    
    CGFloat safeAreaBottom = 0.f;
    if (@available(iOS 11.0, *)) {
        safeAreaBottom = _mInputView.safeAreaInsets.bottom;
        _mInputView.frame = UIEdgeInsetsInsetRect(_mInputView.frame, UIEdgeInsetsMake(-safeAreaBottom, 0, 0, 0));
    }
    
    CGFloat bottom = bounds.size.height - CGRectGetMinY(_mInputView.frame) + bottomMargin - self.rg_viewSafeAreaInsets.bottom;
    
    CGPoint contentOffset = self.tableView.contentOffset;
    UIEdgeInsets contentInset = self.tableView.contentInset;
    
    CGFloat contentBottom = self.tableView.frame.size.height - self.rg_viewSafeAreaInsets.bottom - self.tableView.contentSize.height;
    
    if (_keyboardHeight >= 0 && contentBottom - inputHeight - self.rg_viewSafeAreaInsets.top > 0) {
        if (_keyboardHeight == 0) {
            contentOffset.y = -self.rg_viewSafeAreaInsets.top;
        } else {
            CGFloat offSetY = bottom - contentBottom;
            contentOffset.y = MAX(offSetY, -self.rg_viewSafeAreaInsets.top);
        }
    } else {
        contentOffset.y += bottom - contentInset.bottom;
    }
    
    contentInset.bottom = bottom;
    
    self.tableView.contentInset = contentInset;
    self.tableView.contentOffset = contentOffset;
    
    UIEdgeInsets scrollIndicatorInsets = self.tableView.scrollIndicatorInsets;
    scrollIndicatorInsets.bottom = bottom - bottomMargin;
    self.tableView.scrollIndicatorInsets = scrollIndicatorInsets;
    
    if (_needScrollToBottom) {
        [self.tableView rg_scrollViewToBottom:NO];
    }
}

- (void)__configInputViewTintColor {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(__configInputViewTintColor) object:nil];
    
    CGSize boundsSize = self.view.bounds.size;
    UIEdgeInsets edge = self.rg_viewSafeAreaInsets;
    CGRect toolBarFrame = _mInputView.toolBarFrame;
    
    CGFloat toolBarHeight = CTChatInputToolBarHeight + edge.bottom;
    CGFloat toolBarWidth = MAX(toolBarFrame.size.width, CTChatInputToolBarHeight);
    edge.left = toolBarFrame.origin.x + _mInputView.contentView.frame.origin.x;

    UIImage *image = [(UIImageView *)self.tableView.backgroundView image];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        
        CGSize size = [image rg_sizeThatFill:boundsSize];
        CGSize pixSize = image.rg_pixSize;
        CGFloat scale = pixSize.width / size.width;
        
        CGFloat x = (size.width - boundsSize.width) / 2.f + edge.left;
        CGFloat y = size.height - (size.height - boundsSize.height) / 2.f - toolBarHeight;
        
        
        UIImage *cropImage = [image rg_cropInPixRect:
                              CGRectMake(x * scale,
                                         y * scale,
                                         toolBarWidth * scale,
                                         (toolBarHeight - edge.bottom) * scale)];
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self.mInputView updateNormalTintColorWithBackgroundImage:cropImage];
        });
    });
}

#pragma mark - CTCameraViewDelegate

- (void)cameraView:(CTCameraView *)cameraView didDragButton:(UIButton *)cameraButton {
    [_mInputView updateInputViewDragIcon:cameraButton toolId:CTChatToolIconIdCamara copyIconBlock:^UIView *{
        return [self createCameraButton];
    }];
}

- (void)cameraView:(CTCameraView *)cameraView endDragButton:(UIButton *)cameraButton layoutBlock:(void (^)(BOOL))layout {
    
    __weak typeof(self) wSelf = self;
    
    [_mInputView addOrRemoveInputViewToolBarWithDragIcon:cameraButton toolId:CTChatToolIconIdCamara copyIconBlock:^UIView *{
        
        return [wSelf createCameraButton];
        
    } customAnimate:nil completion:^(BOOL added) {
        
        if (added) {
            cameraView.hidden = YES;
            layout(YES);
            [wSelf __updateIconConfig];
            return;
        }
        
        [wSelf addRightDragBarItemWithDragIcon:cameraButton itmeId:CTChatToolIconIdCamara ignoreIntersect:NO copyIcon:^UIView *{
            return [wSelf createCameraButton];
        } syncAnimate:nil completion:^(BOOL added) {
            if (added) {
                cameraView.hidden = YES;
                layout(YES);
                return;
            }
            layout(added);
        }];
    }];
}

- (void)cameraView:(CTCameraView *)cameraView didTapButton:(UIButton *)cameraButton {
    [self shareMedia:cameraButton];
}

- (UIButton *)createCameraButton {
    UIButton *button = _cameraView.copyCameraButton;
    [button addTarget:self action:@selector(shareMedia:) forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)shareMedia:(UIButton *)sender {
    
    __block BOOL loading;
    
    [RGImagePicker presentByViewController:self maxCount:10 pickResult:^(NSArray<PHAsset *> *phassets, UIViewController *pickerViewController) {
        
        if (loading) {
            return;
        }
        
        loading = YES;
        
        [RGImagePicker loadResourceFromAssets:phassets thumbSize:CGSizeMake(1280, 1280) completion:^(NSArray<NSDictionary *> * _Nonnull infos, NSError * _Nullable error) {
            loading = NO;
            if (error) {
                return;
            }
            
            [pickerViewController.presentingViewController dismissViewControllerAnimated:YES completion:^{
                [infos enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull info, NSUInteger idx, BOOL * _Nonnull stop) {
                    NSData *imageData = info[RGImagePickerResourceData];
                    NSData *thumbData = info[RGImagePickerResourceThumbData];
                    if (!imageData.length) {
                        return;
                    }
                    if (!thumbData.length) {
                        thumbData = imageData;
                    }
                    
                    PHAsset *asset = phassets[idx];
                    
                    NSString *filename = info[RGImagePickerResourceFilename];
                    NSString *thumbName = nil;
                    BOOL isGif = [[info[RGImagePickerResourceType] lowercaseString] containsString:@"gif"];
                    if (isGif) {
                        thumbName = [asset.localIdentifier stringByAppendingPathComponent:filename];
                        thumbData = imageData;
                    } else {
                        thumbName = [asset.localIdentifier stringByAppendingPathComponent:[NSString stringWithFormat:@"thumb-%@", filename]];
                    }
                    
                    RGMessage *model = [RGMessage new];
                    
                    NSString *path = [CTFileManger.cacheManager createFile:thumbName atFolder:UCChatDataFolderName data:thumbData];
                    if (!path.length) {
                        return;
                    }
                    model.thumbUrl = thumbName;
                    model.thumbSize = info[RGImagePickerResourceThumbSize];
                    
                    filename = [asset.localIdentifier stringByAppendingPathComponent:filename];
                    if (!isGif) {
                        path = [CTFileManger.cacheManager createFile:filename atFolder:UCChatDataFolderName data:imageData];
                        if (!path.length) {
                            return;
                        }
                    }
                    model.originalImageUrl = filename;
                    model.originalImageSize = info[RGImagePickerResourceSize];
                    [self insertChatData:model];
                }];
            }];
        }];
    }];
}

#pragma mark - CTMusicButton

- (CTMusicButton *)createMusicButton {
    CTMusicButton *music = [CTMusicButton new];
    [music sizeToFit];
//    music.tintColor = [UIColor whiteColor];
    
    __weak typeof(self) wSelf = self;
    music.clickBlock = ^(CTMusicButton *button) {
        [wSelf playMusic:button];
    };
    music.isPlaying = YES;
    return music;
}

- (void)playMusic:(CTMusicButton *)sender {
    NSLog(@"play music");
    sender.isPlaying = !sender.isPlaying;
}

#pragma mark - UIViewController + DragBarItem

- (void)dragItem:(UIView *)icon didDrag:(NSInteger)itmeId {
    [_mInputView updateInputViewDragIcon:icon toolId:itmeId copyIconBlock:^UIView *{
        return [self iconCopyWithIconId:itmeId];
    }];
}

- (BOOL)dragItemShouldRemove:(UIView *)icon endDrag:(NSInteger)itmeId {
    
    __weak typeof(self) wSelf = self;
    __block BOOL remove = YES;
    
    [_mInputView addOrRemoveInputViewToolBarWithDragIcon:icon toolId:itmeId copyIconBlock:^UIView *{
        return [wSelf iconCopyWithIconId:itmeId];
    } customAnimate:nil completion:^(BOOL added) {
        remove = added;
        if (added) {
            [wSelf __updateIconConfig];
            return;
        }
        
        if (itmeId == CTChatToolIconIdCamara) {
            
            remove = YES;
            
            wSelf.cameraView.hidden = NO;
            [wSelf.cameraView setCameraButtonCenterPoint:[icon.superview convertPoint:icon.center toView:wSelf.cameraView]];
            
            [wSelf.cameraView showCameraButtonWithAnimate:NO];
            [wSelf.cameraView performSelector:@selector(hideCameraButton) withObject:nil afterDelay:1];
        }
    }];
    return remove;
}

- (void)dragItemDidDragAdd:(UIView *)icon didDrag:(NSInteger)itemId {
    [self __updateIconConfig];
}

- (void)dragItemDidDragRemove:(UIView *)icon didDrag:(NSInteger)itemId {
    [self __updateIconConfig];
}

#pragma mark - CTChatTableViewCellActionDelegate

- (void)shareChatTableViewCell:(CTChatTableViewCell *)cell {
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    if (!indexPath) {
        return;
    }
    
    NSArray *items = nil;
    UIView *target = nil;

    RGMessage *message = self.messages[indexPath.row];
    if (message.hasImage) {
        items = @[[message imageUrlForThumb:NO]];
        target = cell.thumbWapper;
    } else {
        items = @[cell.chatBubbleLabel.label.text];
        target = cell.chatBubbleLabel;
    }
    
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:nil];
    activityVC.completionWithItemsHandler = ^(UIActivityType  _Nullable activityType, BOOL completed, NSArray * _Nullable returnedItems, NSError * _Nullable activityError) {
        if (completed) {
            
        } else {
            
        }
    };
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        activityVC.popoverPresentationController.sourceView = target;
        [self presentViewController:activityVC animated:YES completion:nil];
    } else {
        [self presentViewController:activityVC animated:YES completion:nil];
    }
}

- (void)lookupChatTableViewCell:(CTChatTableViewCell *)cell {
    if (!cell.displayThumb) {
        NSString *text = cell.chatBubbleLabel.label.text;
        
        NSError *error;
        NSDataDetector *dataDetector=[NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink|NSTextCheckingTypePhoneNumber error:&error];
        NSArray *arrayOfAllMatches = [dataDetector matchesInString:text options:NSMatchingReportProgress range:NSMakeRange(0, text.length)];
        
        if (arrayOfAllMatches.count <= 0) {
            NSString *url = [@"https://www.baidu.com/s?wd=" stringByAppendingString:text];
            [XJWebViewController showPopoverFrom:cell.chatBubbleLabel withUrl:url];
            return;
        }
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        for (NSTextCheckingResult *match in arrayOfAllMatches) {
            NSString *subText = [text substringWithRange:match.range];
            NSString *title = @"";
            if (match.resultType == NSTextCheckingTypePhoneNumber) {
                title = [NSString stringWithFormat:@"📞 %@", subText];
            } else {
                title = [NSString stringWithFormat:@"🔗 %@", subText];
            }
            [alert addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                if (match.resultType == NSTextCheckingTypePhoneNumber) {
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"telprompt://%@", subText]]];
                } else {
                    [XJWebViewController showPopoverFrom:cell.chatBubbleLabel withUrl:subText];
                }
            }]];
        }
        
        [alert addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"🔍 %@", text] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSString *url = [@"https://www.baidu.com/s?wd=" stringByAppendingString:text];
            [XJWebViewController showPopoverFrom:cell.chatBubbleLabel withUrl:url];
        }]];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            alert.popoverPresentationController.sourceView = cell.thumbWapper;
            [self presentViewController:alert animated:YES completion:nil];
        } else {
            [self presentViewController:alert animated:YES completion:nil];
        }
        return;
    }
    NSString *url = @"https://aip.baidubce.com/oauth/2.0/token?grant_type=client_credentials&client_id=oNZv8Mk3re6t7kMTXI597811&client_secret=xSxCzRSmOBEym07hCnHzDQpBHnhXnlDK";
    
    [[AFHTTPSessionManager manager]
     POST:url
     parameters:nil
     progress:nil
     success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
         
         NSString *access_token = responseObject[@"access_token"];
         if (!access_token.length) {
             return;
         }
         
         NSData *imgData = UIImageJPEGRepresentation(cell.thumbWapper.image, 1.0f);
         NSString *encodedImageStr = [imgData base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
         NSString *url = [@"https://aip.baidubce.com/rest/2.0/image-classify/v2/advanced_general?access_token=" stringByAppendingString:access_token];
         [[AFHTTPSessionManager manager]
          POST:url
          parameters:@{
                       @"image": encodedImageStr,
                       @"baike_num": @(1),
                       }
          progress:nil
          success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
              NSArray *result = responseObject[@"result"];
              if (result && result.count > 0) {
                  [CTImageClassifyTableViewController showPopoverFrom:cell.thumbWapper withInfo:result];
              }
          } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
              
          }];
     } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
         
     }];
}

- (void)deleteChatTableViewCell:(CTChatTableViewCell *)cell {
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    if (!indexPath) {
        return;
    }
    RLMRealm *realm = [RGRealmManager messageRealm];
    [realm transactionWithBlock:^{
        [realm deleteObject:self.messages[indexPath.row]];
    }];
}

#pragma mark - Data

- (void)insertChatData:(RGMessage *)chatData {
    void(^insertBlock)(void) = ^{
        chatData.roomId = self.roomId;
        if (arc4random()%2) {
            chatData.userId = self.mUserId;
        } else {
            chatData.userId = @"lin";
        }
        
        chatData.sendTime = [[NSDate date] timeIntervalSince1970] * 1000;
        RLMRealm *realm = [RGRealmManager messageRealm];
        [realm transactionWithBlock:^{
            [realm addObject:chatData];
        }];
    };
    if (![NSThread isMainThread]) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            insertBlock();
        });
    } else {
        insertBlock();
    }
}

- (void)__realmResults:(RLMResults<RGMessage *> *)results change:(RLMCollectionChange *)change error:(NSError *)error {
    if (!change) {
        return;
    }
    void(^update)(void) = ^{
        [self.tableView deleteRowsAtIndexPaths:[change deletionsInSection:0] withRowAnimation:UITableViewRowAnimationFade];
        [self.tableView insertRowsAtIndexPaths:[change insertionsInSection:0] withRowAnimation:UITableViewRowAnimationFade];
//        [self.tableView reloadRowsAtIndexPaths:[change modificationsInSection:0] withRowAnimation:UITableViewRowAnimationAutomatic];
    };
    
    NSInteger count = self.messages.count;
    BOOL isBottom = [self.tableView rg_isBottom];
    
    void(^scrollToBottom)(void) = ^{
        [self.tableView rg_scrollViewToBottom:YES];
    };
    
    void(^completion)(void) = ^ {
        [[change modificationsInSection:0] enumerateObjectsUsingBlock:^(NSIndexPath * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (self.messages.count != count) {
                *stop = YES;
                return;
            }
            [self _configCell:[self.tableView cellForRowAtIndexPath:obj] withMessage:self.messages[obj.row]];
        }];
        if (change.insertions.count) {
            if (isBottom) {
                scrollToBottom();
                return;
            }
            
            [change.insertions enumerateObjectsUsingBlock:^(NSNumber * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if ([self.messages[obj.integerValue].userId isEqualToString:self.mUserId]) {
                    *stop = YES;
                    scrollToBottom();
                }
            }];
        }
    };
    
    void(^doUpdate)(void) = ^{
        if (@available(iOS 11.0, *)) {
            [self.tableView performBatchUpdates:^{
                update();
            } completion:^(BOOL finished) {
                if (finished) {
                    completion();
                }
            }];
        } else {
            [self.tableView beginUpdates];
            update();
            [self.tableView endUpdates];
            [self.tableView reloadData];
//            [self.tableView layoutIfNeeded];
            completion();
            
        }
    };
    
    if (change.insertions.count || change.deletions.count) {
        if (change.insertions.count) {
            [UIView performWithoutAnimation:^{
                doUpdate();
            }];
        } else {
            doUpdate();
        }
    } else {
        completion();
    }
}

#pragma mark - Keyboard

- (void)__addKeyboardNotification {
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    [notificationCenter addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [notificationCenter addObserver:self selector:@selector(keyboardDidShow:) name:UIKeyboardDidShowNotification object:nil];
}

- (void)keyboardWillShow:(NSNotification *)notification {
    NSDictionary *info = [notification userInfo];
    CGRect kbFrame = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect selfFrame = [self.view convertRect:self.view.bounds toView:nil];
    
    _keyboardHeight = (selfFrame.origin.y + selfFrame.size.height) - kbFrame.origin.y;
    if (_keyboardHeight < 0) {
        _keyboardHeight = 0;
    } else {
        CGFloat markKeyBoardHeight = _keyboardHeight;
        CGFloat duration = [[info objectForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue];
        CGFloat delay = (kbFrame.size.height - _keyboardHeight) / kbFrame.size.height * duration;
        [UIView animateWithDuration:duration - delay delay:delay options:0 animations:^{
            [self __configInputViewLayout];
        } completion:^(BOOL finished) {
            if (self->_keyboardHeight != markKeyBoardHeight) {
                [UIView animateWithDuration:0.1 animations:^{
                    [self __configInputViewLayout];
                }];
            }
        }];
    }
}

- (void)keyboardDidShow:(NSNotification *)notification {
    NSDictionary *info = [notification userInfo];
    CGRect kbFrame = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect selfFrame = [self.view convertRect:self.view.bounds toView:nil];
    _keyboardHeight = (selfFrame.origin.y + selfFrame.size.height) - kbFrame.origin.y;
    if (_keyboardHeight < 0) {
        _keyboardHeight = 0;
    } else {
        [UIView animateWithDuration:0.1 animations:^{
            [self __configInputViewLayout];
        }];
    }
}

- (void)keyboardWillHide:(NSNotification *)notification {
    NSDictionary *info = [notification userInfo];
    CGRect kbFrame = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    
    if (_keyboardHeight != 0) {
        CGFloat duration = [[info objectForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue];
        duration = _keyboardHeight / kbFrame.size.height * duration;
        
        _keyboardHeight = 0;
        
        [UIView animateWithDuration:duration animations:^{
            [self __configInputViewLayout];
        } completion:^(BOOL finished) {
            
        }];
    }
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (void)dealloc {
    self.tableView.delegate = nil;
    self.tableView.dataSource = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
