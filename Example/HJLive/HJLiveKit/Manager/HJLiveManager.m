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

#pragma mark - lazyload
- (HJRtmpSession *)rtmpSession {
	if (_rtmpSession == nil) {
		_rtmpSession = [HJRtmpSession new];
		
		HJRtmpConfig *config = [HJRtmpConfig new];
		config.url = self.rtmpUrl;
		_rtmpSession.config = config;
	}
	return _rtmpSession;
}


@end
