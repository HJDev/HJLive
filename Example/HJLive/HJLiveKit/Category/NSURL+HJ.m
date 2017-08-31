//
//  NSURL+HJ.m
//  HJLive
//
//  Created by HeJun on 31/08/2017.
//  Copyright © 2017 HeJun. All rights reserved.
//

#import "NSURL+HJ.h"
#import <objc/runtime.h>

@implementation NSURL (HJ)

+ (void)load {
	Method mURLWithString = class_getClassMethod(self, @selector(URLWithString:));
	Method customURLWithString = class_getClassMethod(self, @selector(customURLWithString:));
	method_exchangeImplementations(mURLWithString, customURLWithString);
}

+ (instancetype)customURLWithString:(NSString *)URLString {
	NSURL *instance = [self customURLWithString:URLString];
	
	NSString *path = instance.path;
	if ([path hasPrefix:@"/"]) {
		path = [path substringFromIndex:1];
	}
	
	NSArray<NSString *> *pathArray = [path componentsSeparatedByString:@"/"];
	instance.app = pathArray.firstObject;
	instance.playPath = pathArray.lastObject;
	
	return instance;
}

- (void)setApp:(NSString *)app {
	objc_setAssociatedObject(self, @selector(app), app, OBJC_ASSOCIATION_COPY);
}
- (NSString *)app {
	return objc_getAssociatedObject(self, _cmd);
}

- (void)setPlayPath:(NSString *)playPath {
	objc_setAssociatedObject(self, @selector(playPath), playPath, OBJC_ASSOCIATION_COPY);
}
- (NSString *)playPath {
	return objc_getAssociatedObject(self, _cmd);
}

@end
