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
#import "NSURL+HJ.h"

static const size_t kRTMPSignatureSize = 1536;

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

- (void)handleStreamEvent:(NSStreamEvent)event {
	if ((event & NSStreamEventHasBytesAvailable) == NSStreamEventHasBytesAvailable) {
		//收到数据
		HJLog(@"收到数据");
		[self didReceivedData];
		return;
	} else if ((event & NSStreamEventHasSpaceAvailable) == NSStreamEventHasSpaceAvailable) {
		//可以写数据
		HJLog(@"可以写数据");
		if (_rtmpStatus == HJRtmpSessionStatusConnected) {
			[self handShake0];
		}
		return;
	}
	
	if ((event & NSStreamEventOpenCompleted) == NSStreamEventOpenCompleted
		&& _rtmpStatus < HJRtmpSessionStatusConnected) {
		_rtmpStatus = HJRtmpSessionStatusConnected;
	}
	if ((event & NSStreamEventErrorOccurred) == NSStreamEventErrorOccurred) {
		_rtmpStatus = HJRtmpSessionStatusFailed;
	}
	if ((event & NSStreamEventEndEncountered) == NSStreamEventEndEncountered) {
		_rtmpStatus = HJRtmpSessionStatusNotConnected;
	}
}

#pragma mark - handshake
- (void)handShake0 {
	self.rtmpStatus = HJRtmpSessionStatusHandshake0;
	
	//c0
	char c0Byte = 0x03;
	NSData *c0data = [NSData dataWithBytes:&c0Byte length:1];
	[self writeData:c0data];
	
	//c1
	uint8_t *c1Byte = malloc(kRTMPSignatureSize);
	memset(c1Byte, 0, 4 + 4);
	NSData *c1data = [NSData dataWithBytes:c1Byte length:kRTMPSignatureSize];
	free(c1Byte);
	[self writeData:c1data];
}

- (void)handShake1 {
	self.rtmpStatus = HJRtmpSessionStatusHandshake2;
	
	//获取 c2
	NSData *s1 = [self.handshake subdataWithRange:NSMakeRange(0, kRTMPSignatureSize)];
	
	uint8_t *c2Byte = (uint8_t *)s1.bytes;
	memset(c2Byte + 4, 0, 4);
	NSData *c2data = [NSData dataWithBytes:c2Byte length:s1.length];
	[self writeData:c2data];
	
}

- (void)didReceivedData {
	NSData *data = [self.streamSession readData];
	
	if (self.rtmpStatus == HJRtmpSessionStatusConnected ||
		self.rtmpStatus == HJRtmpSessionStatusHandshake0 ||
		self.rtmpStatus == HJRtmpSessionStatusHandshake1 ||
		self.rtmpStatus == HJRtmpSessionStatusHandshake2) {
		[self.handshake appendData:data];
	}
	
	//handshke 可能情况:
	//1.按照官方文档c0,c1,c2
	//2.一起发3073个字节
	//3.先发一部分,再发一部分,每部分大小不确定,总数3073正确
	
	switch (_rtmpStatus) {
		case HJRtmpSessionStatusHandshake0: {
			uint8_t s0;
			[data getBytes:&s0 length:1];
			if (s0 == 0x03) {
				//是 s0 返回数据
				self.rtmpStatus = HJRtmpSessionStatusHandshake1;
				if (data.length > 1) {
					//还有数据，但长度未知
					data = [data subdataWithRange:NSMakeRange(1, data.length - 1)];
					self.handshake = data.mutableCopy;
				} else {
					break;
				}
			} else {
				HJLog(@"握手失败");
				break;
			}
		}
		case HJRtmpSessionStatusHandshake1: {
			if (self.handshake.length >= kRTMPSignatureSize) {
				//s1 返回的数据
				[self handShake1];//在某些情况不发也可以获得成功
				
				if (self.handshake.length > kRTMPSignatureSize) {
					//大于的情况
					NSData *subData = [data subdataWithRange:NSMakeRange(kRTMPSignatureSize, self.handshake.length - kRTMPSignatureSize)];
					self.handshake = [subData mutableCopy];
				} else {
					//等于的情况
					self.handshake = [NSMutableData mutableCopy];
				}
			} else {
				//小于的情况
				break;
			}
		}
		case HJRtmpSessionStatusHandshake2: {
			if (data.length >= kRTMPSignatureSize) {
				//握手完成
				self.rtmpStatus = HJRtmpSessionStatusHandshakeComplete;
				
				[self sendConnectPacket];
			}
		}
			break;
			
		default:
			[self parseData:data];
			break;
	}
}

/**
 * 发送建立了连接的包给服务器
 */
- (void)sendConnectPacket {
	//AMF 格式
	RtmpChunk_0 metadata = {0};
	metadata.msg_stream_id = HJStreamIDInvoke;
	metadata.msg_type_id = HJMsgTypeID_INVOKE;
	
	//组装发送的数据
	NSMutableData *buff = [NSMutableData data];
	
	[buff appendString:@"connect"];
	[buff appendDouble:++_numOfInvokes];
	self.trackedCommands[@(_numOfInvokes)] = @"connect";
	[buff appendByte:kAMFObject];
	[buff putKey:@"app" stringValue:self.config.url.app];
	[buff putKey:@"type" stringValue:@"nonprivate"];
	[buff putKey:@"tcUrl" stringValue:self.config.url.absoluteString];
	[buff putKey:@"fpad" boolValue:NO];//是否使用代理
	[buff putKey:@"capabilities" doubleValue:15.];
	[buff putKey:@"audioCodecs" doubleValue:10.];
	[buff putKey:@"videoCodecs" doubleValue:7.];
	[buff putKey:@"videoFunction" doubleValue:1.];
	[buff appendByte16:0];
	[buff appendByte:kAMFObjectEnd];
	
	metadata.msg_length.data = (int)buff.length;
	[self sendPacket:buff metadata:metadata];
}

- (void)sendPacket:(NSData *)data metadata:(RtmpChunk_0)metadata {
	HJBufferFrame *buffFrame = [HJBufferFrame new];
	
	buffFrame.data = data;
	buffFrame.timestamp = metadata.timestamp.data;
	buffFrame.msgLength = metadata.msg_length.data;
	buffFrame.msgTypeId = metadata.msg_type_id;
	buffFrame.msgSteamId = metadata.msg_stream_id;
	
	[self sendBuffer:buffFrame];
}
/**
 * 处理握手返回的其他数据
 */
- (void)parseData:(NSData *)data {
	
	if (data.length == 0) {
		return;
	}
	
	uint8_t *buffer = (uint8_t *)data.bytes;
	NSUInteger total = data.length;
	
	while (total > 0) {
		int headType = (buffer[0] & 0xC0) >> 6;//取出前两个字节
		buffer++;
		total --;
		
		if (total <= 0) {
			break;
		}
		
		switch (headType) {
			case HJRtmpHeaderType_FULL: {
				RtmpChunk_0 chunk;
				memcpy(&chunk, buffer, sizeof(RtmpChunk_0));
				chunk.msg_length.data = [NSMutableData getByte24:(uint8_t *)&chunk.msg_length];
				buffer += sizeof(RtmpChunk_0);
				total  -= sizeof(RtmpChunk_0);
				BOOL isSuccess = [self handleMeesage:buffer msgTypeId:chunk.msg_type_id];
				if (!isSuccess) {
					total = 0;break;
				}
				
				buffer += chunk.msg_length.data;
				total  -= chunk.msg_length.data;
			}
				break;
			case HJRtmpHeaderType_NO_MSG_STREAM_ID: {
				RtmpChunk_1 chunk;
				memcpy(&chunk, buffer, sizeof(RtmpChunk_1));
				buffer += sizeof(RtmpChunk_1);
				total  -= sizeof(RtmpChunk_1);
				chunk.msg_length.data = [NSMutableData getByte24:(uint8_t *)&chunk.msg_length];
				BOOL isSuccess = [self handleMeesage:buffer msgTypeId:chunk.msg_type_id];
				if (!isSuccess) {
					total = 0;break;
				}
				
				buffer += chunk.msg_length.data;
				total  -= chunk.msg_length.data;
			}
				break;
			case HJRtmpHeaderType_TIMESTAMP: {
				RtmpChunk_2 chunk;
				memcpy(&chunk, buffer, sizeof(RtmpChunk_2));
				buffer += sizeof(RtmpChunk_2) + MIN(total, _inChunkSize);
				total  -= sizeof(RtmpChunk_2) + MIN(total, _inChunkSize);
				
			}
				break;
			case HJRtmpHeaderType_ONLY: {
				buffer += MIN(total, _inChunkSize);
				total  -= MIN(total, _inChunkSize);
			}
				break;
				
			default:
				return;
		}
	}
}

- (BOOL)handleMeesage:(uint8_t *)p msgTypeId:(uint8_t)msgTypeId {
	BOOL handleSuccess = YES;
	switch(msgTypeId) {
		case HJMsgTypeID_BYTES_READ: {
			
		}
			break;
			
		case HJMsgTypeID_CHUNK_SIZE: {
			unsigned long newChunkSize = [NSMutableData getByte32:p];//get_be32(p);
			HJLog(@"change incoming chunk size from %d to: %zu", _inChunkSize, newChunkSize);
			_inChunkSize = (int)newChunkSize;
		}
			break;
			
		case HJMsgTypeID_PING: {
			HJLog(@"received ping, sending pong.");
			[self sendPong];
		}
			break;
			
		case HJMsgTypeID_SERVER_WINDOW: {
			HJLog(@"received server window size: %d\n", [NSMutableData getByte32:p]);
		}
			break;
			
		case HJMsgTypeID_PEER_BW: {
			HJLog(@"received peer bandwidth limit: %d type: %d\n", [NSMutableData getByte32:p], p[4]);
		}
			break;
			
		case HJMsgTypeID_INVOKE: {
			HJLog(@"Received invoke");
			[self handleInvoke:p];//handleInvoke
		}
			break;
		case HJMsgTypeID_VIDEO: {
			HJLog(@"received video");
		}
			break;
			
		case HJMsgTypeID_AUDIO: {
			HJLog(@"received audio");
		}
			break;
			
		case HJMsgTypeID_METADATA: {
			HJLog(@"received metadata");
		}
			break;
			
		case HJMsgTypeID_NOTIFY: {
			HJLog(@"received notify");
		}
			break;
			
		default: {
			HJLog(@"received unknown packet type: 0x%02X", msgTypeId);
			handleSuccess = NO;
		}
			break;
	}
	return handleSuccess;
}

- (void)sendPong {
	dispatch_sync(_packetQueue, ^{
		int streamId = 0;
		
		NSMutableData *data = [NSMutableData data];
		[data appendByte:2];
		[data appendByte24:0];
		[data appendByte24:6];
		[data appendByte:HJMsgTypeID_PING];
		
		[data appendBytes:(uint8_t*)&streamId length:sizeof(int32_t)];
		[data appendByte16:7];
		[data appendByte16:0];
		[data appendByte16:0];
		
		[self writeData:data];
	});
}

- (void)handleInvoke:(uint8_t *)p {
	int buflen = 0;
	NSString *command = [NSMutableData getString:p :&buflen];
	HJLog(@"received invoke %@\n", command);
	
	int pktId = (int)[NSMutableData getDouble:p + 11];
	HJLog(@"pktId: %d\n", pktId);
	
	NSString *trackedCommand = self.trackedCommands[@(pktId)] ;
	
	if ([command isEqualToString:@"_result"]) {
		HJLog(@"tracked command: %@\n", trackedCommand);
		if ([trackedCommand isEqualToString:@"connect"]) {
			[self sendReleaseStream];
			[self sendFCPublish];
			[self sendCreateStream];
			self.rtmpStatus = HJRtmpSessionStatusFCPublish;
		} else if ([trackedCommand isEqualToString:@"createStream"]) {
			if (p[10] || p[19] != 0x05 || p[20]) {
				HJLog(@"RTMP: Unexpected reply on connect()\n");
			} else {
				_streamID = [NSMutableData getDouble:p+21];
			}
			[self sendPublish];
			self.rtmpStatus = HJRtmpSessionStatusReady;
		}
	} else if ([command isEqualToString:@"onStatus"]) {//parseStatusCode
		NSString *code = [self parseStatusCode:p + 3 + command.length];
		HJLog(@"code : %@", code);
		if ([code isEqualToString:@"NetStream.Publish.Start"]) {
			
			// [self sendHeaderPacket];//貌似不发这一句,也可以
			
			//重新设定了chunksize大小
			[self sendSetChunkSize:getpagesize()];//16K
			
			//sendSetBufferTime(0);//设定时间
			self.rtmpStatus = HJRtmpSessionStatusStarted;
		}
	}
}

- (void)sendReleaseStream {
	
	RtmpChunk_0 metadata = {0};
	metadata.msg_stream_id = HJStreamIDInvoke;
	metadata.msg_type_id = HJMsgTypeID_NOTIFY;
	
	NSMutableData *buff = [NSMutableData data];
	[buff appendString:@"releaseStream"];
	[buff appendDouble:++_numOfInvokes];
	
	self.trackedCommands[@(_numOfInvokes)] = @"releaseStream";
	[buff appendByte:kAMFNull];
	[buff appendString:self.config.url.playPath];
	
	metadata.msg_length.data = (int)buff.length;
	[self sendPacket:buff metadata:metadata];
}

- (void)sendFCPublish {
	RtmpChunk_0 metadata = {0};
	metadata.msg_stream_id = HJStreamIDInvoke;
	metadata.msg_type_id = HJMsgTypeID_NOTIFY;
	
	NSMutableData *buff = [NSMutableData data];
	[buff appendString:@"FCPublish"];
	[buff appendDouble:(++_numOfInvokes)];
	self.trackedCommands[@(_numOfInvokes)] = @"FCPublish";
	[buff appendByte:kAMFNull];
	[buff appendString:self.config.url.playPath];
	metadata.msg_length.data = (int)buff.length;
	
	[self sendPacket:buff metadata:metadata];
}

- (void)sendCreateStream {
	RtmpChunk_0 metadata = {0};
	metadata.msg_stream_id = HJStreamIDInvoke;
	metadata.msg_type_id = HJMsgTypeID_NOTIFY;
	
	NSMutableData *buff = [NSMutableData data];
	[buff appendString:@"createStream"];
	self.trackedCommands[@(++_numOfInvokes)] = @"createStream";
	[buff appendDouble:_numOfInvokes];
	[buff appendByte:kAMFNull];
	
	metadata.msg_length.data = (int)buff.length;
	[self sendPacket:buff metadata:metadata];
}

- (void)sendPublish {
	RtmpChunk_0 metadata = {0};
	metadata.msg_stream_id = HJStreamIDAudio;
	metadata.msg_type_id = HJMsgTypeID_INVOKE;
	
	NSMutableData *buff = [NSMutableData data];
	[buff appendString:@"publish"];
	[buff appendDouble:++_numOfInvokes];
	self.trackedCommands[@(_numOfInvokes)] = @"publish";
	[buff appendByte:kAMFNull];
	[buff appendString:self.config.url.playPath];
	[buff appendString:@"live"];
	
	metadata.msg_length.data = (int)buff.length;
	[self sendPacket:buff metadata:metadata];
}

- (NSString *)parseStatusCode:(uint8_t *)p {
	NSMutableDictionary *props = [NSMutableDictionary dictionary];
	
	// skip over the packet id
	p += sizeof(double) + 1;
	
	//keep reading until we find an AMF Object
	bool foundObject = false;
	while (!foundObject) {
		if (p[0] == AMF_DATA_TYPE_OBJECT) {
			p += 1;
			foundObject = true;
			continue;
		} else {
			p += [self amfPrimitiveObjectSize:p];
		}
	}
	
	// read the properties of the object
	uint16_t nameLen, valLen;
	char propName[128], propVal[128];
	do {
		nameLen = [NSMutableData getByte16:p];//get_be16(p);
		p += sizeof(nameLen);
		strncpy(propName, (char*)p, nameLen);
		propName[nameLen] = '\0';
		p += nameLen;
		NSString *key = [NSString stringWithUTF8String:propName];
		HJLog(@"key----%@",key);
		if (p[0] == AMF_DATA_TYPE_STRING) {
			valLen = [NSMutableData getByte16:p+1];//get_be16(p+1);
			p += sizeof(valLen) + 1;
			strncpy(propVal, (char*)p, valLen);
			propVal[valLen] = '\0';
			p += valLen;
			NSString *value = [NSString stringWithUTF8String:propVal];
			props[key] = value;
		} else {
			// treat non-string property values as empty
			p += [self amfPrimitiveObjectSize:p];
			props[key] = @"";
		}
	} while ([NSMutableData getByte24:p] != AMF_DATA_TYPE_OBJECT_END);
	
	//p = start;
	return props[@"code"] ;
}

- (int)amfPrimitiveObjectSize:(uint8_t *)p {//amf原始对象
	switch(p[0]) {
		case AMF_DATA_TYPE_NUMBER:       return 9;
		case AMF_DATA_TYPE_BOOL:         return 2;
		case AMF_DATA_TYPE_NULL:         return 1;
		case AMF_DATA_TYPE_STRING:       return 3 + [NSMutableData getByte16:p];
		case AMF_DATA_TYPE_LONG_STRING:  return 5 + [NSMutableData getByte32:p];
	}
	return -1; // not a primitive, likely an object
}

//验证过
- (void)sendSetChunkSize:(int32_t)newChunkSize {
	
	dispatch_sync(_packetQueue, ^{
		int streamId = 0;
		NSMutableData *data = [NSMutableData data];
		[data appendByte:2];
		[data appendByte24:0];
		[data appendByte24:4];
		[data appendByte:HJMsgTypeID_CHUNK_SIZE];
		
		[data appendBytes:(uint8_t*)&streamId length:sizeof(int32_t)];
		[data appendByte32:newChunkSize];
		
		[self writeData:data];
		//这里重新赋值了 16384
		_outChunkSize = newChunkSize;
	});
}

#pragma mark - lazyload
- (HJStreamSession *)streamSession {
	if (_streamSession == nil) {
		_streamSession = [HJStreamSession new];
		HJWeakSelf;
		[_streamSession setStreamDidChangeBlock:^(NSStreamEvent status) {
			HJLog(@"status : %ld", status);
			[weakSelf handleStreamEvent:status];
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
