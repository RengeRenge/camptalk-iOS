//
//  RGImagePicker.m
//  CampTalk
//
//  Created by renge on 2019/8/1.
//  Copyright © 2019 yuru. All rights reserved.
//

#import "RGImagePicker.h"
#import "RGImagePickerCache.h"
#import "RGImageAlbumListViewController.h"
#import <RGUIKit/RGUIKit.h>

const NSString *RGImagePickerResourceType = @"type";
const NSString *RGImagePickerResourceFilename = @"filename";
const NSString *RGImagePickerResourceData = @"data";
const NSString *RGImagePickerResourceThumbData = @"thumbData";
const NSString *RGImagePickerResourceSize = @"size";
const NSString *RGImagePickerResourceThumbSize = @"thumbSize";

@implementation RGImagePicker

+ (RGImagePickerViewController *)presentByViewController:(UIViewController *)presentingViewController pickResult:(RGImagePickResult)pickResult {
    return [self presentByViewController:presentingViewController maxCount:1 pickResult:pickResult];
}

+ (RGImagePickerViewController *)presentByViewController:(UIViewController *)presentingViewController maxCount:(NSUInteger)maxCount pickResult:(RGImagePickResult)pickResult {
    RGImagePickerCache *cache = [[RGImagePickerCache alloc] init];
    cache.pickResult = pickResult;
    cache.maxCount = maxCount;
    
    RGImagePickerViewController *vc = [[RGImagePickerViewController alloc] init];
    vc.cache = cache;
    
    void(^loadData)(void) = ^{
        vc.collection = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeSmartAlbumUserLibrary options:nil].lastObject;
    };
    
    if ([PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusNotDetermined) {
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
            if (status == PHAuthorizationStatusAuthorized) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    loadData();
                });
            }
        }];
    } else {
        loadData();
    }
    
    RGImageAlbumListViewController *list = [[RGImageAlbumListViewController alloc] initWithStyle:UITableViewStylePlain];
    list.pickResult = pickResult;
    list.cache = cache;
    
    RGNavigationController *nvg = [RGNavigationController navigationWithRoot:list style:RGNavigationBackgroundStyleNormal];
    [nvg setViewControllers:@[list, vc] animated:NO];
    nvg.modalPresentationStyle = UIModalPresentationOverFullScreen;
    nvg.tintColor = [UIColor blackColor];
    [presentingViewController presentViewController:nvg animated:YES completion:nil];
    
    UIBarButtonItem *camera = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCamera target:nil action:nil];
    list.navigationItem.backBarButtonItem = camera;
    
    return vc;
}

+ (void)needLoadWithAsset:(PHAsset *)asset result:(void (^)(BOOL))result {
//    if (asset.rgIsLoaded) {
//        if (result) {
//            result(NO);
//        }
//        return;
//    }
    
    void(^oldMethod)(void) = ^{
        PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
        options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
        options.networkAccessAllowed = NO;
        options.synchronous = NO;
        
        CGSize orSize = CGSizeMake(asset.pixelWidth, asset.pixelHeight);
        
        __block BOOL needLoad = NO;
        [[PHCachingImageManager defaultManager] requestImageForAsset:asset targetSize:orSize contentMode:PHImageContentModeAspectFill options:options resultHandler:^(UIImage * _Nullable image, NSDictionary * _Nullable info) {
            BOOL isLoaded = ![info[PHImageResultIsDegradedKey] boolValue] && image;
            needLoad = !isLoaded;
//            asset.rgIsLoaded = isLoaded;
            if (result) {
                result(needLoad);
            }
        }];
    };
    
    if (@available(iOS 9.0, *)) {
        if (asset.mediaSubtypes != 32) {
            oldMethod();
            return;
        }
        
        NSArray<PHAssetResource *> * resources = [PHAssetResource assetResourcesForAsset:asset];
        for (NSInteger i = resources.count - 1; i >= 0; i--) {
            PHAssetResource *obj = resources[i];
            if (![self isPhoto:obj]) {
                continue;
            }
            
            if ([self isGIF:obj]) {
                PHAssetResourceRequestOptions *option = [[PHAssetResourceRequestOptions alloc] init];
                option.networkAccessAllowed = NO;
                
                __block BOOL hasData = NO;
                [[PHAssetResourceManager defaultManager] requestDataForAssetResource:obj options:option dataReceivedHandler:^(NSData * _Nonnull data) {
                    hasData |= data.length > 0;
                } completionHandler:^(NSError * _Nullable error) {
                    if (result) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            BOOL needLoad = error || !hasData;
//                            asset.rgIsLoaded = !needLoad;
                            result(needLoad);
                        });
                    }
                }];
            } else {
                oldMethod();
            }
            break;
        }
    } else {
        oldMethod();
    }
}

+ (void)loadResourceFromAssets:(NSArray<PHAsset *> *)assets completion:(nonnull void (^)(NSArray<NSDictionary *> * _Nonnull, NSError * _Nullable))completion {
    [self loadResourceFromAssets:assets thumbSize:CGSizeZero completion:completion];
}

+ (void)loadResourceFromAssets:(NSArray<PHAsset *> *)assets thumbSize:(CGSize)thumbSize completion:(void (^)(NSArray<NSDictionary *> * _Nonnull, NSError * _Nullable))completion {
    if (assets.count == 0) {
        if (completion) {
            completion(@[], nil);
        }
    }
    
    NSMutableArray <NSDictionary *> *array = [NSMutableArray arrayWithCapacity:assets.count];
    for (int i = 0; i < assets.count; i++) {
        [array addObject:@{}];
    }

    __block NSInteger count = assets.count;
    
    void(^callBackIfNeed)(NSError *error) = ^(NSError *error) {
        count--;
        if ((count == 0 || error) && completion) {
            count = 0;
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(array, error);
            });
        }
    };
    
    [assets enumerateObjectsUsingBlock:^(PHAsset * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self loadResourceFromAsset:obj progressHandler:nil completion:^(NSDictionary * _Nullable resource, NSError * _Nullable error) {
            
            if (error) {
                callBackIfNeed(error);
                return;
            }
            
            if ([resource[RGImagePickerResourceData] length]) {
                if (!CGSizeEqualToSize(thumbSize, CGSizeZero)) {
                    [self imageForAsset:obj syncLoad:NO allowNet:YES targetSize:thumbSize resizeMode:PHImageRequestOptionsResizeModeExact needImage:NO completion:^(NSData *thumbData) {
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                            NSMutableDictionary *newResource = [NSMutableDictionary dictionaryWithDictionary:resource];
                            
                            UIImage *thumbImage = [UIImage imageWithData:thumbData];
                            NSData *smallData = UIImageJPEGRepresentation(thumbImage, 0.5);
                            if (smallData.length > thumbData.length) {
                                smallData = thumbData;
                            } else {
                                thumbImage = [UIImage imageWithData:smallData];
                            }
                            newResource[RGImagePickerResourceThumbData] = smallData;
                            newResource[RGImagePickerResourceThumbSize] = NSStringFromCGSize(thumbImage.rg_pixSize);
                            [array replaceObjectAtIndex:idx withObject:newResource];
                            callBackIfNeed(error);
                        });
                    }];
                } else {
                    [array replaceObjectAtIndex:idx withObject:resource];
                    callBackIfNeed(error);
                }
            } else {
                callBackIfNeed(error);
            }
        }];
    }];
}

+ (void)loadResourceFromAsset:(PHAsset *)asset progressHandler:(void (^ _Nullable)(double))progressHandler completion:(void (^ _Nullable)(NSDictionary * _Nullable info, NSError * _Nullable error))completion {
    [self loadResourceFromAsset:asset networkAccessAllowed:YES progressHandler:progressHandler completion:completion];
}

+ (void)loadResourceFromAsset:(PHAsset *)asset networkAccessAllowed:(BOOL)networkAccessAllowed progressHandler:(void (^ _Nullable)(double))progressHandler completion:(void (^ _Nullable)(NSDictionary * _Nullable, NSError * _Nullable))completion {
    
    void(^callBackIfNeed)(NSDictionary *resource, NSError *error) = ^(NSDictionary *resource, NSError *error) {
        if (completion && (resource.count || error)) {
            dispatch_async(dispatch_get_main_queue(), ^{
//                if (networkAccessAllowed && data.length) {
//                    asset.rgIsLoaded = YES;
//                }
                completion(resource, error);
            });
        }
    };
    
    void(^oldMethod)(void) = ^{
        PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
        options.synchronous = NO;
        options.networkAccessAllowed = networkAccessAllowed;
        options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
        options.progressHandler = ^(double progress, NSError * _Nullable error, BOOL * _Nonnull stop, NSDictionary * _Nullable info) {
            if (progressHandler) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    asset.rgLoadLargeImageProgress = progress;
                    progressHandler(progress);
                });
            }
            callBackIfNeed(nil, error);
        };
        
        [[PHCachingImageManager defaultManager] requestImageDataForAsset:asset options:options resultHandler:^(NSData * _Nullable imageData, NSString * _Nullable dataUTI, UIImageOrientation orientation, NSDictionary * _Nullable info) {
            if (!imageData) {
                return;
            }
            
            NSURL *path = info[@"PHImageFileURLKey"];
            NSString *filename = @"";
            if (path) {
                filename = path.lastPathComponent;
            } else {
                filename = [[NSUUID UUID].UUIDString stringByAppendingPathExtension:dataUTI.pathExtension];
            }
            CGSize size = CGSizeMake(asset.pixelWidth, asset.pixelHeight);
            callBackIfNeed(@{
                             RGImagePickerResourceData: imageData,
                             RGImagePickerResourceSize: NSStringFromCGSize(size),
                             RGImagePickerResourceType: dataUTI,
                             RGImagePickerResourceFilename: filename,
                             }, nil);
        }];
    };
    
    if (@available(iOS 9.0, *)) {
        NSArray<PHAssetResource *> * resources = [PHAssetResource assetResourcesForAsset:asset];
        if (!resources.count) {
            oldMethod();
            return;
        }
        
        for (NSInteger i = resources.count - 1; i >= 0; i--) {
            PHAssetResource *obj = resources[i];
            if (![self isPhoto:obj]) {
                continue;
            }
            
            PHAssetResourceRequestOptions *option = [[PHAssetResourceRequestOptions alloc] init];
            option.networkAccessAllowed = networkAccessAllowed;
            
            option.progressHandler = ^(double progress) {
                if (progressHandler) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        asset.rgLoadLargeImageProgress = progress;
                        progressHandler(progress);
                    });
                }
            };
            
            NSMutableData *imageData = [NSMutableData data];
            [[PHAssetResourceManager defaultManager] requestDataForAssetResource:obj options:option dataReceivedHandler:^(NSData * _Nonnull data) {
                [imageData appendData:data];
            } completionHandler:^(NSError * _Nullable error) {
                CGSize size = CGSizeMake(asset.pixelWidth, asset.pixelHeight);
                callBackIfNeed(@{
                                 RGImagePickerResourceData: imageData,
                                 RGImagePickerResourceSize: NSStringFromCGSize(size),
                                 RGImagePickerResourceType: obj.uniformTypeIdentifier,
                                 RGImagePickerResourceFilename: obj.originalFilename,
                                 }, error);
            }];
            break;
        }
    } else {
        oldMethod();
    }
}

+ (void)imageForAsset:(PHAsset *)asset
             syncLoad:(BOOL)syncLoad
             allowNet:(BOOL)allowNet
           targetSize:(CGSize)targetSize
           resizeMode:(PHImageRequestOptionsResizeMode)resizeMode
            needImage:(BOOL)needImage
           completion:(void(^_Nullable)(id image))completion {
    
    PHImageRequestOptions *op = [[PHImageRequestOptions alloc] init];
    op.resizeMode = resizeMode;
    op.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
    op.synchronous = syncLoad;
    op.networkAccessAllowed = allowNet;
    
    if (needImage) {
        [[PHCachingImageManager defaultManager] requestImageForAsset:asset targetSize:targetSize contentMode:PHImageContentModeAspectFill options:op resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
            if (completion) {
                completion(result);
            }
        }];
    } else {
        [[PHCachingImageManager defaultManager] requestImageDataForAsset:asset options:op resultHandler:^(NSData * _Nullable imageData, NSString * _Nullable dataUTI, UIImageOrientation orientation, NSDictionary * _Nullable info) {
            if (completion) {
                completion(imageData);
            }
        }];
    }
}

+ (BOOL)isPhoto:(PHAssetResource *)resource  API_AVAILABLE(ios(9.0)) {
    switch (resource.type) {
        case PHAssetResourceTypeFullSizePhoto:
        case PHAssetResourceTypePhoto:
        case PHAssetResourceTypeAlternatePhoto:
        case PHAssetResourceTypeAdjustmentBasePhoto:
            return YES;
        default:
            return NO;
    }
}

+ (BOOL)isGIF:(PHAssetResource *)resource  API_AVAILABLE(ios(9.0)) {
    if ([resource.uniformTypeIdentifier hasSuffix:@".gif"] || [resource.uniformTypeIdentifier hasSuffix:@".GIF"]) {
        return YES;
    }
    
    if ([resource.originalFilename hasSuffix:@".gif"] || [resource.originalFilename hasSuffix:@".GIF"]) {
        return YES;
    }
    return NO;
}

+ (BOOL)isPNG:(PHAssetResource *)resource  API_AVAILABLE(ios(9.0)) {
    if ([resource.uniformTypeIdentifier hasSuffix:@".png"] || [resource.uniformTypeIdentifier hasSuffix:@".PNG"]) {
        return YES;
    }
    
    if ([resource.originalFilename hasSuffix:@".png"] || [resource.originalFilename hasSuffix:@".PNG"]) {
        return YES;
    }
    return NO;
}

@end
