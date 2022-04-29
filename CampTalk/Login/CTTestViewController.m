//
//  CTTestViewController.m
//  CampTalk
//
//  Created by renge on 2019/10/24.
//  Copyright © 2019 yuru. All rights reserved.
//

#import "CTTestViewController.h"
#import "RGSocketIOManager.h"

@interface CTTestViewController () <RGSocketIOManagerDelegate>

@end

@implementation CTTestViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:146.f/255.f green:224.f/255.f blue:205.f/255.f alpha:1.f];
    
    [[RGSocketIOManager shared] addDelegate:self];
    [[RGSocketIOManager shared] startWithToken:@"1234567890"];

    [[RGSocketIOManager shared] requestUrl:@"friends/list" data:nil response:^(int code, id  _Nullable response) {
        if (code == 200) {
            NSArray *list = response[@"list"];
            NSLog(@"%@", list);
        } else if (code == 408) {
            NSLog(@"time out");
        } else if (code == 401) {
            NSLog(@"logout");
        }
    }];
}

#pragma mark - RGSocketIOManagerDelegate

- (void)socketIOManager:(RGSocketIOManager *)manager on:(NSString *)event json:(id)json {
    NSLog(@"Did On -------->\nEvent:「%@」\njson: %@\n<---------\n", event, json);
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
