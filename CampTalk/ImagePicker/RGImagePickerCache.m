//
//  RGImagePickerCache.m
//  CampTalk
//
//  Created by renge on 2019/8/1.
//  Copyright © 2019 yuru. All rights reserved.
//

#import "RGImagePickerCache.h"
#import "RGImagePickerCell.h"
#import "RGImagePicker.h"
#import "UIImageView+RGGif.h"
#import <RGUIKit/RGUIKit.h>
#import "RGImageGallery.h"

NSNotificationName RGPHAssetLoadStatusHasChanged = @"RGPHAssetLoadStatusHasChanged";
NSNotificationName RGImagePickerCachePickPhotosHasChanged = @"RGImagePickerCachePickPhotosHasChanged";

@implementation PHAsset (RGLoaded)

- (void)setRgLoadLargeImageProgress:(CGFloat)rgLoadLargeImageProgress {
    [self rg_setValue:@(rgLoadLargeImageProgress) forKey:@"rgLoadLargeImageProgress" retain:YES];
}

- (CGFloat)rgLoadLargeImageProgress {
    return [[self rg_valueForKey:@"rgLoadLargeImageProgress"] floatValue];
}

- (void)setRgRequestId:(PHImageRequestID)rgRequestId {
    [self rg_setValue:@(rgRequestId) forKey:@"rgRequestId" retain:YES];
}

- (PHImageRequestID)rgRequestId {
    return [[self rg_valueForKey:@"rgRequestId"] intValue];
}

@end

@interface RGImagePickerCache() <RGImageGalleryDelegate, PHPhotoLibraryChangeObserver>

@property (nonatomic, strong) RGImageGallery *imageGallery;

@property (nonatomic, strong) PHAssetCollection *collections;
@property (nonatomic, strong) PHFetchResult<PHAsset *> *assets;

@property (nonatomic, strong) NSMutableDictionary <NSString *, NSNumber *> *loadStatus;

@end

@implementation RGImagePickerCache

- (instancetype)init {
    if (self = [super init]) {
        self.collections = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeSmartAlbumUserLibrary options:nil].lastObject;
        PHFetchOptions *option = [[PHFetchOptions alloc] init];
        self.assets = [PHAsset fetchAssetsInAssetCollection:self.collections options:option];
        [[PHPhotoLibrary sharedPhotoLibrary] registerChangeObserver:self];
    }
    return self;
}

- (void)dealloc {
    [[PHPhotoLibrary sharedPhotoLibrary] unregisterChangeObserver:self];
}

- (void)photoLibraryDidChange:(PHChange *)changeInstance {
    dispatch_async(dispatch_get_main_queue(), ^{
        PHFetchResultChangeDetails *collectionChanges = [changeInstance changeDetailsForFetchResult:self.assets];
        if (collectionChanges) {
            PHFetchResult <PHAsset *> *oldAssets = self.assets;
            self.assets = collectionChanges.fetchResultAfterChanges;
            
            if (collectionChanges.hasIncrementalChanges)  {
                
                NSIndexSet *removed = [collectionChanges removedIndexes];
                NSIndexSet *changed = [collectionChanges changedIndexes];
                
                if (removed.count) {
                    NSArray *removePhotos = [oldAssets objectsAtIndexes:removed];
                    [self removePhotos:removePhotos];
                }
                
                if (changed.count) {
                    NSArray <PHAsset *> *phassets = [self.assets objectsAtIndexes:changed];
                    [self removeThumbCachePhotoForAsset:phassets];
                    
                    NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
                    [phassets enumerateObjectsUsingBlock:^(PHAsset * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                        NSUInteger index = [self.pickPhotos indexOfObject:obj];
                        if (index != NSNotFound) {
                            [indexSet addIndex:idx];
                        }
                    }];
                    [self.imageGallery updatePages:indexSet];
                }
            }
        }
    });
}

- (NSMutableArray<PHAsset *> *)pickPhotos {
    if (!_pickPhotos) {
        _pickPhotos = [NSMutableArray array];
    }
    return _pickPhotos;
}

- (NSMutableArray<NSDictionary<NSString *,UIImage *> *> *)cachePhotos {
    if (!_cachePhotos) {
        _cachePhotos = [NSMutableArray array];
    }
    return _cachePhotos;
}

- (NSMutableDictionary<NSString *,NSNumber *> *)loadStatus {
    if (!_loadStatus) {
        _loadStatus = [NSMutableDictionary dictionary];
    }
    return _loadStatus;
}

- (void)setLoadStatusCache:(BOOL)loaded forAsset:(PHAsset *)asset {
    self.loadStatus[asset.localIdentifier] = @(loaded);
}

- (BOOL)loadStatusCacheForAsset:(PHAsset *)asset {
    return [self.loadStatus[asset.localIdentifier] boolValue];
}

- (void)requestLoadStatusWithAsset:(PHAsset *)asset result:(void(^)(BOOL needLoad))result {
    if ([self loadStatusCacheForAsset:asset]) {
        if (result) {
            result(NO);
        }
        return;
    }
    [RGImagePicker needLoadWithAsset:asset result:^(BOOL needLoad) {
        [self setLoadStatusCache:!needLoad forAsset:asset];
        if (result) {
            result(needLoad);
        }
    }];
}

- (void)addThumbCachePhoto:(UIImage *)photo forAsset:(PHAsset *)asset {
    if (!photo) {
        return;
    }
    NSUInteger index = [self indexForCacheAsset:asset];
    if (index != NSNotFound) {
        UIImage *image = self.cachePhotos[index].allValues.firstObject;
        if (photo.size.width > image.size.width || photo.size.height > image.size.height) {
            self.cachePhotos[index] = @{asset.localIdentifier: photo};
        }
        return;
    }
    if (self.cachePhotos.count > 100) {
        [self.cachePhotos removeObjectAtIndex:0];
    }
    [self.cachePhotos addObject:@{asset.localIdentifier: photo}];
}

- (void)removeThumbCachePhotoForAsset:(NSArray <PHAsset *> *)assets {
    [assets enumerateObjectsUsingBlock:^(PHAsset * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSInteger index = [self indexForCacheAsset:obj];
        if (index == NSNotFound) {
            return;
        }
        [self.cachePhotos removeObjectAtIndex:index];
    }];
}

- (NSUInteger)indexForCacheAsset:(PHAsset *)asset {
    for (NSInteger i = 0; i < self.cachePhotos.count; i++) {
        NSDictionary<NSString *,UIImage *> *obj = self.cachePhotos[i];
        if ([obj.allKeys.firstObject isEqualToString:asset.localIdentifier]) {
            return i;
        }
    }
    return NSNotFound;
}

- (UIImage *)imageForAsset:(PHAsset *)asset
                 onlyCache:(BOOL)onlyCache
                  syncLoad:(BOOL)syncLoad
                  allowNet:(BOOL)allowNet
                targetSize:(CGSize)targetSize
                completion:(void(^)(UIImage *image))completion {
    
    __block UIImage *image = nil;
    
    NSUInteger index = [self indexForCacheAsset:asset];
    if (index != NSNotFound) {
        image = self.cachePhotos[index].allValues.firstObject;
        if (completion) {
            completion(image);
        }
        return image;
    }
    
    if (onlyCache) {
        return image;
    }
    
    if (asset.rgRequestId) {
//        NSLog(@"PH Load And Cancel Id:[%d]", asset.rgRequestId);
        [[PHCachingImageManager defaultManager] cancelImageRequest:asset.rgRequestId];
        asset.rgRequestId = 0;
    }
    
    PHImageRequestOptions *op = [[PHImageRequestOptions alloc] init];
    op.resizeMode = PHImageRequestOptionsResizeModeFast;
    op.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
    op.synchronous = syncLoad;
    op.networkAccessAllowed = allowNet;
    
    [[PHCachingImageManager defaultManager] requestImageForAsset:asset targetSize:targetSize contentMode:PHImageContentModeAspectFill options:op resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
        
        asset.rgRequestId = 0;
        
        image = result;
        [self addThumbCachePhoto:result forAsset:asset];
        if (completion) {
            completion(image);
        }
    }];
    return image;
}

- (void)setPhotos:(NSArray<PHAsset *> *)phassets {
    NSIndexSet *delete = nil;
    NSIndexSet *insert = nil;
    NSIndexSet *update = nil;
    
    if (phassets.count < self.pickPhotos.count) {
        delete = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(phassets.count, self.pickPhotos.count - phassets.count)];
    } else {
        insert = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(self.pickPhotos.count, phassets.count - self.pickPhotos.count)];
    }
    update = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, phassets.count)];
    
    [self.pickPhotos removeAllObjects];
    [self.pickPhotos addObjectsFromArray:phassets];
    [[NSNotificationCenter defaultCenter] postNotificationName:RGImagePickerCachePickPhotosHasChanged object:nil];
    
    [self.imageGallery deletePages:delete];
    [self.imageGallery insertPages:delete];
    [self.imageGallery updatePages:update];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:RGImagePickerCachePickPhotosHasChanged object:nil];
}

- (void)addPhotos:(NSArray<PHAsset *> *)phassets {
    NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
    [phassets enumerateObjectsUsingBlock:^(PHAsset * _Nonnull addPhoto, NSUInteger idx, BOOL * _Nonnull stop) {
        NSInteger index = [self.pickPhotos indexOfObjectPassingTest:^BOOL(PHAsset * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([addPhoto.localIdentifier isEqualToString:obj.localIdentifier]) {
                *stop = YES;
                return YES;
            }
            return NO;
        }];
        if (index == NSNotFound) {
            [indexSet addIndex:self.pickPhotos.count];
            [self.pickPhotos addObject:addPhoto];
        }
    }];
    if (indexSet.count) {
        [self.imageGallery insertPages:indexSet];
        [[NSNotificationCenter defaultCenter] postNotificationName:RGImagePickerCachePickPhotosHasChanged object:nil];
    }
}

- (void)removePhotos:(NSArray<PHAsset *> *)phassets {
    NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
    [phassets enumerateObjectsUsingBlock:^(PHAsset * _Nonnull removedPhoto, NSUInteger idx, BOOL * _Nonnull stop) {
        NSInteger index = [self.pickPhotos indexOfObjectPassingTest:^BOOL(PHAsset * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([removedPhoto.localIdentifier isEqualToString:obj.localIdentifier]) {
                *stop = YES;
                return YES;
            }
            return NO;
        }];
        if (index != NSNotFound) {
            [indexSet addIndex:index];
            [self.pickPhotos removeObjectAtIndex:index];
        }
    }];
    if (indexSet.count) {
        [self.imageGallery deletePages:indexSet];
        [[NSNotificationCenter defaultCenter] postNotificationName:RGImagePickerCachePickPhotosHasChanged object:nil];
    }
}

- (BOOL)contain:(PHAsset *)phassets {
    return [self.pickPhotos containsObject:phassets];
}

- (BOOL)isFull {
    return self.pickPhotos.count >= self.maxCount;
}

- (void)callBack:(UIViewController *)viewController {
    if (![viewController isKindOfClass:UIViewController.class]) {
        viewController = [UIViewController rg_topViewController];
    }
    if (_pickResult) {
        _pickResult(_pickPhotos, viewController);
    }
}

- (void)showPickerPhotosWithParentViewController:(UIViewController *)viewController {
    if (!self.pickPhotos.count) return;
    self.imageGallery = [[RGImageGallery alloc] initWithPlaceHolder:nil andDelegate:self];
    viewController.navigationController.topViewController.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
    [viewController.navigationController pushViewController:self.imageGallery animated:YES];
}

#pragma mark - RGImageGalleryDelegate

- (nonnull UIView *)imageGallery:(nonnull RGImageGallery *)imageGallery thumbViewForPushAtIndex:(NSInteger)index {
    return nil;
}

- (NSInteger)numOfImagesForImageGallery:(nonnull RGImageGallery *)imageGallery {
    return self.pickPhotos.count;
}

- (UIImage *)imageGallery:(RGImageGallery *)imageGallery thumbnailAtIndex:(NSInteger)index targetSize:(CGSize)targetSize {
    return [self imageForAsset:self.pickPhotos[index] onlyCache:NO syncLoad:YES allowNet:YES targetSize:targetSize completion:nil];
}

- (UIImage *)imageGallery:(RGImageGallery *)imageGallery imageAtIndex:(NSInteger)index targetSize:(CGSize)targetSize updateImage:(void(^_Nullable)(UIImage *image))updateImage {
    PHAsset *asset = self.pickPhotos[index];
    if (updateImage) {
        [RGImagePickerCell loadOriginalWithAsset:asset cache:self updateCell:nil collectionView:nil progressHandler:^(double progress) {
            
        } completion:^(NSData * _Nullable imageData, NSError * _Nullable error) {
            UIImage *image = [UIImage rg_imageOrGifWithData:imageData];
            if (image) {
                updateImage(image);
            }
        }];
    }
    return nil;
}

- (UIColor *_Nullable)titleColorForImageGallery:(RGImageGallery *)imageGallery {
    return [UIColor blackColor];
}

- (NSString *_Nullable)titleForImageGallery:(RGImageGallery *)imageGallery AtIndex:(NSInteger)index {
    return [NSString stringWithFormat:@"%lu/%lu", index+1, (unsigned long)self.pickPhotos.count];
}

- (BOOL)imageGallery:(RGImageGallery *)imageGallery toolBarItemsShouldDisplayForIndex:(NSInteger)index {
    return YES;
}

- (NSArray<UIBarButtonItem *> *)imageGallery:(RGImageGallery *)imageGallery toolBarItemsForIndex:(NSInteger)index {
    return [self __createToolBarItmes];
}

- (void)__removeCurrentPhotos:(UIBarButtonItem *)sender {
    if (!self.pickPhotos.count) {
        return;
    }
    NSInteger index = self.imageGallery.page;
    [self removePhotos:@[self.pickPhotos[index]]];
}

- (NSMutableArray <UIBarButtonItem *> *)__createToolBarItmes {
    
    NSMutableArray *array = [NSMutableArray array];
    
    [array addObject:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil]];
    [array addObject:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil]];
    
    UIBarButtonItem *removeItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(__removeCurrentPhotos:)];
    [array addObject:removeItem];
    
    [array addObject:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil]];
    UIBarButtonItem *down = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"img_send2"] style:UIBarButtonItemStyleDone target:self action:@selector(callBack:)];
    [array addObject:down];
    
    return array;
}

@end
