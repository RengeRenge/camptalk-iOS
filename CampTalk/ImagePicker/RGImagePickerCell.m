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
        [self.contentView addSubview:self.imageView];
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
    selected = [self.cache contain:self.asset];
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
        self.selectedButton.hidden = self.cache.maxCount > 1 && self.cache.isFull;
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

- (void)setAsset:(PHAsset *)asset targetSize:(CGSize)targetSize cache:(RGImagePickerCache *)cache {
    self.cache = cache;
    if (self.asset == asset || [self isCurrentAsset:asset]) {
        return;
    }
    self.asset = asset;
    
    void(^didLoadImage)(UIImage *result) = ^(UIImage *result) {
        if (![self isCurrentAsset:asset]) {
            return;
        }
        self.imageView.image = result;
        [RGImagePickerCell needLoadWithAsset:asset result:^(BOOL needLoadWithAsset) {
            if (![self isCurrentAsset:asset]) {
                return;
            }
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            if (needLoadWithAsset) {
                self.selectedLayer.strokeEnd = asset.rgLoadLargeImageProgress;
            } else {
                self.selectedLayer.strokeEnd = 1.f;
            }
            [CATransaction commit];
            
            if (needLoadWithAsset) {
                self.imageViewMask.backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.6];
            } else {
                self.imageViewMask.backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.0];
            }
            
            if (self.asset == asset) {
                if (self.imageView.image != result) {
                    self.imageView.image = result;
                }
            }
        }];
    };
    
    // 因为加载完成的状态可以同步获得，所以先默认显示为未加载完成的状态，防止闪烁
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.imageViewMask.backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.6];
    self.selectedLayer.strokeEnd = 0;
    [CATransaction commit];
    
    [cache imageForAsset:asset onlyCache:NO syncLoad:NO allowNet:NO targetSize:targetSize completion:^(UIImage * _Nonnull image) {
        didLoadImage(image);
    }];
}

- (BOOL)isCurrentAsset:(PHAsset *)asset {
    return self.asset == asset || [self.asset.localIdentifier isEqualToString:asset.localIdentifier];
}

+ (void)needLoadWithAsset:(PHAsset *)asset result:(void(^)(BOOL needLoad))result {
    [RGImagePicker needLoadWithAsset:asset result:result];
}

+ (void)loadOriginalWithAsset:(PHAsset *)asset updateCell:(RGImagePickerCell * _Nullable)cell collectionView:(UICollectionView *)collectionView progressHandler:(void (^ _Nullable)(double))progressHandler completion:(void (^ _Nullable)(NSData * _Nullable, NSError * _Nullable))completion {
    __block RGImagePickerCell *bCell = cell;
    [RGImagePicker loadResourceFromAsset:asset progressHandler:^(double progress) {
        if (progressHandler) {
            progressHandler(progress);
        }
        if (![bCell isCurrentAsset:asset]) {
            bCell = nil;
            [[collectionView visibleCells] enumerateObjectsUsingBlock:^(__kindof UICollectionViewCell * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                RGImagePickerCell *findCell = obj;
                if ([findCell isCurrentAsset:asset]) {
                    bCell = findCell;
                    *stop = YES;
                }
            }];
        }
        bCell.selectedLayer.strokeEnd = progress;
    } completion:^(NSData * _Nullable imageData, NSError * _Nullable error) {
        if (completion) {
            completion(imageData, error);
        }
        if (![bCell isCurrentAsset:asset]) {
            bCell = nil;
            [[collectionView visibleCells] enumerateObjectsUsingBlock:^(__kindof UICollectionViewCell * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                RGImagePickerCell *findCell = obj;
                if ([findCell isCurrentAsset:asset]) {
                    bCell = findCell;
                    *stop = YES;
                }
            }];
        }
        if (error) {
            asset.rgIsLoaded = NO;
            bCell.imageViewMask.backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.6];
        } else {
            asset.rgIsLoaded = YES;
            bCell.imageViewMask.backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.0];
        }
        bCell.selectedLayer.strokeEnd = asset.rgIsLoaded ? 1 : 0;
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
