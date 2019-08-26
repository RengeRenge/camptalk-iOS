//
//  CTImagePickerViewController.m
//  CampTalk
//
//  Created by renge on 2018/5/7.
//  Copyright © 2018年 yuru. All rights reserved.
//

#import "RGImagePickerViewController.h"
#import "RGImageAlbumListViewController.h"

#import <RGUIKit/RGUIKit.h>

#import <Photos/Photos.h>
#import <CoreLocation/CoreLocation.h>

#import "RGImageGallery.h"

#import "RGImagePickerConst.h"
#import "RGImagePickerCache.h"
#import "UIImageView+RGGif.h"

#import "RGImagePickerCell.h"

#import "CTUserConfig.h"

#import "Bluuur.h"

static PHImageRequestOptions *requestOptions = nil;

@interface RGImagePickerViewController () <UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UICollectionViewDataSourcePrefetching, PHPhotoLibraryChangeObserver, RGImagePickerCellDelegate, RGImageGalleryDelegate>

@property (nonatomic, assign) BOOL needScrollToBottom;
@property (nonatomic, assign) BOOL needRequestLoadStatus;
@property (nonatomic, assign) BOOL needResetView;
@property (nonatomic, assign) BOOL needSyncLoad;
@property (nonatomic, strong) PHFetchResult<PHAsset *> *assets;

@property (nonatomic, strong) PHCachingImageManager *imageManager;
@property (nonatomic, assign) CGRect previousPreheatRect;

@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, assign) CGSize itemSize;
@property (nonatomic, strong) UIView *backgroundView;

@property (nonatomic, assign) CGSize thumbSize;
@property (nonatomic, assign) CGSize lowThumbSize;

@property (nonatomic, strong) NSIndexPath *recordMaxIndexPath;

@property (nonatomic, strong) RGImageGallery *imageGallery;

@property (nonatomic, strong) UIToolbar *toolBar;
@property (nonatomic, strong) UIToolbar *toolBarSafeArea;

@property (nonatomic, strong) UIButton *toolBarLabel;
@property (nonatomic, strong) UIButton *toolBarLabelGallery;

@property (nonatomic, strong) NSMutableArray <UIBarButtonItem *> *toolBarItem;
@property (nonatomic, strong) NSMutableArray <UIBarButtonItem *> *toolBarItemGallery;

@end

@implementation RGImagePickerViewController

#pragma mark - life cycle

- (instancetype)init {
    if (self = [super init]) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
//            requestOptions = [[PHImageRequestOptions alloc] init];
//            requestOptions.resizeMode = PHImageRequestOptionsResizeModeFast;
//            requestOptions.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
//            requestOptions.synchronous = NO;
//            requestOptions.networkAccessAllowed = YES;
        });
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.needRequestLoadStatus = YES;
    self.view.tintColor = [UIColor blackColor];
    self.view.backgroundColor = [UIColor whiteColor];
    
    UIImage *image = [UIImage imageWithContentsOfFile:[CTUserConfig chatBackgroundImagePath]];
    UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
    imageView.contentMode = UIViewContentModeScaleAspectFill;
    imageView.clipsToBounds = YES;
    
    MLWBluuurView *bluuurView = [[MLWBluuurView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
    bluuurView.blurRadius = 3.5;
    bluuurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    bluuurView.frame = imageView.bounds;
    [imageView addSubview:bluuurView];
    self.backgroundView = imageView;
    [self.view addSubview:self.backgroundView];
    [self.view addSubview:self.collectionView];
    
    [self.collectionView registerClass:[RGImagePickerCell class] forCellWithReuseIdentifier:@"RGImagePickerCell"];
    self.collectionView.allowsMultipleSelection = self.cache.maxCount > 1;
    
    UIBarButtonItem *down = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(rg_dismiss)];
    self.navigationItem.rightBarButtonItem = down;
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
    
    _imageGallery = [[RGImageGallery alloc] initWithPlaceHolder:[UIImage rg_imageWithName:@"sad"] andDelegate:self];
    _imageGallery.pushFromView = YES;
    
    self.toolBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.toolBar.items = [self __toolBarItemForGallery:NO];
    [self.view addSubview:self.toolBar];
    
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.view
                                                          attribute:NSLayoutAttributeLeading
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self.toolBar
                                                          attribute:NSLayoutAttributeLeading
                                                         multiplier:1
                                                           constant:0]];

    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.view
                                                          attribute:NSLayoutAttributeTrailing
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self.toolBar
                                                          attribute:NSLayoutAttributeTrailing
                                                         multiplier:1
                                                           constant:0]];
    
    [self.toolBar updateConstraints];
    if (@available(iOS 11.0, *)) {;
        [self.toolBar.lastBaselineAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor].active = YES;
    } else {
        [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.toolBar
                                                              attribute:NSLayoutAttributeBottom
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:self.view
                                                              attribute:NSLayoutAttributeBottom
                                                             multiplier:1
                                                               constant:0]];
    }
    [self __configViewWithCurrentCollection:NO];
    [self setNeedScrollToBottom:YES];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    [self __doLayout];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self __doLayout];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self setNeedsStatusBarAppearanceUpdate];
    [self __scrollToBottomIfNeed];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.navigationController.presentingViewController setNeedsStatusBarAppearanceUpdate];
}

- (void)viewSafeAreaInsetsDidChange {
    [super viewSafeAreaInsetsDidChange];
    [self __configItemSize];
    [self __doReloadData];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if ([PHPhotoLibrary authorizationStatus] != PHAuthorizationStatusAuthorized) {
        return;
    }
    [self resetCachedAssets];
    [[PHPhotoLibrary sharedPhotoLibrary] unregisterChangeObserver:self];
}

#pragma mark - Getter

- (UICollectionView *)collectionView {
    if (!_collectionView) {
        UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
        layout.minimumInteritemSpacing = 0.f;
        layout.minimumLineSpacing = 2.f;
        _collectionView = [[UICollectionView alloc] initWithFrame:self.view.bounds collectionViewLayout:layout];
        _collectionView.backgroundColor = [UIColor clearColor];
        [self __configItemSize];
        _collectionView.delegate = self;
        _collectionView.dataSource = self;
        if (@available(iOS 10.0, *)) {
//            _collectionView.prefetchDataSource = self;
        }
        if (@available(iOS 11.0, *)) {
            _collectionView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAlways;
        }
    }
    return _collectionView;
}

- (UIToolbar *)toolBar {
    if (!_toolBar) {
        _toolBar = [[UIToolbar alloc] init];
    }
    return _toolBar;
}

- (void)setCollection:(PHAssetCollection *)collection {
    _collection = collection;
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"mediaType = %d", PHAssetMediaTypeImage];
    PHFetchOptions *option = [[PHFetchOptions alloc] init];
    option.predicate = predicate;
    
    _assets = [PHAsset fetchAssetsInAssetCollection:_collection options:option];
    
    [[PHPhotoLibrary sharedPhotoLibrary] registerChangeObserver:self];
    [self __configViewWithCurrentCollection:YES];
}

#pragma mark - Config

- (void)__doLayout {
    CGFloat recordHeight = self.collectionView.frame.size.height;
    [_collectionView rg_setAdditionalContentInset:UIEdgeInsetsMake(0, 0, self.toolBar.frame.size.height, 0) safeArea:self.rg_layoutSafeAreaInsets];
    _collectionView.scrollIndicatorInsets = _collectionView.contentInset;
    _collectionView.frame = self.view.bounds;
    _backgroundView.frame = self.view.bounds;
    
    [_collectionView rg_setAdditionalContentInset:UIEdgeInsetsMake(0, 0, self.toolBar.frame.size.height, 0) safeArea:self.rg_layoutSafeAreaInsets];
    _collectionView.scrollIndicatorInsets = _collectionView.contentInset;
    
    if (recordHeight != self.view.bounds.size.height) {
        [self __configItemSize];
        [self __doReloadData];
    }
    if (_needScrollToBottom) {
        [self __scrollViewToBottom];
    } else {
        if (recordHeight != self.collectionView.frame.size.height) {
            
            if (!_recordMaxIndexPath) {
                return;
            }
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(__recordMaxIndexPathIfNeed) object:nil];
            
            [self.collectionView scrollToItemAtIndexPath:self.recordMaxIndexPath atScrollPosition:UICollectionViewScrollPositionBottom animated:NO];
            dispatch_async(dispatch_get_main_queue(), ^{
                
                [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(__recordMaxIndexPathIfNeed) object:nil];
                
                [UIView performWithoutAnimation:^{
                    [self.collectionView scrollToItemAtIndexPath:self.recordMaxIndexPath atScrollPosition:UICollectionViewScrollPositionBottom animated:NO];
                }];
            });
        }
    }
}

- (void)__configViewWithCurrentCollection:(BOOL)scrollToBottom {
    if (!self.isViewLoaded) {
        return;
    }
    if (!_imageManager) {
        _imageManager = (PHCachingImageManager *)[PHCachingImageManager new];
        _imageManager.allowsCachingHighQualityImages = YES;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(__imagePickerCachePickPhotosHasChanged:) name:RGImagePickerCachePickPhotosHasChanged object:nil];
    }
    [self resetCachedAssets];
    [self __configTitle];
    if (scrollToBottom) {
        [self setNeedScrollToBottom:YES];
        [self __doReloadData];
        [self __scrollToBottomIfNeed];
    }
}

- (void)__configTitle {
    if (_collection) {
        NSString *title = [NSString stringWithFormat:@"%@ (%lu/%lu)", _collection.localizedTitle, (unsigned long)self.cache.pickPhotos.count, (unsigned long)self.cache.maxCount];
        self.navigationItem.title = title;
    }
}

- (void)__scrollToBottomIfNeed {
    if (_needScrollToBottom && _assets) {
        if (_assets.count <= 0) {
            _needScrollToBottom = NO;
            return;
        }
        
        self.collectionView.alpha = 0;
        [self.collectionView setNeedsLayout];
        [self.collectionView layoutIfNeeded];
        [self __scrollViewToBottom];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_needScrollToBottom = NO;
            
            [UIView animateWithDuration:0.5 animations:^{
                self.collectionView.alpha = 1;
                self.needResetView = NO;
                self.needSyncLoad = YES;
                self.needRequestLoadStatus = YES;
                [self __doReloadData];
            } completion:^(BOOL finished) {
                self.needResetView = YES;
                self.needSyncLoad = NO;
            }];
        });
    }
}

- (void)__scrollViewToBottom {
//    BOOL record = self.needRequestLoadStatus;
    [self.collectionView rg_scrollViewToBottom:NO];
//    self.needRequestLoadStatus = record;
}

- (void)__configItemSize {    
    CGFloat space = 2.f;
    CGRect bounds = self.rg_safeAreaBounds;
    CGFloat contaiWidth = MIN(bounds.size.width, bounds.size.height);
    NSInteger count = 4 ;
    CGFloat width = contaiWidth - (count > 0 ? (count - 1) * space : 0);
    width = 1.f * width / count;
    
//    if (width < 80) {
//        contaiWidth = _collectionView.bounds.size.width;
//        count = contaiWidth / (80 + space);
//        width = contaiWidth - (count > 0 ? (count - 1) * space : 0);
//        width = 1.f * width / count;
//    }
    _itemSize = CGSizeMake(width, width);
    _lowThumbSize = CGSizeMake(width, width);
    width = floor(width * [UIScreen mainScreen].scale);
    _thumbSize = CGSizeMake(width, width);
}

- (void)__down {
    [self.cache callBack:self];
}

- (void)__doReloadData {
//    [CATransaction begin];
//    [CATransaction setDisableActions:YES];
    [self.collectionView reloadData];
//    [CATransaction commit];
}

- (void)__showPickerPhotos:(UIButton *)sender {
    [self.cache showPickerPhotosWithParentViewController:self];
}

#pragma mark - UICollectionViewDelegate

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return _assets.count;
}

- (void)collectionView:(UICollectionView *)collectionView prefetchItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths {
//    NSMutableArray *array = [NSMutableArray arrayWithCapacity:indexPaths.count];
//    [indexPaths enumerateObjectsUsingBlock:^(NSIndexPath * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
//        [array addObject:self.assets[obj.row]];
//    }];
//    [self.imageManager startCachingImagesForAssets:array
//                                        targetSize:self.lowThumbSize
//                                       contentMode:PHImageContentModeAspectFill
//                                           options:requestOptions];
}

- (void)collectionView:(UICollectionView *)collectionView cancelPrefetchingForItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths {
//    NSMutableArray *array = [NSMutableArray arrayWithCapacity:indexPaths.count];
//    [indexPaths enumerateObjectsUsingBlock:^(NSIndexPath * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
//        [array addObject:self.assets[obj.row]];
//    }];
//    [self.imageManager stopCachingImagesForAssets:array
//                                       targetSize:self.lowThumbSize
//                                      contentMode:PHImageContentModeAspectFill
//                                          options:requestOptions];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    self.needRequestLoadStatus = NO;
    [self updateCachedAssets];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    [self __loadStatusWtihResetView:NO];
}

- (void)scrollViewDidScrollToTop:(UIScrollView *)scrollView {
    [self __loadStatusWtihResetView:NO];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    self.needRequestLoadStatus = NO;
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (!decelerate) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(__loadStatusWtihResetView:) object:@(NO)];
        [self performSelector:@selector(__loadStatusWtihResetView:) withObject:@(NO) afterDelay:0.3];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [self __loadStatusWtihResetView:NO];
}

- (void)__loadStatusWtihResetView:(BOOL)resetView {
    self.needRequestLoadStatus = YES;
    self.needResetView = resetView;
    NSArray<__kindof UICollectionViewCell *> *visibleCells = self.collectionView.visibleCells;
    NSArray<NSIndexPath *> *indexPathsForVisibleRows = self.collectionView.indexPathsForVisibleItems;
    [visibleCells enumerateObjectsUsingBlock:^(RGImagePickerCell * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        obj.asset = nil;
        [self __configCell:obj withIndexPath:indexPathsForVisibleRows[idx]];
    }];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    RGImagePickerCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"RGImagePickerCell" forIndexPath:indexPath];
    cell.delegate = self;
    if (indexPath.row >= _assets.count) {
        return cell;
    }
    if (!_needScrollToBottom) {
        [self __configCell:cell withIndexPath:indexPath];
    }
    return cell;
}

- (void)__configCell:(RGImagePickerCell *)cell withIndexPath:(NSIndexPath *)indexPath {
    
    PHAsset *asset = _assets[indexPath.row];
    CGSize targetSize = _needRequestLoadStatus ? _thumbSize : _lowThumbSize;
    [cell setAsset:asset photoManager:_imageManager options:requestOptions targetSize:targetSize cache:_cache sync:YES loadStatus:_needRequestLoadStatus resetView:_needResetView];
    
    if ([self.cache contain:asset]) {
        [self.collectionView selectItemAtIndexPath:indexPath animated:NO scrollPosition:UICollectionViewScrollPositionNone];
        [cell setSelected:YES];
    } else {
        [self.collectionView deselectItemAtIndexPath:indexPath animated:NO];
        [cell setSelected:NO];
    }
    
    if (_imageGallery.page == indexPath.row) {
        if (_imageGallery.pushState > RGImageGalleryPushStateNoPush) {
            cell.contentView.alpha = 0;
        } else {
            cell.contentView.alpha = 1;
        }
    } else {
        cell.contentView.alpha = 1;
    }
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return _itemSize;
}

- (void)collectionView:(UICollectionView *)collectionView willDisplayCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
    if (!_recordMaxIndexPath) {
        [self __recordMaxIndexPathIfNeed];
    } else {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(__recordMaxIndexPathIfNeed) object:nil];
        [self performSelector:@selector(__recordMaxIndexPathIfNeed) withObject:nil afterDelay:0.3f inModes:@[NSRunLoopCommonModes]];
    }
}

- (BOOL)collectionView:(UICollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    RGImagePickerCell *cell = (RGImagePickerCell *)[collectionView cellForItemAtIndexPath:indexPath];
    if (cell.lastTouchForce == 0) {
        PHAsset *photo = _assets[indexPath.row];
        if (![self.cache loadStatusCacheForAsset:photo]) {
            [RGImagePickerCell loadOriginalWithAsset:photo cache:self.cache updateCell:cell collectionView:collectionView progressHandler:nil completion:nil];
            return NO;
        }
        [_imageGallery showImageGalleryAtIndex:indexPath.row fatherViewController:self];
        return NO;
    }
    return NO;
}

- (BOOL)collectionView:(UICollectionView *)collectionView shouldDeselectItemAtIndexPath:(NSIndexPath *)indexPath {
    return [self collectionView:collectionView shouldSelectItemAtIndexPath:indexPath];
}

- (void)__recordMaxIndexPathIfNeed {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(__recordMaxIndexPathIfNeed) object:nil];
    
    [self.collectionView.indexPathsForVisibleItems enumerateObjectsUsingBlock:^(NSIndexPath * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (idx == 0) {
            self.recordMaxIndexPath = obj;
        } else {
            if (self.recordMaxIndexPath.row < obj.row) {
                self.recordMaxIndexPath = obj;
            }
        }
    }];
    _recordMaxIndexPath = _recordMaxIndexPath.copy;
}

- (void)__selectItemWithCurrentGalleryPage {
    [self __selectItemAtIndex:_imageGallery.page orCell:nil];
}

- (void)__selectItemAtIndex:(NSInteger)index orCell:(RGImagePickerCell *_Nullable)cell {
    PHAsset *asset = self->_assets[index];
    
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
    if (!cell) {
        cell = (RGImagePickerCell *)[self.collectionView cellForItemAtIndexPath:indexPath];
    }
    
    BOOL isFull = self.cache.isFull;
    
    if (indexPath) {
        if ([self.cache contain:asset]) {
            [self.cache removePhotos:@[asset]];
            [cell setSelected:NO animated:YES];
            [self.collectionView deselectItemAtIndexPath:indexPath animated:YES];
        } else {
            [self.cache requestLoadStatusWithAsset:asset onlyCache:NO cacheSync:NO result:^(BOOL needLoad) {
                if (needLoad) {
                    [RGImagePickerCell loadOriginalWithAsset:asset cache:self.cache updateCell:cell collectionView:self.collectionView progressHandler:nil completion:nil];
                } else {
                    if (self.cache.maxCount <= 1) {
                        [self.cache setPhotos:@[asset]];
                        [cell setSelected:YES animated:YES];
                        [self.collectionView selectItemAtIndexPath:indexPath animated:YES scrollPosition:UICollectionViewScrollPositionNone];
                    } else {
                        if (self.cache.pickPhotos.count < self.cache.maxCount) {
                            [self.cache addPhotos:@[asset]];
                            [cell setSelected:YES animated:YES];
                            [self.collectionView selectItemAtIndexPath:indexPath animated:YES scrollPosition:UICollectionViewScrollPositionNone];
                        }
                    }
                    [self __configViewWhenCacheChanged];
                }
            }];
        }
    }
    if (self.cache.isFull != isFull) {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        NSMutableArray *visiable = [NSMutableArray arrayWithArray:self.collectionView.indexPathsForVisibleItems];
        [visiable removeObject:indexPath];
        [self.collectionView reloadItemsAtIndexPaths:visiable];
        [CATransaction commit];
    }
    [self __configViewWhenCacheChanged];
}

- (void)__configViewWhenCacheChanged {
    self.toolBar.items = [self __toolBarItemForGallery:NO];
    [_imageGallery reloadToolBarItem];
    [self __configTitle];
}

- (NSMutableArray <UIBarButtonItem *> *)__createToolBarItmes {
    
    NSMutableArray *array = [NSMutableArray array];
    
    UIBarButtonItem *countItem = [[UIBarButtonItem alloc] initWithTitle:nil style:UIBarButtonItemStylePlain target:nil action:nil];
    
    UIButton *button = [[UIButton alloc] init];
    [button setBackgroundImage:[UIImage rg_templateImageWithSize:CGSizeMake(1, 1)] forState:UIControlStateNormal];
    button.layer.cornerRadius = 10;
    button.titleLabel.font = [UIFont systemFontOfSize:16];
    button.clipsToBounds = YES;
    countItem.customView = button;
    [button addTarget:self action:@selector(__showPickerPhotos:) forControlEvents:UIControlEventTouchUpInside];
    [array addObject:countItem];
    
    [array addObject:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil]];
    
    UIBarButtonItem *addItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(__selectItemWithCurrentGalleryPage)];
    addItem.tag = 1;
    [array addObject:addItem];
    
    [array addObject:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil]];
    UIBarButtonItem *down = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"img_send2"] style:UIBarButtonItemStyleDone target:self action:@selector(__down)];
    [array addObject:down];
    
    return array;
}

- (NSArray <UIBarButtonItem *> *)__toolBarItemForGallery:(BOOL)forGallery {
    
    if (forGallery && !_toolBarItemGallery) {
        _toolBarItemGallery = [self __createToolBarItmes];
    }
    
    if (!forGallery && !_toolBarItem) {
        _toolBarItem = [self __createToolBarItmes];
    }
    
    NSMutableArray <UIBarButtonItem *> *array = forGallery ? _toolBarItemGallery : _toolBarItem;
    
    // 0: countItem
    UIBarButtonItem *countItem = array[0];
    UIButton *label = countItem.customView;
    NSString *text = @(self.cache.pickPhotos.count).stringValue;
    
    if (![text isEqualToString:[label titleForState:UIControlStateNormal]]) {
        [label setTitle:text forState:UIControlStateNormal];
        [label sizeToFit];
        CGFloat width = MAX(label.frame.size.width + 8, 26);
        label.frame = CGRectMake(0, 0, width, 26);
    }
    countItem.customView = label;
    
    
    // 2: center
    UIBarButtonItem *centerItem = array[2];
    if (forGallery) {
        NSInteger page = _imageGallery.page;
        PHAsset *asset = forGallery ? _assets[page] : nil;
        if ([self.cache contain:asset]) {
            if (centerItem.tag != 2) {
                centerItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(__selectItemWithCurrentGalleryPage)];
                centerItem.tag = 2;
                [array replaceObjectAtIndex:2 withObject:centerItem];
            }
        } else {
            if ([self.cache loadStatusCacheForAsset:asset]) {
                if (centerItem.tag != 1) {
                    centerItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(__selectItemWithCurrentGalleryPage)];
                    centerItem.enabled = !self.cache.isFull;
                    centerItem.tag = 1;
                    [array replaceObjectAtIndex:2 withObject:centerItem];
                }
            } else {
                if (!centerItem.customView) {
                    UIActivityIndicatorView *loading = [UIActivityIndicatorView new];
                    loading.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
                    [loading sizeToFit];
                    [loading startAnimating];
                    centerItem.customView = loading;
                    centerItem.tag = 3;
                }
            }
        }
    } else {
        centerItem.enabled = NO;
        centerItem.tintColor = [UIColor clearColor];
    }
    
    // downItem
    UIBarButtonItem *downItem = array[4];
    downItem.enabled = self.cache.pickPhotos.count;
    return array;
}

#pragma mark - PHPhotoLibraryChangeObserver

- (void)photoLibraryDidChange:(PHChange *)changeInstance {
    // https://developer.apple.com/documentation/photokit/phphotolibrarychangeobserver?language=objc
    // Photos may call this method on a background queue;
    // switch to the main queue to update the UI.
    dispatch_async(dispatch_get_main_queue(), ^{
        // Check for changes to the displayed album itself
        // (its existence and metadata, not its member assets).
        
        PHObjectChangeDetails *albumChanges = [changeInstance changeDetailsForObject:self.collection];
        if (albumChanges) {
            // Fetch the new album and update the UI accordingly.
            self->_collection = [albumChanges objectAfterChanges];
            [self __configTitle];
        }
        
        BOOL isFull = self.cache.isFull;
        
        PHFetchResultChangeDetails *collectionChanges = [changeInstance changeDetailsForFetchResult:self.assets];
        if (collectionChanges) {
            
            self.assets = collectionChanges.fetchResultAfterChanges;
            
            if (collectionChanges.hasIncrementalChanges)  {
                
                UICollectionView *collectionView = self.collectionView;
                NSArray *removedPaths;
                NSArray *insertedPaths;
                NSArray *changedPaths;
                
                NSIndexSet *removed = [collectionChanges removedIndexes];
                removedPaths = [self __indexPathsFromIndexSet:removed];
                
                NSIndexSet *inserted = [collectionChanges insertedIndexes];
                insertedPaths = [self __indexPathsFromIndexSet:inserted];
                
                NSIndexSet *changed = [collectionChanges changedIndexes];
                changedPaths = [self __indexPathsFromIndexSet:changed];
                
                BOOL shouldReload = NO;
                
                if (changedPaths != nil && removedPaths != nil) {
                    for (NSIndexPath *changedPath in changedPaths) {
                        if ([removedPaths containsObject:changedPath]) {
                            shouldReload = YES;
                            break;
                        }
                    }
                }
                
                if (removedPaths.lastObject && ((NSIndexPath *)removedPaths.lastObject).item >= self.assets.count) {
                    shouldReload = YES;
                }
                
                [collectionView performBatchUpdates:^{
                    if (removed.count) {
                        [collectionView deleteItemsAtIndexPaths:removedPaths];
                        [self.imageGallery deletePages:removed];
                    }
                    
                    if (inserted.count) {
                        [collectionView insertItemsAtIndexPaths:insertedPaths];
                        [self.imageGallery insertPages:inserted];
                    }
                    
                    if (changed.count) {
                        if (!shouldReload) {
                            [collectionView reloadItemsAtIndexPaths:changedPaths];
                        }
                        [self.imageGallery updatePages:changed];
                    }
                    
                    if ([collectionChanges hasMoves]) {
                        [collectionChanges enumerateMovesWithBlock:^(NSUInteger fromIndex, NSUInteger toIndex) {
                            NSIndexPath *fromIndexPath = [NSIndexPath indexPathForItem:fromIndex inSection:0];
                            NSIndexPath *toIndexPath = [NSIndexPath indexPathForItem:toIndex inSection:0];
                            [collectionView moveItemAtIndexPath:fromIndexPath toIndexPath:toIndexPath];
                        }];
                    }
                    
                } completion:^(BOOL finished) {
                    if (shouldReload || self.cache.isFull != isFull) {
                        [self __doReloadData];
                    }
                }];
            } else {
                [self __doReloadData];
            }
        }
    });
}

- (NSArray<NSIndexPath *> *)__indexPathsFromIndexSet:(NSIndexSet *)indexSet {
    if (!indexSet) {
        return nil;
    }
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:indexSet.count];
    [indexSet enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
        [array addObject:[NSIndexPath indexPathForItem:idx inSection:0]];
    }];
    return array;
}

#pragma mark - RGImagePickerCellDelegate

- (void)imagePickerCell:(RGImagePickerCell *)cell touchForce:(CGFloat)force maximumPossibleForce:(CGFloat)maximumPossibleForce {
    if (maximumPossibleForce) {
        maximumPossibleForce /= 2.5f;
        self.view.alpha = MAX(0, (maximumPossibleForce - force) / maximumPossibleForce);
    }
}

- (void)didCheckForImagePickerCell:(RGImagePickerCell *)cell {
    NSIndexPath *indexPath = [self.collectionView indexPathForCell:cell];
    [self __selectItemAtIndex:indexPath.row orCell:cell];
}

#pragma mark - ImageGalleryDelegate

- (NSInteger)numOfImagesForImageGallery:(RGImageGallery *)imageGallery {
    return _assets.count;
}

- (UIColor *)titleColorForImageGallery:(RGImageGallery *)imageGallery {
    return self.navigationController.navigationBar.tintColor;
}

- (NSString *)titleForImageGallery:(RGImageGallery *)imageGallery AtIndex:(NSInteger)index {
    if (index >= 0) {
        PHAsset *assert = _assets[index];
        NSString *title = [[assert creationDate] rg_stringWithDateFormat:@"yyyy-MM-dd HH:mm\n"];
        return [title stringByAppendingString:@(index+1).stringValue];
    } else {
        return @"";
    }
}

- (UIImage *)imageGallery:(RGImageGallery *)imageGallery thumbnailAtIndex:(NSInteger)index targetSize:(CGSize)targetSize {
    PHAsset *asset = _assets[index];
    return [self.cache imageForAsset:asset onlyCache:NO syncLoad:YES allowNet:NO targetSize:self.thumbSize completion:nil];
}

- (UIImage *)imageGallery:(RGImageGallery *)imageGallery
             imageAtIndex:(NSInteger)index
               targetSize:(CGSize)targetSize
              updateImage:(void (^ _Nullable)(UIImage * _Nonnull))updateImage {
    PHAsset *asset = _assets[index];
    if (updateImage) {
        [RGImagePickerCell loadOriginalWithAsset:asset cache:self.cache updateCell:nil collectionView:self.collectionView progressHandler:^(double progress) {
            
        } completion:^(NSData * _Nullable imageData, NSError * _Nullable error) {
            UIImage *image = [UIImage rg_imageOrGifWithData:imageData];
            if (image) {
                updateImage(image);
            }
            if ([self->_assets[imageGallery.page].localIdentifier isEqualToString:asset.localIdentifier]) {
                [imageGallery reloadToolBarItem];
            }
        }];
    }
    return nil;
}

- (UIView *)imageGallery:(RGImageGallery *)imageGallery thumbViewForTransitionAtIndex:(NSInteger)index {
    if (index >= 0) {
        if (imageGallery.pushState == RGImageGalleryPushStatePushed) {
            [self __scrollToIndex:index];
        }
        UICollectionViewCell *cell = [self.collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
        return cell;
    } else  {
        return nil;
    }
}

- (BOOL)imageGallery:(RGImageGallery *)imageGallery toolBarItemsShouldDisplayForIndex:(NSInteger)index {
    return YES;
}

- (NSArray<UIBarButtonItem *> *)imageGallery:(RGImageGallery *)imageGallery toolBarItemsForIndex:(NSInteger)index {
    return [self __toolBarItemForGallery:YES];
}

- (RGIMGalleryTransitionCompletion)imageGallery:(RGImageGallery *)imageGallery willPopToParentViewController:(UIViewController *)viewController {
    
    NSUInteger page = imageGallery.page;
    [self __scrollToIndex:page];
    
    UICollectionViewCell *cell = [self.collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForRow:page inSection:0]];
    cell.contentView.alpha = 0;
    
    RGIMGalleryTransitionCompletion com = ^(BOOL flag) {
        [self __loadStatusWtihResetView:NO];
    };
    
    return com;
}

- (RGIMGalleryTransitionCompletion)imageGallery:(RGImageGallery *)imageGallery willBePushedWithParentViewController:(UIViewController *)viewController {
    
    UICollectionViewCell *cell = [self.collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForRow:imageGallery.page inSection:0]];
    cell.contentView.alpha = 0;
    
    RGIMGalleryTransitionCompletion com = ^(BOOL flag) {
        cell.contentView.alpha = 1;
    };
    return com;
}

- (void)__scrollToIndex:(NSUInteger)index {
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    NSIndexPath *needShowIndexPath = [NSIndexPath indexPathForRow:index inSection:0];
    if (![self.collectionView.indexPathsForVisibleItems containsObject:needShowIndexPath]) {
        [self.collectionView scrollToItemAtIndexPath:needShowIndexPath atScrollPosition:UICollectionViewScrollPositionCenteredVertically animated:NO];
    }
    [self.collectionView setNeedsLayout];
    [self.collectionView layoutIfNeeded];
    [CATransaction commit];
}

#pragma mark - RGImagePickerCachePickPhotosHasChanged

- (void)__imagePickerCachePickPhotosHasChanged:(NSNotification *)noti {
    if (self.navigationController.topViewController != self) {
        [self __configViewWhenCacheChanged];
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(__loadStatusWtihResetView:) object:@(NO)];
        [self performSelector:@selector(__loadStatusWtihResetView:) withObject:@(NO) afterDelay:0.6];
    }
}

#pragma mark - Asset Caching

- (void)resetCachedAssets {
    [self.imageManager stopCachingImagesForAllAssets];
    self.previousPreheatRect = CGRectZero;
}

- (void)updateCachedAssets {
    BOOL isViewVisible = [self isViewLoaded] && [[self view] window] != nil;
    if (!isViewVisible) { return; }
    
    // 预加载区域是可显示区域的两倍
    CGRect preheatRect = self.collectionView.bounds;
    preheatRect = CGRectInset(preheatRect, 0.0f, -0.5f * CGRectGetHeight(preheatRect));
    
    // 比较是否显示的区域与之前预加载的区域有不同
    CGFloat delta = ABS(CGRectGetMidY(preheatRect) - CGRectGetMidY(self.previousPreheatRect));
    if (delta > CGRectGetHeight(self.collectionView.bounds) / 3.0f) {
        
        // 区分资源分别操作
        NSMutableArray *addedIndexPaths = [NSMutableArray array];
        NSMutableArray *removedIndexPaths = [NSMutableArray array];
        
        [self computeDifferenceBetweenRect:self.previousPreheatRect andRect:preheatRect removedHandler:^(CGRect removedRect) {
            NSArray *indexPaths = [self indexPathsForElementsInCollectionView:self.collectionView rect:removedRect];
            [removedIndexPaths addObjectsFromArray:indexPaths];
        } addedHandler:^(CGRect addedRect) {
            NSArray *indexPaths = [self indexPathsForElementsInCollectionView:self.collectionView rect:addedRect];
            [addedIndexPaths addObjectsFromArray:indexPaths];
        }];
        
        NSArray *assetsToStartCaching = [self assetsAtIndexPaths:addedIndexPaths];
        NSArray *assetsToStopCaching = [self assetsAtIndexPaths:removedIndexPaths];
        
        // 更新缓存
        [self.imageManager startCachingImagesForAssets:assetsToStartCaching
                                            targetSize:self.lowThumbSize
                                           contentMode:PHImageContentModeAspectFill
                                               options:requestOptions];
        [self.imageManager stopCachingImagesForAssets:assetsToStopCaching
                                           targetSize:self.lowThumbSize
                                          contentMode:PHImageContentModeAspectFill
                                              options:requestOptions];
        
        // 存储预加载矩形已供比较
        self.previousPreheatRect = preheatRect;
    }
}

- (void)computeDifferenceBetweenRect:(CGRect)oldRect andRect:(CGRect)newRect removedHandler:(void (^)(CGRect removedRect))removedHandler addedHandler:(void (^)(CGRect addedRect))addedHandler {
    if (CGRectIntersectsRect(newRect, oldRect)) {
        CGFloat oldMaxY = CGRectGetMaxY(oldRect);
        CGFloat oldMinY = CGRectGetMinY(oldRect);
        CGFloat newMaxY = CGRectGetMaxY(newRect);
        CGFloat newMinY = CGRectGetMinY(newRect);
        
        if (newMaxY > oldMaxY) {
            CGRect rectToAdd = CGRectMake(newRect.origin.x, oldMaxY, newRect.size.width, (newMaxY - oldMaxY));
            addedHandler(rectToAdd);
        }
        
        if (oldMinY > newMinY) {
            CGRect rectToAdd = CGRectMake(newRect.origin.x, newMinY, newRect.size.width, (oldMinY - newMinY));
            addedHandler(rectToAdd);
        }
        
        if (newMaxY < oldMaxY) {
            CGRect rectToRemove = CGRectMake(newRect.origin.x, newMaxY, newRect.size.width, (oldMaxY - newMaxY));
            removedHandler(rectToRemove);
        }
        
        if (oldMinY < newMinY) {
            CGRect rectToRemove = CGRectMake(newRect.origin.x, oldMinY, newRect.size.width, (newMinY - oldMinY));
            removedHandler(rectToRemove);
        }
    } else {
        addedHandler(newRect);
        removedHandler(oldRect);
    }
}

- (NSArray *)assetsAtIndexPaths:(NSArray *)indexPaths {
    if (indexPaths.count == 0) { return nil; }
    
    NSMutableArray *assets = [NSMutableArray arrayWithCapacity:indexPaths.count];
    for (NSIndexPath *indexPath in indexPaths) {
        PHAsset *asset = self.assets[indexPath.item];
        [assets addObject:asset];
    }
    
    return assets;
}

- (NSArray *)indexPathsFromIndexes:(NSIndexSet *)indexSet section:(NSUInteger)section {
    NSMutableArray *indexPaths = [NSMutableArray arrayWithCapacity:indexSet.count];
    [indexSet enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        [indexPaths addObject:[NSIndexPath indexPathForItem:idx inSection:section]];
    }];
    return indexPaths;
}

- (NSArray *)indexPathsForElementsInCollectionView:(UICollectionView *)collection rect:(CGRect)rect {
    NSArray *allLayoutAttributes = [collection.collectionViewLayout layoutAttributesForElementsInRect:rect];
    if (allLayoutAttributes.count == 0) { return nil; }
    NSMutableArray *indexPaths = [NSMutableArray arrayWithCapacity:allLayoutAttributes.count];
    for (UICollectionViewLayoutAttributes *layoutAttributes in allLayoutAttributes) {
        NSIndexPath *indexPath = layoutAttributes.indexPath;
        [indexPaths addObject:indexPath];
    }
    return indexPaths;
}

@end
