//
//  RGImagerPickerConfig+RGSetting.m
//  CampTalk
//
//  Created by renge on 2019/9/1.
//  Copyright © 2019 yuru. All rights reserved.
//

#import "RGImagePickerConfig+RGSetting.h"
#import <RGUIKit/RGUIKit.h>

@implementation RGImagePickerConfig(RGSetting)

+ (instancetype)chatConfigWithImage:(UIImage *)image {
    RGImagePickerConfig *config = [RGImagePickerConfig new];
    config.backgroundImage = image;
    config.backgroundBlurRadius = 3.5;
    config.tintColor = [UIColor rg_labelColor];
    
    NSMutableArray *array = [NSMutableArray array];
    
    [array addObject:@(PHAssetCollectionSubtypeSmartAlbumUserLibrary)];
    
    // 收藏
    [array addObject:@(PHAssetCollectionSubtypeSmartAlbumFavorites)];
    [array addObject:@(PHAssetCollectionSubtypeSmartAlbumTimelapses)];
    [array addObject:@(PHAssetCollectionSubtypeSmartAlbumRecentlyAdded)];
    if (@available(iOS 10.3, *)) {
        [array addObject:@(PHAssetCollectionSubtypeSmartAlbumLivePhotos)];
    }
    [array addObject:@(PHAssetCollectionSubtypeSmartAlbumPanoramas)];
    
    if (@available(iOS 9.0, *)) {
        [array addObject:@(PHAssetCollectionSubtypeSmartAlbumSelfPortraits)];
    }
    if (@available(iOS 9.0, *)) {
        [array addObject:@(PHAssetCollectionSubtypeSmartAlbumScreenshots)];
    }
    if (@available(iOS 10.2, *)) {
        [array addObject:@(PHAssetCollectionSubtypeSmartAlbumDepthEffect)];
    }
    // 动图
    if (@available(iOS 11.0, *)) {
        [array addObject:@(PHAssetCollectionSubtypeSmartAlbumAnimated)];
    }
//    config.cutomSmartAlbum = array;
    return config;
}

@end
