//
//  HJBufferFrame.h
//  HJLive
//
//  Created by HeJun on 11/08/2017.
//  Copyright © 2017 HeJun. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface HJBufferFrame : NSObject

/** 发送的数据 */
@property (nonatomic, strong) NSData *data;
/** 时间戳 */
@property (nonatomic, assign) int timestamp;
/** 消息长度 */
@property (nonatomic, assign) int msgLength;
/** 消息类型 ID */
@property (nonatomic, assign) int msgTypeId;
/** 流 ID */
@property (nonatomic, assign) int msgSteamId;
/** 是否为关键帧 */
@property (nonatomic, assign, getter=isKeyFrame) BOOL keyFrame;

@end
