//
//  CTChatTableViewCell.m
//  CampTalk
//
//  Created by kikilee on 2018/4/20.
//  Copyright © 2018年 yuru. All rights reserved.
//

#import "CTChatTableViewCell.h"
#import <RGUIKit/RGUIKit.h>
#import "RGBubbleView.h"
#import <FLAnimatedImageView+RGWrapper.h>
#import "JYWaveView.h"

static CGSize _maxIconSize = {40, 40};
static CGFloat _chatCelIIconWidth = 40;

static CGFloat _margin = 15;
static CGFloat _marginBubble = 4.f;

static CGFloat _marginTop = 20;

NSString * const CTChatTableViewCellId = @"kCTChatTableViewCellId";

@interface CTChatTableViewCell () <CAAnimationDelegate>

@property (weak, nonatomic) IBOutlet UIImageView *iconView;
@property (nonatomic, strong) JYWaveView *waveView;

@property (nonatomic, copy) void(^lookMeBlock)(BOOL);

@end

@implementation CTChatTableViewCell

+ (void)registerForTableView:(UITableView *)tableView {
    [tableView registerNib:[UINib nibWithNibName:NSStringFromClass([self class]) bundle:[NSBundle mainBundle]] forCellReuseIdentifier:CTChatTableViewCellId];
}

- (void)awakeFromNib {
    [super awakeFromNib];
    self.chatBubbleLabel.layer.anchorPoint = CGPointMake(0, 1);
    self.thumbWapper.layer.anchorPoint = CGPointMake(0, 1);
    
    UILongPressGestureRecognizer *longTap = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onItemLongTap:)];
    [self.chatBubbleLabel addGestureRecognizer:longTap];
    
    longTap = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onItemLongTap:)];
    self.thumbWapper.userInteractionEnabled = YES;
    [self.thumbWapper addGestureRecognizer:longTap];
}

- (JYWaveView *)waveView {
    if (!_waveView) {
        _waveView = [[JYWaveView alloc] initWithFrame:self.thumbWapper.bounds];
        _waveView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        _waveView.frontColor = [[UIColor whiteColor] colorWithAlphaComponent:0.7];
        _waveView.insideColor = [[UIColor whiteColor] colorWithAlphaComponent:0.3];
        _waveView.frontSpeed = 0.05;
        _waveView.insideSpeed = 0.05*1.2;
        _waveView.waveBottomWillToHeight = 20;
        _waveView.waveHeight = 10;
        _waveView.directionType = WaveDirectionTypeFoward;
        [self.thumbWapper.backgroundView addSubview:_waveView];
    }
    return _waveView;
}

- (void)setIconImage:(UIImage *)iconImage {
    _iconImage = iconImage;
    self.iconView.image = _iconImage;
}

- (void)setLoadThumbProresss:(CGFloat)loadThumbProresss {
    loadThumbProresss = MIN(loadThumbProresss, 1);
    _loadThumbProresss = loadThumbProresss;
    if (self.isLookMe) {
        self.thumbWapper.backgroundView.backgroundColor = [UIColor clearColor];
        return;
    }
    if (self.displayThumb && !self.displayLocalThumb) {
        if (_loadThumbProresss >= 1) {
            return;
        }
        self.waveView.alpha = 1;
        self.thumbWapper.imageView.alpha = 0;
        self.waveView.waveBottomWillToHeight = self.thumbWapper.imageView.bounds.size.height*loadThumbProresss;
        [self.waveView strat];
        self.thumbWapper.backgroundView.backgroundColor = [UIColor clearColor];
    }
}

- (void)doAnimateOnLoadImageFinishIfNeed {
    if (!_displayThumb || _displayLocalThumb) {
        return;
    }
    CGFloat loadThumbProresss = self.loadThumbProresss;
    [UIView animateWithDuration:1.f animations:^{
        self.waveView.alpha = 0;
        self.thumbWapper.imageView.alpha = 1;
        self.thumbWapper.backgroundView.backgroundColor = [UIColor whiteColor];
    } completion:^(BOOL finished) {
        if (loadThumbProresss == self->_loadThumbProresss) {
            [self.waveView stop];
        }
    }];
}

- (void)setDisplayThumb:(BOOL)displayThumb {
    if (_displayThumb == displayThumb) {
        return;
    }
    _displayThumb = displayThumb;
    [self setNeedsLayout];
}

- (void)setDisplayLocalThumb:(BOOL)displayLocalThumb {
    if (_displayLocalThumb == displayLocalThumb) {
        return;
    }
    _displayLocalThumb = displayLocalThumb;
    if (displayLocalThumb) {
        self.thumbWapper.backgroundView.backgroundColor = [UIColor whiteColor];
    }
    [self setNeedsLayout];
}

- (void)setMyDirection:(BOOL)myDirection {
    if (_myDirection == myDirection) {
        return;
    }
    _myDirection = myDirection;
    self.chatBubbleLabel.bubbleRightToLeft = myDirection;
    self.thumbWapper.bubbleRightToLeft = myDirection;
    [UIView performWithoutAnimation:^{
        if (myDirection) {
            self.iconView.transform = CGAffineTransformMakeScale(-1, 1);
        } else {
            self.iconView.transform  = CGAffineTransformMakeScale(1, 1);
        }
    }];
    [self.contentView setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    if (!_displayThumb || _displayLocalThumb) {
        self.waveView.waveBottomWillToHeight = 0;
        self.waveView.waveBottomCurrentHeight = 0;
        [self.waveView stop];
    }
    
    CGRect bounds = self.contentView.bounds;
    CGFloat height = bounds.size.height;
    
    // 头像布局，头像宽不超出 _chatCelIIconWidth，高度不超出父视图的高度，否则按比例缩放头像至全部显示
    
    CGSize iconSize = [CTChatTableViewCell imageSizeThatFits:CGSizeMake(_chatCelIIconWidth, height) imageSize:self.iconView.image.rg_logicSize];
    
    self.iconView.frame =
    CGRectMake(
               _margin + (_chatCelIIconWidth - iconSize.width) / 2.f,
               bounds.size.height - iconSize.height,
               iconSize.width,
               iconSize.height
               );
    
    CGRect contentBounds = UIEdgeInsetsInsetRect(bounds, UIEdgeInsetsMake(0, _chatCelIIconWidth + _margin + _marginBubble, 0, _chatCelIIconWidth + _margin));
    
    if (self.displayThumb) {
        //图片布局
        CGSize thumbLogicSize = [UIImage rg_logicSizeWithPixSize:self.thumbPixSize];
        
        CGSize size = [CTChatTableViewCell imageSizeThatFits:CGSizeMake(contentBounds.size.width, height - [self.class imageSizeHeightExt]) imageSize:thumbLogicSize];
        
        size = [self.thumbWapper setBoundsWithImageSize:size].size;
        size.width = MIN(size.width, contentBounds.size.width);
        contentBounds.size = size;
        contentBounds.origin.y = bounds.size.height - contentBounds.size.height;
        self.thumbWapper.frame = contentBounds;
        self.waveView.waveBottomWillToHeight = self.thumbWapper.bounds.size.height*self.loadThumbProresss;
        
        self.chatBubbleLabel.hidden = YES;
        self.thumbWapper.hidden = NO;
    } else {
        
        //文字布局
        CGSize labelSize = [self.chatBubbleLabel sizeThatFits:contentBounds.size];
//        if (bounds.size.height - _maxIconSize.height - _marginTop < 1e-7) {
//            labelSize = [self.chatBubbleLabel sizeThatFits:bounds.size];
//        } else {
//            labelSize = bounds.size;
//            labelSize.height -= _marginTop;
//        }
        
        contentBounds.origin.y = contentBounds.size.height - labelSize.height;
        contentBounds.size = labelSize;
        self.chatBubbleLabel.frame = contentBounds;
        
        self.chatBubbleLabel.hidden = NO;
        self.thumbWapper.hidden = YES;
    }
    
    if (self.myDirection) {
        [self.contentView.subviews enumerateObjectsUsingBlock:^(__kindof UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [obj rg_setFrameToFitRTL];
        }];
    }
}

//- (BOOL)displayThumb {
//    return self.thumbView.image != nil;
//}

+ (CGSize)imageSizeThatFits:(CGSize)size imageSize:(CGSize)imageSize {
    
    CGFloat scale = size.width / imageSize.width;
    if (scale < 1.f) {
        if (imageSize.height * scale > size.height) {
            scale = size.height / imageSize.height;
        }
        imageSize.height *= scale;
        imageSize.width *= scale;
    } else {
        scale = size.height / imageSize.height;
        if (scale < 1.f) {
            if (imageSize.width * scale > size.width) {
                scale = size.width / imageSize.width;
            }
            imageSize.height *= scale;
            imageSize.width *= scale;
        }
    }
    if (imageSize.height != 0 && imageSize.height < 40) {
        scale = 40 / imageSize.height;
        imageSize.height *= scale;
        imageSize.width *= scale;
    }
    return imageSize;
}

+ (CGFloat)heightWithText:(NSString *)string tableView:(UITableView *)tableView {
    
    CGSize size = CGSizeMake(tableView.frame.size.width, CGFLOAT_MAX);
    size.width -= (_maxIconSize.width + _margin * 2 + _marginBubble);
    
    CGFloat height = [CTChatBubbleLabel heightWithString:string fits:size].height;
    height = MAX(height, _maxIconSize.height);
    height += _marginTop;
    return height;
}

+ (CGFloat)estimatedHeightWithText:(NSString *)string tableView:(UITableView *)tableView {
    // Size 25 * 25
    return (string.length * 25.f) / (tableView.frame.size.width - _maxIconSize.width - _margin * 2 - _marginBubble) * 25;
}

+ (CGFloat)heightWithThumbSize:(CGSize)thumbSize tableView:(UITableView *)tableView {
    
    thumbSize = [UIImage rg_logicSizeWithPixSize:thumbSize];
    
    CGSize fits = CGSizeMake((tableView.frame.size.width - 2 * _maxIconSize.width - _margin * 2 - _marginBubble), 200.f);
    fits.width = MIN(fits.width, tableView.frame.size.width/2.f);
    
    fits.height = [self imageSizeThatFits:fits imageSize:thumbSize].height;
    fits.height = MAX(fits.height, _maxIconSize.height);
    
    return fits.height + [self imageSizeHeightExt];
}

+ (CGFloat)imageSizeHeightExt {
    UIEdgeInsets bubbleInset = [CTBubbleImageView contentViewEdgeWithRightToLeft:NO];
    return _marginTop + bubbleInset.bottom + bubbleInset.top;
}

- (BOOL)isLookMe {
    if ([self.chatBubbleLabel.layer animationForKey:@"transformAnimation"]) {
        return YES;
    }
    if ([self.thumbWapper.layer animationForKey:@"transformAnimation"]) {
        return YES;
    }
    return NO;
}

- (void)lookMe:(void (^)(BOOL))completion {
    // Configure the view for the selected state
    if (self.isLookMe) {
        void(^lookMeBlock)(BOOL) = self.lookMeBlock;
        self.lookMeBlock = nil;
        [self.thumbWapper.layer removeAllAnimations];
        [self.chatBubbleLabel.layer removeAllAnimations];
        if (lookMeBlock) {
            lookMeBlock(NO);
        }
    }
    [self.waveView stop];
    
    UIView *animateView = self.displayThumb ? self.thumbWapper : self.chatBubbleLabel;
    
    CGRect frame = animateView.frame;
    CGFloat scale;
    if (frame.size.height < frame.size.width) {
        scale = MIN((frame.size.height + 5.f) / frame.size.height, 1.1f);
    } else {
        scale = MIN((frame.size.width + 5.f) / frame.size.width, 1.1f);
    }
    
    CABasicAnimation *transformAnimation = [CABasicAnimation animationWithKeyPath:@"transform"];
    transformAnimation.toValue = [NSValue valueWithCATransform3D:CATransform3DMakeScale(scale, scale, 1.0)];
//    transformAnimation.beginTime = CACurrentMediaTime();
    transformAnimation.duration = 0.35f;
    transformAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    transformAnimation.removedOnCompletion = YES;
    transformAnimation.autoreverses = YES;
    transformAnimation.delegate = self;
    
    if (_myDirection) {
        CGPoint position = animateView.layer.position;
        position.x = CGRectGetMaxX(animateView.frame);
        animateView.layer.anchorPoint = CGPointMake(1, 1);
        animateView.layer.position = position;
    } else {
        CGPoint position = animateView.layer.position;
        position.x = CGRectGetMinX(animateView.frame);
        animateView.layer.anchorPoint = CGPointMake(0, 1);
        animateView.layer.position = position;
    }
    [animateView.layer addAnimation:transformAnimation forKey:@"transformAnimation"];
    __weak typeof(self) wSelf = self;
    self.lookMeBlock = ^(BOOL flag) {
        completion(flag);
        wSelf.loadThumbProresss = wSelf.loadThumbProresss;
    };
}

- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag {
    if (![anim isKindOfClass:[CABasicAnimation class]]) {
        return;
    }
    [self.thumbWapper.layer removeAllAnimations];
    [self.chatBubbleLabel.layer removeAllAnimations];
    if (self.lookMeBlock) {
        void(^lookMeBlock)(BOOL) = self.lookMeBlock;
        self.lookMeBlock = nil;
        lookMeBlock(NO);
    }
}

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(copy:)){
        return YES;
    }
//    if (action == @selector(select:)){
//        return YES;
//    }
    if (action == @selector(delete:)){
        return YES;
    }
    if (action == @selector(_lookup:)){
        return YES;
    }
    if (action == @selector(_share:)){
        return YES;
    }
    return NO;
}

- (void)copy:(id)sender {
    UIPasteboard *pboard = [UIPasteboard generalPasteboard];
    if (self.displayThumb) {
        pboard.image = self.thumbWapper.image;
    } else {
        pboard.string = self.chatBubbleLabel.label.text;
    }
}

- (void)delete:(id)sender {
    if ([self.delegate respondsToSelector:@selector(deleteChatTableViewCell:)]) {
        [self.delegate deleteChatTableViewCell:self];
    }
}

- (void)_lookup:(id)sender {
    if ([self.delegate respondsToSelector:@selector(lookupChatTableViewCell:)]) {
        [self.delegate lookupChatTableViewCell:self];
    }
}

- (void)_share:(id)sender {
    if ([self.delegate respondsToSelector:@selector(lookupChatTableViewCell:)]) {
        [self.delegate shareChatTableViewCell:self];
    }
}

- (void)onItemLongTap:(UILongPressGestureRecognizer *)sender {
    switch (sender.state) {
        case UIGestureRecognizerStateBegan:{
            
            [self becomeFirstResponder];
            
            UIMenuController *menu = [UIMenuController sharedMenuController];
            menu.menuItems = @[];
            
            [menu setTargetRect:sender.view.bounds inView:sender.view];
            menu.arrowDirection = UIMenuControllerArrowDefault;
            [menu update];
            [menu setMenuVisible:YES animated:YES];
            break;
        }
        default:
            break;
    }
}

//- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
//    [super setSelected:selected animated:animated];
//    if (!selected) {
//        return;
//    }
//}

//- (void)prepareForReuse {
//    [super prepareForReuse];
//    self.thumbView.image = nil;
//    self.chatBubbleLabel.label.text = nil;
//    [self setNeedsLayout];
//}

//- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
//    UIView *hitView = [super hitTest:point withEvent:event];
//    if (hitView == self || hitView == self.contentView) {
//        return nil;
//    }
//    return hitView;
//}

@end
