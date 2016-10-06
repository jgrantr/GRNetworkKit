//
//  HttpPostStream.m
//  Shout
//
//  Created by Grant Robinson on 8/27/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "HttpPostStream.h"
#import "GRHttpPost.h"
#import "HttpPostParams.h"
#import <stdio.h>
#import <objc/message.h>

#import "MyLogging.h"

#define BOUNDARY_PREFIX @"---------------"
#define BOUNDARY_POSTFIX @"---------------"
#define NEWLINE_STR @"\r\n"

// StreamMessage declaration
@interface StreamMessage : NSObject
{
	NSStreamEvent event;
}

@property (nonatomic, assign) NSStreamEvent event;

@end

// StreamMessage implementation
@implementation StreamMessage

@synthesize event;

@end

static NSDictionary *methodsToResolve = nil;

@interface HttpPostStream()
{
	NSMutableDictionary *properties;
	NSMutableArray *items;
	NSEnumerator *valuesEnum;
	BOOL hasBytes;
	NSError *error;
	CFRunLoopSourceRef runLoopSource;
	NSMutableArray *messageQueue;
	CFRunLoopRef runLoop;
	FILE *curFile;
	NSData *curData;
	NSUInteger curPos;
}

@property (nonatomic, strong) NSMutableDictionary *properties;
@property (nonatomic, strong) NSMutableArray *items;
@property (nonatomic, strong) NSEnumerator *valuesEnum;
@property (nonatomic, strong) NSMutableArray *messageQueue;
@property (nonatomic, strong) NSData *curData;

- (void) sourceFired;
- (void) enqueueStreamEvent: (NSStreamEvent)event;
- (void) doCFRunLoopSchedule:(CFRunLoopRef)aRunLoop forMode:(CFStringRef)mode;
- (void) doCFRunLoopUnschedule:(CFRunLoopRef)aRunLoop forMode:(CFStringRef)mode;
- (BOOL) doCFClientFlags:
	(CFOptionFlags)theStreamEvents
	callback:(CFReadStreamClientCallBack)clientCB
	context:(CFStreamClientContext*)clientContext;
- (void) initItems: (GRHttpPost *)post;
- (void) prepNextItem;
- (NSUInteger) readFromCurFile:(uint8_t *)buffer maxLength:(NSUInteger)len;

@end


static void sourceFired(void *info) {
	HttpPostStream *stream = (__bridge HttpPostStream *)info;
	[stream sourceFired];
}

@implementation HttpPostStream

@synthesize status, boundary, contentLength;
@synthesize properties, items, valuesEnum, messageQueue, curData;

+ (void) initialize {
	methodsToResolve = [[NSDictionary alloc] initWithObjectsAndKeys:@"doCFRunLoopSchedule:forMode:", @"_scheduleInCFRunLoop:forMode:", @"doCFRunLoopUnschedule:forMode:", @"_unscheduleFromCFRunLop:forMode:", @"doCFClientFlags:callback:context:", @"_setCFClientFlags:callback:context:", nil];
}

+ (BOOL) resolveInstanceMethod:(SEL)sel {
    NSString * name = NSStringFromSelector(sel);
	
    if ( [name hasPrefix:@"_"] )
    {
		NSString *methodName = [methodsToResolve objectForKey:name];
		if (methodName) {
			SEL aSelector = NSSelectorFromString(methodName);
			Method method = class_getInstanceMethod(self, aSelector);
			
			if ( method )
			{
				class_addMethod(self,
								sel,
								method_getImplementation(method),
								method_getTypeEncoding(method));
				return YES;
			}
		}
    }
    return [super resolveInstanceMethod:sel];
}

- (void) setBoundary:(NSString *)_boundary {
	boundary = _boundary;
}

#pragma mark private methods
- (void) sourceFired {
	NSMutableArray *curQueue = messageQueue;
	self.messageQueue = [[NSMutableArray alloc] initWithCapacity:10];
	for (StreamMessage *message in curQueue) {
		[delegate stream:self handleEvent:message.event];
	}
}

- (void) enqueueStreamEvent: (NSStreamEvent)event {
	if (runLoop) {
		StreamMessage *msg = [[StreamMessage alloc] init];
		msg.event = event;
		[messageQueue addObject:msg];
		CFRunLoopSourceSignal(runLoopSource);
		CFRunLoopWakeUp(runLoop);
	}
}

- (void) doCFRunLoopSchedule:(CFRunLoopRef)aRunLoop forMode:(CFStringRef)mode {
	runLoop = aRunLoop;
	CFRunLoopAddSource(runLoop, runLoopSource, (CFStringRef)mode);	
}

- (void) doCFRunLoopUnschedule:(CFRunLoopRef)aRunLoop forMode:(CFStringRef)mode {
	CFRunLoopRemoveSource(runLoop, runLoopSource, (CFStringRef)mode);
	runLoop = NULL;	
}

- (BOOL) doCFClientFlags:(CFOptionFlags)theStreamEvents callback:(CFReadStreamClientCallBack)clientCB context:(CFStreamClientContext *)clientContext {
	return NO;
}

- (void) initItems: (GRHttpPost *)post {
	for (NSString *key in post) {
		id nextValue = post[key];
		if ([nextValue isKindOfClass:[NSString class]]) {
			NSString *dataWithBoundary = [NSString
										  stringWithFormat:@"--%@%@Content-Disposition: form-data; name=\"%@\"%@%@%@%@",
										  boundary, NEWLINE_STR, key, NEWLINE_STR, NEWLINE_STR, nextValue, NEWLINE_STR
										  ];
			NSData *data = [dataWithBoundary dataUsingEncoding:NSUTF8StringEncoding];
			contentLength += [data length];
			[items addObject:data];
		}
		else if ([nextValue isKindOfClass:[DataParam class]]) {
			DataParam *param = (DataParam *)nextValue;
			NSData *dataWithBoundary = [[NSString stringWithFormat:@"--%@%@Content-Disposition: form-data; name=\"%@\"; filename=\"image.png\"%@Content-Type: %@%@%@", boundary, NEWLINE_STR, key, NEWLINE_STR, param.contentType, NEWLINE_STR, NEWLINE_STR] dataUsingEncoding:NSUTF8StringEncoding];
			contentLength += [dataWithBoundary length];
			[items addObject:dataWithBoundary];
			contentLength += [param.data length];
			[items addObject:param.data];
			NSData *newline = [NEWLINE_STR dataUsingEncoding:NSUTF8StringEncoding];
			contentLength += [newline length];
			[items addObject:newline];
		}
		else if ([nextValue isKindOfClass:[FileParam class]]) {
			FileParam *param = (FileParam *)nextValue;
			NSString *filePreamble = [NSString
									  stringWithFormat:@"--%@%@Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"%@Content-Type: %@%@%@",
									  boundary, NEWLINE_STR, key, [param.path lastPathComponent], NEWLINE_STR, param.contentType, NEWLINE_STR, NEWLINE_STR
									  ];
			NSData *data = [filePreamble dataUsingEncoding:NSUTF8StringEncoding];
			contentLength += [data length];
			[items addObject:data];
			contentLength += param.size;
			[items addObject:param];
			data = [NEWLINE_STR dataUsingEncoding:NSUTF8StringEncoding];
			contentLength += [data length];
			[items addObject:data];
		}
		else {
			DDLogVerbose(@"Unknown type of object: %@", NSStringFromClass([nextValue class]));
		}		
	}
	NSString *endBoundary = [NSString stringWithFormat:@"--%@--%@", boundary, NEWLINE_STR];
	NSData *data = [endBoundary dataUsingEncoding:NSUTF8StringEncoding];
	contentLength += [data length];
	[items addObject:data];
}

- (void) prepNextItem {
	self.curData = nil;
	curPos = 0;
	if (curFile) {
		fclose(curFile);
		curFile = NULL;
	}
	id next = [valuesEnum nextObject];
	if (next == nil) {
		hasBytes = NO;
		self.valuesEnum = nil;
		return;
	}
	if ([next isKindOfClass:[NSData class]]) {
		curData = next;
	}
	else if ([next isKindOfClass:[FileParam class]]) {
		curFile = fopen([[(FileParam *)next path] UTF8String], "rb");
	}
	else {
		DDLogVerbose(@"Unknown type of object: %@", NSStringFromClass([next class]));
	}

}

- (NSUInteger) readFromCurFile:(uint8_t *)buffer maxLength:(NSUInteger)len {
	size_t bytesRead = fread(buffer, 1, len, curFile);
	if (bytesRead < len) {
		[self prepNextItem];
	}
	return bytesRead;
}


- (id) initWithPost:(GRHttpPost *)post {
	self = [super init];
	if (self) {
		self.properties = [NSMutableDictionary dictionary];
		self.status = NSStreamStatusNotOpen;
		delegate = self;
		self.messageQueue = [NSMutableArray arrayWithCapacity:10];
		CFRunLoopSourceContext context;
		memset(&context, 0, sizeof(CFRunLoopSourceContext));
		context.info = (__bridge void *)(self);
		context.perform = sourceFired;
		runLoopSource = CFRunLoopSourceCreate(NULL, 0, &context);
		runLoop = NULL;
		curData = nil;
		curFile = NULL;
		curPos = 0;
		self.boundary = [NSString stringWithFormat:@"%@%@%@",
					 BOUNDARY_PREFIX,
					 [[NSDate date] description],
					 BOUNDARY_POSTFIX
					 ];
		self.items = [NSMutableArray arrayWithCapacity:post.count+2];
		contentLength = 0;
		[self initItems:post];
	}
	return self;	
}

- (void) dealloc {
	if (runLoopSource) {
		CFRelease(runLoopSource);
		runLoopSource = NULL;
	}
	if (curFile) {
		fclose(curFile);
		curFile = NULL;
	}
}

- (void) open {
	DDLogVerbose(@"HttpPostStream::open called");
	self.status = NSStreamStatusOpen;
	self.valuesEnum = [items objectEnumerator];
	[self prepNextItem];
	hasBytes = YES;
	[self enqueueStreamEvent:NSStreamEventOpenCompleted];
	if ([self hasBytesAvailable]) {
		[self enqueueStreamEvent:NSStreamEventHasBytesAvailable];
	}
}

- (void) close {
	DDLogVerbose(@"HttpPostStream::close called");
	self.status = NSStreamStatusNotOpen;
}

- (id <NSStreamDelegate>) delegate {
	DDLogVerbose(@"HttpPostStream::delegate called");
	return delegate;
}

- (void) setDelegate:(id <NSStreamDelegate>)_delegate {
	DDLogVerbose(@"HttpPostStream::setDelegate: called");
	if (_delegate == nil) {
		delegate = self;
	}
	else {
		delegate = _delegate;
	}
}

- (id) propertyForKey:(NSString *)key {
	DDLogVerbose(@"HttpPostStream::propertyForKey:'%@'", key);
	return [properties objectForKey:key];
}

- (BOOL) setProperty:(id)property forKey:(NSString *)key {
	DDLogVerbose(@"HttpPostStream::setProperty:'%@' forKey:'%@'", property, key);
	[properties setObject:property forKey:key];
	return YES;
}

- (NSStreamStatus) streamStatus {
	NSStreamStatus _status = self.status;
	DDLogVerbose(@"stream status = %lu", (unsigned long)_status);
	return _status;
}

- (NSError *) streamError {
	return error;
}

- (void) scheduleInRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode {
	DDLogVerbose(@"HttpPostStream::scheduleInRunLoop:forMode called");
	[self doCFRunLoopSchedule:[aRunLoop getCFRunLoop] forMode:(CFStringRef)mode];
}

- (void) removeFromRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode {
	DDLogVerbose(@"HttpPostStream::removeFromRunLoop:forMode");
	[self doCFRunLoopUnschedule:[aRunLoop getCFRunLoop] forMode:(CFStringRef)mode];
}

- (NSInteger) read:(uint8_t *)buffer maxLength:(NSUInteger)len {
	DDLogVerbose(@"HttpPostStream::read: %p maxLength:%lu called", buffer, (unsigned long)len);
	NSStreamStatus oldStatus = self.status;
	self.status = NSStreamStatusReading;
	NSUInteger bytesRead = 0;
	uint8_t *curBufPtr = buffer;
	while (hasBytes && bytesRead < len) {
		if (curFile) {
			NSUInteger numBytes = [self readFromCurFile:curBufPtr maxLength:len - bytesRead];
			curBufPtr += numBytes;
			bytesRead += numBytes;
		}
		else {
			NSUInteger available = [curData length] - curPos;
			NSUInteger bytesToRead = available > (len - bytesRead) ? (len - bytesRead) : available;
			[curData getBytes:curBufPtr range:NSMakeRange(curPos, bytesToRead)];
			curPos += bytesToRead;
			curBufPtr += bytesToRead;
			bytesRead += bytesToRead;
			if (curPos == [curData length]) {
				[self prepNextItem];
			}
		}
	}
	if ([self hasBytesAvailable]) {
		[self enqueueStreamEvent:NSStreamEventHasBytesAvailable];
	}
	if (hasBytes) {
		self.status = oldStatus;		
	}
	else {
		self.status = NSStreamStatusAtEnd;
		[self enqueueStreamEvent:NSStreamEventEndEncountered];
	}

	return bytesRead;
}

- (BOOL) hasBytesAvailable {
	DDLogVerbose(@"HttpPostStream::hasBytesAvailable called, answer is %s", hasBytes ? "YES" : "NO");
	return hasBytes;
}

- (BOOL) getBuffer:(uint8_t **)buffer length:(NSUInteger *)len {
	DDLogVerbose(@"HttpPostStream::getBuffer:length");
	return NO;
}

- (void) stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
	DDLogInfo(@"handleEvent called with eventCode %lu", (unsigned long)eventCode);
}

@end

