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
#import "RGImagePicker.h"
#import "UIImageView+RGGif.h"

#import "RGImagePickerCell.h"

#import "CTUserConfig.h"

#import "Bluuur.h"

@interface RGImagePickerViewController () <UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, PHPhotoLibraryChangeObserver, UICollectionViewDataSourcePrefetching, RGImagePickerCellDelegate, RGImageGalleryDelegate>

@property (nonatomic, assign) BOOL needScrollToBottom;
@property (nonatomic, strong) PHFetchResult<PHAsset *> *assets;

@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, assign) CGSize itemSize;
@property (nonatomic, assign) CGSize thumbSize;

@property (nonatomic, strong) NSIndexPath *recordMaxIndexPath;

@property (nonatomic, strong) RGImageGallery *imageGallery;

@property (nonatomic, strong) UIToolbar *toolBar;

@property (nonatomic, strong) UIButton *toolBarLabel;
@property (nonatomic, strong) UIButton *toolBarLabelGallery;

@property (nonatomic, strong) NSMutableArray <UIBarButtonItem *> *toolBarItem;
@property (nonatomic, strong) NSMutableArray <UIBarButtonItem *> *toolBarItemGallery;

@end

@implementation RGImagePickerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
//    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(__phAssetLoadStatusHasChanged:) name:RGPHAssetLoadStatusHasChanged object:nil];
    
    [self.view addSubview:self.collectionView];
    self.view.tintColor = [UIColor blackColor];
    
    UIImage *image = [UIImage imageWithContentsOfFile:[CTUserConfig chatBackgroundImagePath]];
    UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
    imageView.contentMode = UIViewContentModeScaleAspectFill;
    imageView.clipsToBounds = YES;
    
    MLWBluuurView *backgroundView = [[MLWBluuurView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
    backgroundView.blurRadius = 3.5;
    backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    backgroundView.frame = imageView.bounds;
    [imageView addSubview:backgroundView];
    self.collectionView.backgroundView = imageView;
    
    [self.collectionView registerClass:[RGImagePickerCell class] forCellWithReuseIdentifier:@"RGImagePickerCell"];
    self.collectionView.allowsMultipleSelection = self.cache.maxCount > 1;
    
    UIBarButtonItem *down = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(rg_dismiss)];
    self.navigationItem.rightBarButtonItem = down;
    [self __configViewWithCollection:_collection];
    
    _imageGallery = [[RGImageGallery alloc] initWithPlaceHolder:[UIImage rg_imageWithName:@"sad"] andDelegate:self];
    
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
}

- (UICollectionView *)collectionView {
    if (!_collectionView) {
        UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
        layout.minimumInteritemSpacing = 0.f;
        layout.minimumLineSpacing = 2.f;
        _collectionView = [[UICollectionView alloc] initWithFrame:self.view.bounds collectionViewLayout:layout];
        [self __configItemSize];
        _collectionView.delegate = self;
        _collectionView.dataSource = self;
        if (@available(iOS 10.0, *)) {
            _collectionView.prefetchDataSource = self;
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
    
    if (self.isViewLoaded) {
        [self __configViewWithCollection:_collection];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[PHPhotoLibrary sharedPhotoLibrary] unregisterChangeObserver:self];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    _collectionView.contentInset = UIEdgeInsetsMake(0, 0, self.toolBar.frame.size.height, 0);
    _collectionView.scrollIndicatorInsets = _collectionView.contentInset;
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    
    _collectionView.contentInset = UIEdgeInsetsMake(0, 0, self.toolBar.frame.size.height, 0);
    _collectionView.scrollIndicatorInsets = _collectionView.contentInset;
    
    CGFloat recordHeight = self.collectionView.frame.size.height;
    _collectionView.frame = self.view.bounds;
    
    if (recordHeight != self.view.bounds.size.height) {
        [self __configItemSize];
        [self __doReloadData];
    }
    
    if (!_needScrollToBottom) {
        
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

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self __scrollToBottomIfNeed];
}

- (void)__configViewWithCollection:(PHAssetCollection *)collection {
    [self __doReloadData];
    [self __configTitle];
    [self setNeedScrollToBottom:YES];
    [self __scrollToBottomIfNeed];
    [self.view setNeedsLayout];
}

- (void)__configTitle {
    if (_collection) {
        NSString *title = [NSString stringWithFormat:@"%@ (%lu/%lu)", _collection.localizedTitle, (unsigned long)self.cache.pickPhotos.count, (unsigned long)self.cache.maxCount];
        self.navigationItem.title = title;
        self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:_collection.localizedTitle style:UIBarButtonItemStylePlain target:nil action:nil];
    }
}

- (void)__scrollToBottomIfNeed {
    if (_needScrollToBottom && _assets) {
        [self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForRow:self.assets.count - 1 inSection:0] atScrollPosition:UICollectionViewScrollPositionTop animated:NO];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForRow:self.assets.count - 1 inSection:0] atScrollPosition:UICollectionViewScrollPositionTop animated:NO];
        });
        _needScrollToBottom = NO;
    }
}

- (void)__configItemSize {
    CGFloat space = 2.f;
    NSInteger count = _collectionView.bounds.size.width / (80 + space);
    CGFloat width = _collectionView.bounds.size.width - (count > 0 ? (count - 1) * space : 0);
    width = 1.f * width / count ;
    _itemSize = CGSizeMake(width, width);
    _thumbSize = CGSizeMake(width * [UIScreen mainScreen].scale, width * [UIScreen mainScreen].scale);
}

- (void)__down {
    [self.cache callBack:self];
}

- (void)__phAssetLoadStatusHasChanged:(NSNotification *)noti {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(__doReloadData) object:nil];
    [self performSelector:@selector(__doReloadData) withObject:nil afterDelay:0.3];
}

- (void)__doReloadData {
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [self.collectionView reloadData];
    [CATransaction commit];
}

#pragma mark - UICollectionViewDelegate

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return _assets.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    RGImagePickerCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"RGImagePickerCell" forIndexPath:indexPath];
    cell.delegate = self;
    PHAsset *photo = _assets[indexPath.row];
    [cell setAsset:photo targetSize:_thumbSize cache:_cache];
    
    if ([self.cache contain:photo]) {
        [collectionView selectItemAtIndexPath:indexPath animated:NO scrollPosition:UICollectionViewScrollPositionNone];
        [cell setSelected:YES];
    } else {
        [collectionView deselectItemAtIndexPath:indexPath animated:NO];
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
    return cell;
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

- (BOOL)collectionView:(UICollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    RGImagePickerCell *cell = (RGImagePickerCell *)[collectionView cellForItemAtIndexPath:indexPath];
    if (cell.lastTouchForce == 0) {
        PHAsset *photo = _assets[indexPath.row];
        if (!photo.rgIsLoaded) {
            [RGImagePickerCell loadOriginalWithAsset:photo updateCell:cell collectionView:collectionView progressHandler:nil completion:nil];
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

- (void)__selectItemWithCurrentGalleryPage {
    [self __selectItemAtIndex:_imageGallery.page orCell:nil];
    [_imageGallery configToolBarItem];
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
            [RGImagePickerCell needLoadWithAsset:asset result:^(BOOL needLoad) {
                if (needLoad) {
                    [RGImagePickerCell loadOriginalWithAsset:asset updateCell:cell collectionView:self.collectionView progressHandler:nil completion:nil];
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
        PHAsset *asset = forGallery ? _assets[_imageGallery.page] : nil;
        if ([self.cache contain:asset]) {
            if (centerItem.tag != 2) {
                centerItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(__selectItemWithCurrentGalleryPage)];
                centerItem.tag = 2;
                [array replaceObjectAtIndex:2 withObject:centerItem];
            }
        } else {
            if (asset.rgIsLoaded) {
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

#pragma mark - UICollectionViewDataSourcePrefetching

- (void)collectionView:(UICollectionView *)collectionView prefetchItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths {
    for (NSIndexPath *indexPath in indexPaths) {
        [self.cache imageForAsset:_assets[indexPath.row] onlyCache:NO syncLoad:NO allowNet:YES targetSize:self.thumbSize completion:nil];
    }
}

- (void)collectionView:(UICollectionView *)collectionView cancelPrefetchingForItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths {
    for (NSIndexPath *indexPath in indexPaths) {
        PHImageRequestID rgRequestId = _assets[indexPath.row].rgRequestId;
//        NSLog(@"PH Cancel Id:[%d]", rgRequestId);
        if (rgRequestId) {
            [[PHCachingImageManager defaultManager] cancelImageRequest:rgRequestId];
        }
    }
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
            
            PHFetchResult <PHAsset *> *oldAssets = self.assets;
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
                        NSArray *removePhotos = [oldAssets objectsAtIndexes:removed];
                        [self.cache removePhotos:removePhotos];
                        [collectionView deleteItemsAtIndexPaths:removedPaths];
                        
                        [self.imageGallery deletePages:removed];
                        [self __configViewWhenCacheChanged];
                    }
                    
                    if (inserted.count) {
                        [collectionView insertItemsAtIndexPaths:insertedPaths];
                        [self.imageGallery insertPages:inserted];
                    }
                    
                    if (changed.count) {
                        [self.cache removeCachePhotoForAsset:[self.assets objectsAtIndexes:changed]];
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

- (UIImage *)backgroundImageForImageGalleryBar:(RGImageGallery *)imageGallery {
    return nil;
}

- (UIImage *)backgroundImageForParentViewControllerBar {
    return nil;
}

- (NSString *)titleForImageGallery:(RGImageGallery *)imageGallery AtIndex:(NSInteger)index {
    if (index >= 0) {
        PHAsset *assert = _assets[index];
        NSString *title = [[assert creationDate] rg_stringWithDateFormat:@"yyyy-MM-dd\nHH:mm"];
        return title;
    } else {
        return @"";
    }
}

- (UIImage *)imageGallery:(RGImageGallery *)imageGallery thumbnailAtIndex:(NSInteger)index targetSize:(CGSize)targetSize {
    if (index>=0) {
        PHAsset *asset = _assets[index];
        return [self.cache imageForAsset:asset onlyCache:NO syncLoad:YES allowNet:NO targetSize:self.thumbSize completion:nil];
    }
    return nil;
}

- (UIImage *)imageGallery:(RGImageGallery *)imageGallery
             imageAtIndex:(NSInteger)index
               targetSize:(CGSize)targetSize
              updateImage:(void (^ _Nullable)(UIImage * _Nonnull))updateImage {
    if (index>=0) {
        PHAsset *asset = _assets[index];
        if (updateImage) {
            [RGImagePickerCell loadOriginalWithAsset:asset updateCell:nil collectionView:self.collectionView progressHandler:^(double progress) {
                
            } completion:^(NSData * _Nullable imageData, NSError * _Nullable error) {
                UIImage *image = [UIImage rg_imageOrGifWithData:imageData];
                if (image) {
                    updateImage(image);
                }
                if ([self->_assets[imageGallery.page].localIdentifier isEqualToString:asset.localIdentifier]) {
                    [imageGallery configToolBarItem];
                }
            }];
        }
        return nil;
    } else {
        return nil;
    }
}

- (UIView *)imageGallery:(RGImageGallery *)imageGallery thumbViewForPushAtIndex:(NSInteger)index {
    if (index >= 0) {
        if (imageGallery.pushState == RGImageGalleryPushStatePushed) {
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            if (imageGallery.pushState == RGImageGalleryPushStatePushed && index>=0) {
                NSIndexPath *needShowIndexPath = [NSIndexPath indexPathForRow:index inSection:0];
                if (![self.collectionView.indexPathsForVisibleItems containsObject:needShowIndexPath]) {
                    [self.collectionView scrollToItemAtIndexPath:needShowIndexPath atScrollPosition:UICollectionViewScrollPositionCenteredVertically animated:NO];
                }
            }
            [self.collectionView setNeedsLayout];
            [self.collectionView layoutIfNeeded];
            [CATransaction commit];
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
    
    UICollectionViewCell *cell = [self.collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForRow:imageGallery.page inSection:0]];
    cell.contentView.alpha = 0;
    
    RGIMGalleryTransitionCompletion com = ^(BOOL flag) {
        [self __doReloadData];
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

@end
