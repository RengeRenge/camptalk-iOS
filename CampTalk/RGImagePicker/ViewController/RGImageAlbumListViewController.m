//
//  CTImageAlbumListViewController.m
//  CampTalk
//
//  Created by renge on 2018/5/7.
//  Copyright © 2018年 yuru. All rights reserved.
//

#import "RGImageAlbumListViewController.h"
#import "RGImagePickerViewController.h"
#import <RGUIKit/RGUIKit.h>

@interface RGImageAlbumListViewController () <PHPhotoLibraryChangeObserver>

@property (nonatomic, strong) NSArray <PHAssetCollection *> *customCollections;
@property (nonatomic, strong) NSArray <PHFetchResult<PHAsset *> *> *customAssets;

@property (nonatomic, strong) PHFetchResult<PHAssetCollection *> *assetCollections;

@end

@implementation RGImageAlbumListViewController

- (instancetype)initWithStyle:(UITableViewStyle)style {
    if (self = [super initWithStyle:style]) {
        [[PHPhotoLibrary sharedPhotoLibrary] registerChangeObserver:self];
        [self loadData];
    }
    return self;
}

- (void)loadData {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"mediaType = %d", PHAssetMediaTypeImage];
        PHFetchOptions *option = [[PHFetchOptions alloc] init];
        option.predicate = predicate;
        
        NSMutableArray <PHAssetCollection *> *customCollections = [NSMutableArray array];
        NSMutableArray <PHFetchResult<PHAsset *> *> *customAssets = [NSMutableArray array];
        
        void(^customCollection)(PHAssetCollectionSubtype type) = ^(PHAssetCollectionSubtype type) {
            PHAssetCollection *collections = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:type options:nil].lastObject;
            PHFetchResult<PHAsset *> *asset = [PHAsset fetchAssetsInAssetCollection:collections options:option];
            
            if (collections && asset) {
                [customCollections addObject:collections];
                [customAssets addObject:asset];
            }
        };
        
        // 所有照片
        customCollection(PHAssetCollectionSubtypeSmartAlbumUserLibrary);
        // 收藏
        customCollection(PHAssetCollectionSubtypeSmartAlbumFavorites);
        customCollection(PHAssetCollectionSubtypeSmartAlbumTimelapses);
        customCollection(PHAssetCollectionSubtypeSmartAlbumRecentlyAdded);
        if (@available(iOS 9.0, *)) {
            customCollection(PHAssetCollectionSubtypeSmartAlbumSelfPortraits);
        }
        if (@available(iOS 9.0, *)) {
            customCollection(PHAssetCollectionSubtypeSmartAlbumScreenshots);
        }
        if (@available(iOS 10.2, *)) {
            customCollection(PHAssetCollectionSubtypeSmartAlbumDepthEffect);
        }
        // 动图
        if (@available(iOS 11.0, *)) {
            customCollection(PHAssetCollectionSubtypeSmartAlbumAnimated);
        }
        
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.customAssets = customAssets;
            self.customCollections = customCollections;
            
            // 其他相册
            self.assetCollections = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum subtype:PHAssetCollectionSubtypeAlbumRegular options:nil];
            
            if (self.isViewLoaded) {
                [self.tableView reloadData];
            } else {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    if (!self.isViewLoaded) {
                        [self.tableView reloadData];
                    }
                });
            }
        });
    });
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.tableFooterView = [UIView new];
    self.tableView.rowHeight = 44;
    self.tableView.estimatedRowHeight = 0;
    [self.tableView registerClass:RGIconCell.class forCellReuseIdentifier:RGCellIDValue1];
    
    UIBarButtonItem *down = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(rg_dismiss)];
    self.navigationItem.rightBarButtonItem = down;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self setNeedsStatusBarAppearanceUpdate];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.navigationController.presentingViewController setNeedsStatusBarAppearanceUpdate];
}

- (void)dealloc {
    [[PHPhotoLibrary sharedPhotoLibrary] unregisterChangeObserver:self];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.customCollections.count + _assetCollections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section < self.customAssets.count) {
        return self.customAssets[section].count > 0 ? 1 : 0;
    }
    return [PHAsset fetchAssetsInAssetCollection:_assetCollections[section - self.customAssets.count] options:nil].count > 0 ? 1 : 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    RGIconCell *cell = [tableView dequeueReusableCellWithIdentifier:RGCellIDValue1 forIndexPath:indexPath];
    cell.iconSize = CGSizeMake(tableView.rowHeight, tableView.rowHeight);
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    PHAsset *asset;
    if (indexPath.section < self.customCollections.count) {
        asset = self.customAssets[indexPath.section].lastObject;
        cell.textLabel.text = self.customCollections[indexPath.section].localizedTitle;
        cell.detailTextLabel.text = @(self.customAssets[indexPath.section].count).stringValue;
    } else {
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"mediaType = %d", PHAssetMediaTypeImage];
        PHFetchOptions *option = [[PHFetchOptions alloc] init];
        option.predicate = predicate;
        
        PHFetchResult<PHAsset *> *result = [PHAsset fetchAssetsInAssetCollection:_assetCollections[indexPath.section - self.customCollections.count] options:option];
        asset = result.lastObject;
        
        cell.textLabel.text = _assetCollections[indexPath.section - self.customCollections.count].localizedTitle;
        cell.detailTextLabel.text = @(result.count).stringValue;
    }
    
    [[PHCachingImageManager defaultManager] requestImageForAsset:asset targetSize:CGSizeMake(tableView.rowHeight, tableView.rowHeight) contentMode:PHImageContentModeAspectFill options:0 resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
        cell.imageView.image = result;
    }];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    PHAssetCollection *collection = nil;
    if (indexPath.section < self.customCollections.count) {
        collection = self.customCollections[indexPath.section];
    } else {
        collection = _assetCollections[indexPath.section - self.customCollections.count];
    }
    RGImagePickerViewController *albumDetails = [[RGImagePickerViewController alloc] init];
    albumDetails.collection = collection;
    albumDetails.cache = self.cache;
    [self.navigationController pushViewController:albumDetails animated:YES];
}

- (void)callBack {
    [self.cache callBack:self];
}

#pragma mark - PHPhotoLibraryChangeObserver

- (void)photoLibraryDidChange:(PHChange *)changeInstance {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self loadData];
    });
}

@end
