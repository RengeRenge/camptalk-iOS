//
//  CTBubbleImageView.m
//  CampTalk
//
//  Created by renge on 2019/8/30.
//  Copyright © 2019 yuru. All rights reserved.
//

#import "CTBubbleImageView.h"

@interface CTBubbleImageView ()

@property (nonatomic, assign) BOOL fullDisplay;

@end

@implementation CTBubbleImageView
@synthesize imageView = _imageView;

- (void)awakeFromNib {
    [super awakeFromNib];
    self.backgroundView.backgroundColor = [UIColor whiteColor];
}

- (UIImageView *)imageView {
    if (!_imageView) {
        _imageView = [[UIImageView alloc] initWithFrame:self.bounds];
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        [self.backgroundView insertSubview:_imageView atIndex:0];
    }
    return _imageView;
}

- (void)setImage:(UIImage *)image {
    self.imageView.image = image;
}

- (UIImage *)image {
    return self.imageView.image;
}

- (void)setFullDisplay:(BOOL)fullDisplay {
    if (_fullDisplay == fullDisplay) {
        return;
    }
    _fullDisplay = fullDisplay;
//    if (fullDisplay) {
//        self.backgroundView.backgroundColor = [UIColor clearColor];
//    } else {
//        self.backgroundView.backgroundColor = [UIColor whiteColor];
//    }
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (_fullDisplay) {
        UIEdgeInsets bubbleEdge = [self.class contentViewEdgeWithRightToLeft:NO];
        bubbleEdge.left = bubbleEdge.right;
        self.imageView.frame = UIEdgeInsetsInsetRect(self.backgroundView.bounds, bubbleEdge);
    } else {
        UIEdgeInsets bubbleEdge = [self contentViewEdge];
        self.imageView.frame = UIEdgeInsetsInsetRect(self.backgroundView.bounds, bubbleEdge);
    }
}

- (CGRect)setBoundsWithImageSize:(CGSize)imageSize {
    
    UIEdgeInsets bubbleEdge = [CTBubbleImageView contentViewEdgeWithRightToLeft:NO];
    
    BOOL fullDisplay = (imageSize.width > bubbleEdge.left * 12);
    self.fullDisplay = fullDisplay;
    
    if (fullDisplay) {
        CGFloat sumHeight = imageSize.height + bubbleEdge.top + bubbleEdge.bottom;
        CGFloat sumWidth = imageSize.width*sumHeight/imageSize.height + bubbleEdge.right * 2;
        
        CGRect bounds = self.bounds;
        bounds.size = CGSizeMake(sumWidth, sumHeight);
        self.bounds = bounds;
    } else {
        // 图片尺寸过小，图片从气泡 contentView 上布局
        [self setBoundsWithCertainConentSize:imageSize];
    }
    return self.bounds;
}

@end
