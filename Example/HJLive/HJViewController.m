//
//  HJViewController.m
//  HJLive
//
//  Created by HeJun on 08/09/2017.
//  Copyright (c) 2017 HeJun. All rights reserved.
//

#import "HJViewController.h"
#import "HJRTMPSession.h"

@interface HJViewController ()<HJRTMPSessionDelegate>

/** 连接服务器 */
- (IBAction)startConnect:(id)sender;

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
	HJRTMPSession *session = [HJRTMPSession defaultSession];
	session.delegate = self;
	[session connectWithUrl:[NSURL URLWithString:@"rtmp://192.168.1.253/rtmplive/aaa"]];
}

#pragma mark - delegate
- (void)session:(HJRTMPSession *)session withStatus:(HJRTMPSessionStatus)status {
	HJLog(@"%@", session);
}
@end
