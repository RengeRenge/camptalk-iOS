//
//  CTBubbleImageView.h
//  CampTalk
//
//  Created by renge on 2019/8/30.
//  Copyright © 2019 yuru. All rights reserved.
//

#import "RGBubbleView.h"

NS_ASSUME_NONNULL_BEGIN

@interface CTBubbleImageView : RGBubbleView

@property (nonatomic, strong, nullable) UIImage *image;
@property (nonatomic, strong, readonly) UIImageView *imageView;

- (CGRect)setBoundsWithImageSize:(CGSize)imageSize;

@end

NS_ASSUME_NONNULL_END
