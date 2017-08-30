//
//  HJRTMPSession.h
//  HJLive
//
//  Created by HeJun on 11/08/2017.
//  Copyright © 2017 HeJun. All rights reserved.
//

#import <Foundation/Foundation.h>
@class HJRtmpSession;
@class HJRtmpConfig;
@class HJBufferFrame;

/** session status */
typedef NS_ENUM(NSUInteger, HJRtmpSessionStatus) {
	/** 默认 */
	HJRtmpSessionStatusNormal = 0,
	/** 已连接 */
	HJRtmpSessionStatusConnected,
	/** 连接失败 */
	HJRtmpSessionStatusFailed,
	/** 未连接 */
	HJRtmpSessionStatusNotConnected,
	
	/** 第一次握手 */
	HJRtmpSessionStatusHandshake0,
	/** 第二次握手 */
	HJRtmpSessionStatusHandshake1,
	/** 第三次握手 */
	HJRtmpSessionStatusHandshake2,
	/** 握手完成 */
	HJRtmpSessionStatusHandshakeComplete,
	
	/** 特殊指令 */
	HJRtmpSessionStatusFCPublish,
	HJRtmpSessionStatusReady,
	HJRtmpSessionStatusStarted
};

typedef void(^OnRtmpStatusDidChanged)(HJRtmpSessionStatus status);

@interface HJRtmpSession : NSObject

/** 配置 */
@property (nonatomic, strong) HJRtmpConfig *config;
/** 代理 */
@property (nonatomic, copy	) OnRtmpStatusDidChanged statusChangedBlock;

+ (instancetype)defaultSession;

- (void)connect;
- (void)disConnect;
- (void)sendBuffer:(HJBufferFrame *)buffer;

#pragma mark - optional func
- (void)setStatusChangedBlock:(OnRtmpStatusDidChanged)statusChangedBlock;

@end
