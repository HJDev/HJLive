//
//  HJSteamSession.h
//  HJLive
//
//  Created by HeJun on 30/08/2017.
//  Copyright © 2017 HeJun. All rights reserved.
//
//  负责流的创建、连接、以及数据的发送和接收

#import <Foundation/Foundation.h>

typedef void(^OnStreamStatusDidChanged)(NSStreamEvent status);

@interface HJStreamSession : NSObject

/** 流状态 */
@property (nonatomic, assign, readonly) NSStreamEvent streamStatus;
/** 流状态改变 block 回调 */
@property (nonatomic, copy) OnStreamStatusDidChanged streamDidChangeBlock;

#pragma mark - func
/** 连接到服务器 */
- (void)connectToServerWithUrl:(NSURL *)url;
/** 关闭连接 */
- (void)close;
/** 读取数据 */
- (NSData *)readData;
/** 写数据 */
- (NSInteger)writeData:(NSData *)data;
#pragma mark - optional func
- (void)setStreamDidChangeBlock:(OnStreamStatusDidChanged)streamDidChangeBlock;

@end
