//
//  HJLiveManager.h
//  HJLive
//
//  Created by HeJun on 30/08/2017.
//  Copyright © 2017 HeJun. All rights reserved.
//

#import <Foundation/Foundation.h>
@class HJVideoConfig;
@class HJAudioConfig;

/** 直播链接状态 */
typedef NS_ENUM(NSUInteger, HJLiveStatus) {
	/** 未连接 */
	HJLiveStatusNone,
	/** 正在连接 */
	HJLiveStatusConnecting,
	/** 已连接 */
	HJLiveStatusConnected,
	/** 连接失败 */
	HJLiveStatusConnectFail,
};

typedef void(^OnLiveStatusChanged)(HJLiveStatus liveStatus);

@interface HJLiveManager : NSObject

/** 推流地址 */
@property (nonatomic, copy) NSURL *rtmpUrl;
/** 连接回调 */
@property (nonatomic, copy) OnLiveStatusChanged liveStatusChangedBlock;
/** 直播状态 */
@property (nonatomic, assign, readonly) HJLiveStatus liveStatus;
/** 视频预览视图(可以修改预览视频的 frame) */
@property (nonatomic, strong, readonly) UIView *preview;
#pragma mark - optional param
/** 视频配置 */
@property (nonatomic, strong) HJVideoConfig *videoConfig;
/** 音频配置 */
@property (nonatomic, strong) HJAudioConfig *audioConfig;

+ (instancetype)defaultManager;

/** 开始直播 */
- (void)start;
/** 结束直播 */
- (void)end;
#pragma mark - optional func
- (void)setLiveStatusChangedBlock:(OnLiveStatusChanged)liveStatusChangedBlock;

@end
