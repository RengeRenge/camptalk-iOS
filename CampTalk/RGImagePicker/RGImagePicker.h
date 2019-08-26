//
//  RGImagePicker.h
//  CampTalk
//
//  Created by renge on 2019/8/1.
//  Copyright © 2019 yuru. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RGImagePickerConst.h"
#import "RGImagePickerViewController.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *RGImagePickerResourceType;
extern NSString *RGImagePickerResourceFilename;
extern NSString *RGImagePickerResourceData;
extern NSString *RGImagePickerResourceThumbData;
extern NSString *RGImagePickerResourceSize;
extern NSString *RGImagePickerResourceThumbSize;

@interface RGImagePicker : NSObject

+ (RGImagePickerViewController *)presentByViewController:(UIViewController *)presentingViewController pickResult:(RGImagePickResult)pickResult;

+ (RGImagePickerViewController *)presentByViewController:(UIViewController *)presentingViewController maxCount:(NSUInteger)maxCount pickResult:(RGImagePickResult)pickResult;

+ (void)needLoadWithAsset:(PHAsset *)asset result:(void(^)(BOOL needLoad))result;

+ (void)imageForAsset:(PHAsset *)asset
             syncLoad:(BOOL)syncLoad
             allowNet:(BOOL)allowNet
           targetSize:(CGSize)targetSize
           resizeMode:(PHImageRequestOptionsResizeMode)resizeMode
            needImage:(BOOL)needImage
           completion:(void(^_Nullable)(id image))completion;

+ (void)loadResourceFromAsset:(PHAsset *)asset
              progressHandler:(void(^_Nullable)(double progress))progressHandler
                   completion:(void (^_Nullable)(NSDictionary *_Nullable resource, NSError *_Nullable error))completion;

+ (void)loadResourceFromAssets:(NSArray <PHAsset *> *)assets
                     thumbSize:(CGSize)thumbSize
                    completion:(void(^)(NSArray <NSDictionary *> *resource, NSError *_Nullable error))completion;

+ (void)loadResourceFromAssets:(NSArray <PHAsset *> *)assets
                    completion:(void(^)(NSArray <NSDictionary *> *resource, NSError *_Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
