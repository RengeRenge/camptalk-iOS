//
//  RGImagePickerCache.m
//  CampTalk
//
//  Created by renge on 2019/8/1.
//  Copyright © 2019 yuru. All rights reserved.
//

#import "RGImagePickerCache.h"
#import <RGUIKit/RGUIKit.h>

NSNotificationName RGPHAssetLoadStatusHasChanged = @"RGPHAssetLoadStatusHasChanged";

@implementation PHAsset (RGLoaded)

- (void)setRgLoadLargeImageProgress:(CGFloat)rgLoadLargeImageProgress {
    [self rg_setValue:@(rgLoadLargeImageProgress) forKey:@"rgLoadLargeImageProgress" retain:YES];
}

- (CGFloat)rgLoadLargeImageProgress {
    return [[self rg_valueForKey:@"rgLoadLargeImageProgress"] floatValue];
}

- (void)setRgIsLoaded:(BOOL)rgIsLoaded {
    if (self.rgIsLoaded == rgIsLoaded) {
        return;
    }
//    [[NSNotificationCenter defaultCenter] postNotificationName:RGPHAssetLoadStatusHasChanged object:self];
    [self rg_setValue:@(rgIsLoaded) forKey:@"rgIsLoaded" retain:YES];
}

- (BOOL)rgIsLoaded {
    return [[self rg_valueForKey:@"rgIsLoaded"] boolValue];
}

- (void)setRgRequestId:(PHImageRequestID)rgRequestId {
    [self rg_setValue:@(rgRequestId) forKey:@"rgRequestId" retain:YES];
}

- (PHImageRequestID)rgRequestId {
    return [[self rg_valueForKey:@"rgRequestId"] intValue];
}

@end

@implementation RGImagePickerCache

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

- (void)addCachePhoto:(UIImage *)photo forAsset:(PHAsset *)asset {
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

- (void)removeCachePhotoForAsset:(NSArray <PHAsset *> *)assets {
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
        [self addCachePhoto:result forAsset:asset];
        if (completion) {
            completion(image);
        }
    }];
    return image;
}

- (void)setPhotos:(NSArray<PHAsset *> *)phassets {
    [self.pickPhotos removeAllObjects];
    [self.pickPhotos addObjectsFromArray:phassets];
//    [self.pickPhotos replaceObjectsInRange:NSMakeRange(0, self.pickPhotos.count) withObjectsFromArray:phassets];
}

- (void)addPhotos:(NSArray<PHAsset *> *)phassets {
    [phassets enumerateObjectsUsingBlock:^(PHAsset * _Nonnull addPhoto, NSUInteger idx, BOOL * _Nonnull stop) {
        NSInteger index = [self.pickPhotos indexOfObjectPassingTest:^BOOL(PHAsset * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([addPhoto.localIdentifier isEqualToString:obj.localIdentifier]) {
                *stop = YES;
                return YES;
            }
            return NO;
        }];
        if (index == NSNotFound) {
            [self.pickPhotos addObject:addPhoto];
        }
    }];
}

- (void)removePhotos:(NSArray<PHAsset *> *)phassets {
    [phassets enumerateObjectsUsingBlock:^(PHAsset * _Nonnull removedPhoto, NSUInteger idx, BOOL * _Nonnull stop) {
        NSInteger index = [self.pickPhotos indexOfObjectPassingTest:^BOOL(PHAsset * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([removedPhoto.localIdentifier isEqualToString:obj.localIdentifier]) {
                *stop = YES;
                return YES;
            }
            return NO;
        }];
        if (index != NSNotFound) {
            [self.pickPhotos removeObjectAtIndex:index];
        }
    }];
}

- (BOOL)contain:(PHAsset *)phassets {
    return [self.pickPhotos containsObject:phassets];
}

- (BOOL)isFull {
    return self.pickPhotos.count >= self.maxCount;
}

- (void)callBack:(UIViewController *)viewController {
    if (_pickResult) {
        _pickResult(_pickPhotos, viewController);
    }
}

@end
