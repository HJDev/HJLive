//
//  HJSteamSession.m
//  HJLive
//
//  Created by HeJun on 30/08/2017.
//  Copyright © 2017 HeJun. All rights reserved.
//

#import "HJStreamSession.h"

@interface HJStreamSession()<NSStreamDelegate>

/** 输入流 */
@property (nonatomic, strong) NSInputStream	 *inputStream;
/** 输出流 */
@property (nonatomic, strong) NSOutputStream *outputStream;

@end

@implementation HJStreamSession

- (instancetype)init {
	if (self = [super init]) {
		_streamStatus = NSStreamEventNone;
	}
	return self;
}

- (void)dealloc {
	[self close];
}

#pragma mark - public func
/**
 * 连接服务器
 */
- (void)connectToServerWithUrl:(NSURL *)url {
	if (self.streamStatus != NSStreamEventNone) {
		[self close];
	}
	
	//输入流
	CFReadStreamRef readStream = NULL;
	//输出流
	CFWriteStreamRef writeStream = NULL;
	//建立 socket 连接
	CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)(url.host), (UInt32)url.port.intValue, &readStream, &writeStream);
	
	//转换为 OC 对象,这里不能用__bridge,否则可能会造成内存泄漏
	//注意__bridge_transfer,转移对象的内存管理权
	_inputStream = (__bridge_transfer NSInputStream *)(readStream);
	_outputStream = (__bridge_transfer NSOutputStream *)(writeStream);
	
	//设置流代理
	_inputStream.delegate = self;
	_outputStream.delegate = self;
	
	//添加到 RunLoop(主循环)
	[_inputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
	[_outputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
	
	//打开流
	[_inputStream open];
	[_outputStream open];
}

/**
 * 关闭连接
 */
- (void)close {
	//关闭流
	[_inputStream close];
	[_outputStream close];
	//移出 RunLoop
	[_inputStream removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
	[_outputStream removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
	//重置状态
	_streamStatus = NSStreamEventNone;
	_inputStream.delegate = nil;
	_outputStream.delegate = nil;
	_inputStream = nil;
	_outputStream = nil;
}

/**
 * 读数据
 */
- (NSData *)readData {
	uint8_t buff[4096];//缓存区大小 4K
	NSUInteger length = [_inputStream read:buff maxLength:sizeof(buff)];
	NSData *data;
	if (length < sizeof(buff) && (_streamStatus & NSStreamEventHasBytesAvailable) == NSStreamEventHasBytesAvailable) {
		_streamStatus ^= NSStreamEventHasBytesAvailable;
		data = [NSData dataWithBytes:buff length:length];
	}
	return data;
}

/**
 * 写数据
 */
- (NSInteger)writeData:(NSData *)data {
	if (data.length == 0) {
		return 0;
	}
	
	NSInteger ret = 0;
	if (_outputStream.hasSpaceAvailable) {
		ret = [_outputStream write:data.bytes maxLength:data.length];
	}
	if (ret > 0 && (_streamStatus & NSStreamEventHasSpaceAvailable)) {
		//移除标志位
		_streamStatus ^= NSStreamEventHasSpaceAvailable;
	}
	return ret;
}

#pragma mark - NSStreamDelegate
- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
	switch (eventCode) {
		case NSStreamEventNone: {
			return;//此处是return
		}
		case NSStreamEventOpenCompleted: {
			if (_inputStream == aStream ) {
				HJLog(@"连接成功");
				_streamStatus = NSStreamEventOpenCompleted;
			}
			break;
		}
		case NSStreamEventHasBytesAvailable: {
			HJLog(@"有字节可读");
			_streamStatus |= NSStreamEventHasBytesAvailable;
			break;
		}
		case NSStreamEventHasSpaceAvailable: {
			HJLog(@"可以发送字节");
			_streamStatus |= NSStreamEventHasSpaceAvailable;
			break;
		}
		case NSStreamEventErrorOccurred: {
			HJLog(@"连接出现错误");
			_streamStatus = NSStreamEventErrorOccurred;
			break;
		}
		case NSStreamEventEndEncountered: {
			HJLog(@"连接结束");
			_streamStatus = NSStreamEventEndEncountered;
			break;
		}
	}
	
	if (self.streamDidChangeBlock) {
		self.streamDidChangeBlock(_streamStatus);
	}
}

@end
