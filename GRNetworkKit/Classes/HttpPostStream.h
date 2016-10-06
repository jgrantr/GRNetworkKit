//
//  HttpPostStream.h
//  Shout
//
//  Created by Grant Robinson on 8/27/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <stdio.h>

@class GRHttpPost;

@interface HttpPostStream : NSInputStream <NSStreamDelegate> {
	NSStreamStatus status;
	int64_t contentLength;
	id <NSStreamDelegate> delegate;
	NSString *boundary;
}

@property (nonatomic, assign) NSStreamStatus status;
@property (nonatomic, readonly) NSString* boundary;
@property (nonatomic, readonly) int64_t contentLength;

- (id) initWithPost:(GRHttpPost *)post;
- (void) open;
- (void) close;
- (id <NSStreamDelegate>) delegate;
- (void) setDelegate:(id <NSStreamDelegate>)delegate;
- (id) propertyForKey:(NSString *)key;
- (BOOL) setProperty:(id)property forKey:(NSString *)key;
- (NSStreamStatus) streamStatus;
- (NSError *) streamError;
- (void) scheduleInRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode;
- (void) removeFromRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode;
- (NSInteger) read:(uint8_t *)buffer maxLength:(NSUInteger)len;
- (BOOL) hasBytesAvailable;
- (BOOL) getBuffer:(uint8_t **)buffer length:(NSUInteger *)len;

@end
