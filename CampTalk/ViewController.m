//
//  ViewController.m
//  CampTalk
//
//  Created by LD on 2018/4/17.
//  Copyright © 2018年 yuru. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "CTChatTableViewController.h"
#import "CTChatListTableViewController.h"
#import "CTLoginViewController.h"
#import "CTTestViewController.h"

#import <RGUIKit/RGUIKit.h>
#import "YYFPSLabel.h"
#import "RGSocketIOManager.h"

@interface ViewController () <RGSocketIOManagerDelegate>

@property (nonatomic, strong) AVAudioPlayer *player;
@property (weak, nonatomic) IBOutlet UIImageView *corverImageView;
@property (weak, nonatomic) IBOutlet UIImageView *corverImageBgView;

@property (strong, nonatomic) UIWindow *fpsWindow;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[RGSocketIOManager shared] addDelegate:self];
    
    // Do any additional setup after loading the view, typically from a nib.
    
    self.rg_navigationController.barBackgroundStyle = RGNavigationBackgroundStyleShadow;
    self.rg_navigationController.tintColor = [UIColor whiteColor];
    
    NSString *imageName = [NSString stringWithFormat:@"corver%d.jpg", arc4random()%2];
    
    _corverImageView.image = [UIImage rg_imageWithName:imageName];
    _corverImageBgView.image = _corverImageView.image;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionMixWithOthers error:nil];
    
    NSURL *fileUrl = [[NSBundle mainBundle] URLForResource:@"linJiang" withExtension:@"m4a"];
    self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:fileUrl error:nil];
    
    if (self.player) {
        [self.player prepareToPlay];
    }
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(linJiang:)];
    [self.view addGestureRecognizer:tap];
    
    self.navigationItem.backBarButtonItem =
    [[UIBarButtonItem alloc] initWithTitle:@""
                                     style:UIBarButtonItemStylePlain
                                    target:self
                                    action:nil];
    
    self.navigationItem.leftBarButtonItem =
    [[UIBarButtonItem alloc] initWithTitle:@"Login"
                                     style:UIBarButtonItemStylePlain
                                    target:self
                                    action:@selector(login:)];
    [self presentViewController:[CTTestViewController new] animated:YES completion:nil];
    
    YYFPSLabel *label = [[YYFPSLabel alloc] init];
    RGWindow *window = [RGWindow windowWithViewController:self];
    [window setAddtionViewWillLayout:^(UIViewController * _Nonnull viewController, CGRect bounds) {
        RGLayout.shared.targetNext(label, bounds)
        .leading(10)
        .top(viewController.rg_layoutTopY + 44)
        .apply();
    }];
    [window showWithAddtionView:label animation:nil completion:nil];
}

- (void)linJiang:(id)sender {
    [self.player play];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)chat:(id)sender {
    CTChatListTableViewController *vc = [CTChatListTableViewController new];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)login:(id)sender {
    RGNavigationController *ngv = [RGNavigationController navigationWithRoot:[[CTLoginViewController alloc] initWithStyle:UITableViewStylePlain] style:RGNavigationBackgroundStyleAllTranslucent];
    ngv.tintColor = UIColor.blackColor;
    if (@available(iOS 13.0, *)) {
        ngv.modalInPresentation = YES;
    }
    [self rg_presentViewController:ngv animated:YES dismissOther:nil completion:nil];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

#pragma mark - RGSocketIOManagerDelegate

- (void)socketIOManager:(RGSocketIOManager *)manager on:(NSString *)event json:(id)json {
    [RGToastView showWithInfo:[json description] duration:3 percentY:0.7 viewController:self];
}

@end
