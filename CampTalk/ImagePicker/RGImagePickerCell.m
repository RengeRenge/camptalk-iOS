//
//  CTImagePickerCell.m
//  CampTalk
//
//  Created by renge on 2019/8/2.
//  Copyright © 2019 yuru. All rights reserved.
//

#import "RGImagePickerCell.h"
//#import <RGUIKit/RGUIKit.h>
#import "RGImagePicker.h"

static PHImageRequestOptions *__ctImagePickerOptions;

@implementation RGImagePickerCell

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.layer.cornerRadius = 2.f;
        self.clipsToBounds = YES;
        self.contentView.backgroundColor = [UIColor clearColor];
        [self.contentView addSubview:self.selectedButton];
//        [self.contentView.layer addSublayer:self.selectedLayer];
        
        if (!self.supportForceTouch) {
            UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)];
            [self.contentView addGestureRecognizer:longPress];
        }
    }
    return self;
}

- (CAShapeLayer *)checkMarkLayer {
    if (!_checkMarkLayer) {
        _checkMarkLayer = [CAShapeLayer layer];
        _checkMarkLayer.frame = CGRectMake(0, 0, 25, 25);
        
        UIBezierPath* bezier2Path = [UIBezierPath bezierPath];
        
        [bezier2Path moveToPoint: CGPointMake(5, 14.95)];
        [bezier2Path addLineToPoint: CGPointMake(10.25, 20.01)];
        [bezier2Path addLineToPoint: CGPointMake(21.475, 7.83)];
        
        _checkMarkLayer.path = bezier2Path.CGPath;
        _checkMarkLayer.fillColor = [UIColor clearColor].CGColor;
        _checkMarkLayer.strokeColor = [UIColor blackColor].CGColor;
        _checkMarkLayer.lineWidth = 2.f;
        _checkMarkLayer.lineCap = kCALineCapRound;
        _checkMarkLayer.lineJoin = kCALineJoinRound;
        _checkMarkLayer.strokeEnd = 0.f;
        _checkMarkLayer.strokeStart = 0.f;
    }
    return _checkMarkLayer;
}

- (CAShapeLayer *)selectedLayer {
    if (!_selectedLayer) {
        _selectedLayer = [CAShapeLayer layer];
        _selectedLayer.frame = CGRectMake(10, 5, 25, 25);
        _selectedLayer.path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, 25, 25) cornerRadius:12.5f].CGPath;
        _selectedLayer.strokeColor = [UIColor whiteColor].CGColor;
        _selectedLayer.fillColor = [UIColor clearColor].CGColor;
        _selectedLayer.lineWidth = 1.5f;
        
        [_selectedLayer addSublayer:self.checkMarkLayer];
    }
    return _selectedLayer;
}

- (UIButton *)selectedButton {
    if (!_selectedButton) {
        _selectedButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
        [_selectedButton addTarget:self action:@selector(checked) forControlEvents:UIControlEventTouchUpInside];
        [_selectedButton.layer addSublayer:self.selectedLayer];
    }
    return _selectedButton;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _imageView.frame = self.contentView.bounds;
    [self.contentView sendSubviewToBack:_imageView];
    
    CGRect frame = _selectedButton.frame;
    frame.origin.x = self.contentView.bounds.size.width - frame.size.width;
    _selectedButton.frame = frame;
}

- (void)checked {
    [self.delegate didCheckForImagePickerCell:self];
}

- (void)setSelected:(BOOL)selected {
    [self setSelected:selected animated:NO];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected];
    if (!animated) {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
    }
    if (selected) {
        _selectedLayer.fillColor = [UIColor whiteColor].CGColor;
        _checkMarkLayer.strokeEnd = 1.f;
        self.selectedButton.hidden = NO;
    } else {
        self.selectedButton.hidden = self.cache.isFull;
        _selectedLayer.fillColor = [UIColor clearColor].CGColor;
        _checkMarkLayer.strokeEnd = 0.f;
    }
    if (!animated) {
        [CATransaction commit];
    }
}

- (UIImageView *)imageView {
    if (!_imageView) {
        _imageView = [[UIImageView alloc] initWithFrame:self.contentView.bounds];
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        _imageView.clipsToBounds = YES;
        
        self.imageViewMask.frame = _imageView.bounds;
        self.imageViewMask.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [_imageView addSubview:self.imageViewMask];
        
        [self.contentView addSubview:_imageView];
    }
    return _imageView;
}

- (UIView *)imageViewMask {
    if (!_imageViewMask) {
        _imageViewMask = [[UIView alloc] init];
    }
    return _imageViewMask;
}

+ (void)setAsset:(PHAsset *)asset targetSize:(CGSize)targetSize updateCell:(RGImagePickerCell *)cell cache:(RGImagePickerCache *)cache {
    if (cell && (cell.asset == asset || [cell isCurrentAsset:asset])) {
        return;
    }
    
    if (asset.rgRequestId) {
//        NSLog(@"PH Load And Cancel Id:[%d]", asset.rgRequestId);
        [[PHCachingImageManager defaultManager] cancelImageRequest:asset.rgRequestId];
        asset.rgRequestId = 0;
    }
    
    void(^didLoadImage)(UIImage *result) = ^(UIImage *result) {
        cell.imageView.image = result;
        [RGImagePickerCell needLoadWithAsset:asset result:^(BOOL needLoadWithAsset) {
            if (!cell) {
                return;
            }
            if (![cell->_asset.localIdentifier isEqualToString:asset.localIdentifier]) {
                return;
            }
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            if (needLoadWithAsset) {
                cell->_selectedLayer.strokeEnd = 0.f;
            } else {
                cell->_selectedLayer.strokeEnd = 1.f;
            }
            [CATransaction commit];
            
            if (needLoadWithAsset) {
                cell->_selectedLayer.strokeEnd = 0.f;
                cell.imageViewMask.backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.6];
            } else {
                cell->_selectedLayer.strokeEnd = 1.f;
                cell.imageViewMask.backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.0];
            }
            
            if (cell.asset == asset) {
                if (cell.imageView.image != result) {
                    cell.imageView.image = result;
                }
            }
        }];
    };
    
    
    cell.asset = asset;
    UIImage *image = [cache imageForAsset:asset];
    if (image) {
        asset.rgRequestId = 0;
        didLoadImage(image);
        return;
    }
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __ctImagePickerOptions = [[PHImageRequestOptions alloc] init];
        __ctImagePickerOptions.resizeMode = PHImageRequestOptionsResizeModeFast;
        __ctImagePickerOptions.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
    });
    
    asset.rgRequestId =
    [[PHCachingImageManager defaultManager] requestImageForAsset:asset targetSize:targetSize contentMode:PHImageContentModeAspectFill options:__ctImagePickerOptions resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
        
        if (result) {
            asset.rgRequestId = 0;
        }
        [cache addCachePhoto:result forAsset:asset];
        
        if (!cell) {
            return;
        }
        
        if (![cell->_asset.localIdentifier isEqualToString:asset.localIdentifier]) {
            return;
        }
        if (!result) {
            return;
        }
        
        didLoadImage(result);
    }];
    
//    NSLog(@"PH Load Id:[%d]", asset.rgRequestId);
}

- (BOOL)isCurrentAsset:(PHAsset *)asset {
    return [self->_asset.localIdentifier isEqualToString:asset.localIdentifier];
}

+ (void)needLoadWithAsset:(PHAsset *)asset result:(void(^)(BOOL needLoad))result {
    [RGImagePicker needLoadWithAsset:asset result:result];
}

+ (void)loadOriginalWithAsset:(PHAsset *)asset updateCell:(nonnull RGImagePickerCell *)cell {
    [RGImagePicker loadResourceFromAsset:asset progressHandler:^(double progress) {
        if (![cell isCurrentAsset:asset]) {
            return;
        }
        cell->_selectedLayer.strokeEnd = progress;
    } completion:^(NSData * _Nullable imageData, NSError * _Nullable error) {
        if (![cell isCurrentAsset:asset]) {
            return;
        }
        if (error) {
            asset.rgIsLoaded = NO;
            cell.imageViewMask.backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.6];
        } else {
            asset.rgIsLoaded = YES;
            cell.imageViewMask.backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.0];
        }
    }];
}

- (BOOL)supportForceTouch {
    if ([self respondsToSelector:@selector(traitCollection)]) {
        if ([self.traitCollection respondsToSelector:@selector(forceTouchCapability)])
        {
            if (@available(iOS 9.0, *)) {
                if(self.traitCollection.forceTouchCapability == UIForceTouchCapabilityAvailable) {
                    return YES;
                }
            }
        }
    }
    return NO;
}

- (void)longPress:(UILongPressGestureRecognizer *)gesture {
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan:{
            [UIView animateWithDuration:0.3 animations:^{
                [self.delegate imagePickerCell:self touchForce:1 maximumPossibleForce:1];
            }];
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateFailed:
        case UIGestureRecognizerStateCancelled:{
            [UIView animateWithDuration:0.3 animations:^{
                [self.delegate imagePickerCell:self touchForce:0 maximumPossibleForce:1];
            }];
            break;
        }
        default:
            break;
    }
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    UITouch *touch = [touches allObjects].firstObject;
    if (@available(iOS 9.0, *)) {
        _lastTouchForce = touch.force;
        [self.delegate imagePickerCell:self touchForce:touch.force maximumPossibleForce:touch.maximumPossibleForce];
    }
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesMoved:touches withEvent:event];
    UITouch *touch = [touches allObjects].firstObject;
    if (@available(iOS 9.0, *)) {
        _lastTouchForce = touch.force;
        [self.delegate imagePickerCell:self touchForce:touch.force maximumPossibleForce:touch.maximumPossibleForce];
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
    UITouch *touch = [touches allObjects].firstObject;
    if (@available(iOS 9.0, *)) {
        _lastTouchForce = touch.force;
        [self.delegate imagePickerCell:self touchForce:touch.force maximumPossibleForce:touch.maximumPossibleForce];
    }
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesCancelled:touches withEvent:event];
    UITouch *touch = [touches allObjects].firstObject;
    if (@available(iOS 9.0, *)) {
        _lastTouchForce = touch.force;
        [self.delegate imagePickerCell:self touchForce:touch.force maximumPossibleForce:touch.maximumPossibleForce];
    }
}

@end
