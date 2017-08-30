//
//  HJRtmpConfig.h
//  HJLive
//
//  Created by HeJun on 30/08/2017.
//  Copyright © 2017 HeJun. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface HJRtmpConfig : NSObject

/** 推流地址 */
@property (nonatomic, strong) NSURL		*url;
/** 视频宽度 */
@property (nonatomic, assign) int32_t	width;
/** 视频高度 */
@property (nonatomic, assign) int32_t	height;
/** 视频比特率 */
@property (nonatomic, assign) int32_t	videoBitrate;
/** 每帧长度 */
@property (nonatomic, assign) double	frameDuration;
/** 音频采样率 */
@property (nonatomic, assign) double	audioSampleRate;
/** 是否为立体声 */
@property (nonatomic, assign) BOOL		stereo;

@end
