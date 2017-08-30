//
//  HJViewController.m
//  HJLive
//
//  Created by HeJun on 08/09/2017.
//  Copyright (c) 2017 HeJun. All rights reserved.
//

#import "HJViewController.h"
#import "HJLiveManager.h"

@interface HJViewController ()

@property (nonatomic, strong) HJLiveManager *manager;
/** 连接服务器 */
- (IBAction)startConnect:(id)sender;
- (IBAction)disConnect:(id)sender;

@end

@implementation HJViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)startConnect:(id)sender {
	
	HJLiveManager *manager = [HJLiveManager defaultManager];
	[manager setLiveStatusChangedBlock:^(HJLiveStatus liveStatus) {
		HJLog(@"liveStatus : %ld", liveStatus);
	}];
	manager.rtmpUrl = [NSURL URLWithString:@"rtmp://192.168.1.253:1935/rtmplive/aaa"];
	[manager start];
	self.manager = manager;
}

- (IBAction)disConnect:(id)sender {
	self.manager = nil;
}

@end
