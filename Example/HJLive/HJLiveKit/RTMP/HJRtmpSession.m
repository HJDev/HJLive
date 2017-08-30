//
//  HJRTMPSession.m
//  HJLive
//
//  Created by HeJun on 11/08/2017.
//  Copyright © 2017 HeJun. All rights reserved.
//

#import "HJRtmpSession.h"
#import "HJRtmpConfig.h"
#import "HJStreamSession.h"
#import "HJBufferFrame.h"
#import "HJRtmpTypes.h"
#import "NSMutableData+Buffer.h"

@interface HJRtmpSession()<NSStreamDelegate> {
	//组装数据线程
	dispatch_queue_t _packetQueue;
	//发送数据线程
	dispatch_queue_t _sendQueue;
	//分包大小(默认大小为128)
	int _outChunkSize;
	int _inChunkSize;
	//流ID
	int _streamID;
	int _numOfInvokes;
}

/** 流管理器 */
@property (nonatomic, strong) HJStreamSession *streamSession;
/** rmtp 状态 */
@property (nonatomic, assign) HJRtmpSessionStatus rtmpStatus;
@property (nonatomic, strong) NSMutableData *handshake;
@property (nonatomic, strong) NSMutableDictionary *preChunk;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSString *> *trackedCommands;

@end

@implementation HJRtmpSession

- (instancetype)init {
	if (self = [super init]) {
		_rtmpStatus = HJRtmpSessionStatusNormal;
		_packetQueue = dispatch_queue_create("packet", 0);
		_sendQueue = dispatch_queue_create("send", 0);
		
		_outChunkSize = 128;
		_inChunkSize = 128;
	}
	return self;
}

- (void)dealloc {
	self.statusChangedBlock = nil;
	self.streamSession.streamDidChangeBlock = nil;
	self.streamSession = nil;
	_packetQueue = nil;
	_sendQueue = nil;
	_rtmpStatus = HJRtmpSessionStatusNormal;
	_numOfInvokes = 0;
	[_preChunk removeAllObjects];
	[_trackedCommands removeAllObjects];
	_config = nil;
}

#pragma mark - public func
+ (instancetype)defaultSession {
	return [self new];
}

- (void)connect {
	[self.streamSession connectToServerWithUrl:self.config.url];
}

- (void)disConnect {
	[self reset];
	[self.streamSession close];
}

- (void)sendBuffer:(HJBufferFrame *)bufferFrame {
	HJWeakSelf;
	dispatch_sync(_packetQueue, ^{
		uint64_t timestamp = bufferFrame.timestamp;
		int streamId = bufferFrame.msgSteamId;
		NSNumber *preTimestamp = weakSelf.preChunk[@(streamId)];
		
		uint8_t *chunk = NULL;
		int offset = 0;
		
		if (preTimestamp == nil) {
			//第一帧,音频或者视频
			chunk = malloc(12);
			chunk[0] = RTMP_CHUNK_TYPE_0/*0x00*/ | (streamId & 0x1F); //前两个字节 00 表示12字节
			offset += 1;
			
			memcpy(chunk+offset, [NSMutableData be24:(uint32_t)timestamp], 3);
			offset += 3;//时间戳3个字节
			
			memcpy(chunk+offset, [NSMutableData be24:bufferFrame.msgLength], 3);
			offset += 3;//消息长度3个字节
			
			int msgTypeId = bufferFrame.msgTypeId;//一个字节的消息类型
			memcpy(chunk+offset, &msgTypeId, 1);
			offset += 1;
			
			memcpy(chunk+offset, (uint8_t *)&(_streamID), sizeof(_streamID));
			offset += sizeof(_streamID);
		} else {
			//不是第一帧
			chunk = malloc(8);
			chunk[0] = RTMP_CHUNK_TYPE_1/*0x40*/ | (streamId & 0x1F);//前两个字节01表示8字节
			offset += 1;
			
			char *temp = [NSMutableData be24:(uint32_t)(timestamp - preTimestamp.integerValue)];
			memcpy(chunk+offset, temp, 3);
			offset += 3;
			
			memcpy(chunk+offset, [NSMutableData be24:bufferFrame.msgLength], 3);
			offset += 3;
			
			int msgTypeId = bufferFrame.msgTypeId;
			memcpy(chunk+offset, &msgTypeId, 1);
			offset += 1;
		}
		
		weakSelf.preChunk[@(streamId)] = @(timestamp);
		
		uint8_t *bufferData = (uint8_t *)bufferFrame.data.bytes;
		uint8_t *output = (uint8_t *)malloc(bufferFrame.data.length + 64);
		memcpy(output, chunk, offset);
		free(chunk);
		
		NSUInteger total = bufferFrame.data.length;
		NSInteger step = MIN(total, _outChunkSize);
		
		memcpy(output + offset, bufferData, step);
		offset += step;
		total -= step;
		bufferData += step;
		
		while (total > 0) {
			step = MIN(total, _outChunkSize);
			bufferData[-1] = RTMP_CHUNK_TYPE_3 | (streamId & 0x1F);//11表示一个字节,直接跳过这个字节;
			memcpy(output + offset, bufferData - 1, step + 1);
			
			offset += step + 1;
			total -= step;
			bufferData += step;
		}
		
		NSData *sendData = [NSData dataWithBytes:output length:offset];
		free(output);
		[weakSelf writeData:sendData];
	});
}

#pragma mark - private func
- (void)reset {
	_handshake = nil;
	_preChunk = nil;
	_trackedCommands = nil;
	
	_streamID = 0;
	_numOfInvokes = 0;
	_inChunkSize = 128;
	_outChunkSize = 128;
	self.rtmpStatus = HJRtmpSessionStatusNormal;
}

- (void)writeData:(NSData *)data {
	if (data.length == 0) {
		return;
	}
	
	[self.streamSession writeData:data];
}

#pragma mark - lazyload
- (HJStreamSession *)streamSession {
	if (_streamSession == nil) {
		_streamSession = [HJStreamSession new];
		[_streamSession setStreamDidChangeBlock:^(NSStreamEvent status) {
			HJLog(@"status : %ld", status);
		}];
	}
	return _streamSession;
}

- (NSMutableData *)handshake {
	if (_handshake == nil) {
		_handshake = [NSMutableData new];
	}
	return _handshake;
}

- (NSMutableDictionary *)preChunk {
	if (_preChunk == nil) {
		_preChunk = [NSMutableDictionary dictionary];
	}
	return _preChunk;
}

- (NSMutableDictionary<NSNumber *,NSString *> *)trackedCommands {
	if (_trackedCommands == nil) {
		_trackedCommands = [NSMutableDictionary<NSNumber *, NSString *> new];
	}
	return _trackedCommands;
}

@end
