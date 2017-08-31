//
//  HJLiveManager.m
//  HJLive
//
//  Created by HeJun on 30/08/2017.
//  Copyright © 2017 HeJun. All rights reserved.
//

#import "HJLiveManager.h"

#import "HJRtmpSession.h"
#import "HJRtmpConfig.h"

@interface HJLiveManager()

@property (nonatomic, strong) HJRtmpSession *rtmpSession;

@end

@implementation HJLiveManager

- (instancetype)init {
	if (self = [super init]) {
		_liveStatus = HJLiveStatusNone;
	}
	return self;
}

- (void)dealloc {
	self.rtmpSession.statusChangedBlock = nil;
	self.rtmpSession = nil;
}

+ (instancetype)defaultManager {
	return [self new];
}

- (void)start {
	[self.rtmpSession connect];
}

- (void)end {
	[self.rtmpSession disConnect];
}

/**
 * 处理 rtmp 会话状态信息
 */
- (void)handleRtmpSessionStatus:(HJRtmpSessionStatus)status {
	if (status == HJRtmpSessionStatusConnected) {
		_liveStatus = HJLiveStatusConnecting;
	} else if (status == HJRtmpSessionStatusStarted) {
		_liveStatus = HJLiveStatusConnected;
	} else if (status == HJRtmpSessionStatusFailed) {
		_liveStatus = HJLiveStatusConnectFail;
	} else if (status == HJRtmpSessionStatusNotConnected) {
		_liveStatus = HJLiveStatusDisConnected;
	}
	
	if (self.liveStatusChangedBlock) {
		self.liveStatusChangedBlock(_liveStatus);
	}
}

#pragma mark - lazyload
- (HJRtmpSession *)rtmpSession {
	if (_rtmpSession == nil) {
		_rtmpSession = [HJRtmpSession new];
		
		HJRtmpConfig *config = [HJRtmpConfig new];
		config.url = self.rtmpUrl;
		_rtmpSession.config = config;
		HJWeakSelf;
		[_rtmpSession setStatusChangedBlock:^(HJRtmpSessionStatus status) {
			HJLog(@"status : %ld", status);
			[weakSelf handleRtmpSessionStatus:status];
		}];
	}
	return _rtmpSession;
}


@end
