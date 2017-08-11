//
//  HJRTMPSession.m
//  HJLive
//
//  Created by HeJun on 11/08/2017.
//  Copyright © 2017 HeJun. All rights reserved.
//

#import "HJRTMPSession.h"

@interface HJRTMPSession()<NSStreamDelegate>

/** 当前流事件状态 */
@property (nonatomic, assign) NSStreamEvent streamEvent;
/** 输入流 */
@property (nonatomic, strong) NSInputStream *inputStream;
/** 输出流 */
@property (nonatomic, strong) NSOutputStream *outputStream;

@end

@implementation HJRTMPSession

+ (instancetype)defaultSession {
	static HJRTMPSession *session;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		session = [self new];
		session.streamEvent = NSStreamEventNone;
	});
	return session;
}

- (void)connectWithUrl:(NSURL *)url {
	if (url == nil) {
		return;
	}
	if (self.streamEvent != NSStreamEventNone) {
		[self close];
	}
	
	[self connectToServerWithUrl:url];
}

- (void)disConnect {
	[self close];
}

- (void)sendBuffer:(HJBufferFrame *)buffer {
	
}

#pragma mark - private func
/**
 * 连接到服务器
 */
- (void)connectToServerWithUrl:(NSURL *)url {
	//输入流
	CFReadStreamRef readStream = NULL;
	//输出流
	CFWriteStreamRef writeStream = NULL;
	CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, (__bridge CFStringRef)(url.absoluteString), (UInt32)url.port, &readStream, &writeStream);
	
	//转换成 OC 对象
	self.inputStream = (__bridge NSInputStream *)(readStream);
	self.outputStream = (__bridge NSOutputStream *)(writeStream);
	
	//设置代理
	self.inputStream.delegate = self;
	self.outputStream.delegate = self;
	
	//添加到 Runloop
	[self.inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
	[self.outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
	
	//打开输入输出流
	[self.inputStream open];
	[self.outputStream open];
}

/**
 * 断开与服务器连接
 */
- (void)close {
	//移出 Runloop
	[self.inputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
	[self.outputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
	//关闭流
	[self.inputStream close];
	[self.outputStream close];
	//重置状态
	self.streamEvent = NSStreamEventNone;
	self.inputStream.delegate = nil;
	self.outputStream.delegate = nil;
	self.inputStream = nil;
	self.outputStream = nil;
}

#pragma mark - delegate
- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
	HJLog(@"%@", aStream);
}

@end
