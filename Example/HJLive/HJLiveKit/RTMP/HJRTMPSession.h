//
//  HJRTMPSession.h
//  HJLive
//
//  Created by HeJun on 11/08/2017.
//  Copyright © 2017 HeJun. All rights reserved.
//

#import <Foundation/Foundation.h>
@class HJRTMPSession;
@class HJBufferFrame;

/** session status */
typedef NS_ENUM(NSUInteger, HJRTMPSessionStatus) {
	/** 默认 */
	HJRTMPSessionStatusNormal,
	/** 连接中 */
	HJRTMPSessionStatusConnecting,
	/** 已连接 */
	HJRTMPSessionStatusConnected,
	/** 连接失败 */
	HJRTMPSessionStatusFailed,
};

@protocol HJRTMPSessionDelegate <NSObject>

@optional
- (void)session:(HJRTMPSession *)session withStatus:(HJRTMPSessionStatus)status;

@end

@interface HJRTMPSession : NSObject

/** 连接 URL */
//@property (nonatomic, copy) NSURL *connectUrl;
/** 代理 */
@property (nonatomic, weak) id<HJRTMPSessionDelegate> delegate;

+ (instancetype)defaultSession;

- (void)connectWithUrl:(NSURL *)url;
- (void)disConnect;
- (void)sendBuffer:(HJBufferFrame *)buffer;

@end
