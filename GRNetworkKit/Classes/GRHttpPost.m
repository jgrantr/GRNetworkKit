//
//  HttpPost.m
//  Shout
//
//  Created by Grant Robinson on 8/27/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "GRHttpPost.h"
#import "HttpPostParams.h"
#import "HttpPostStream.h"
#import "MyLogging.h"


@interface GRHttpPost ()
{
	NSMutableDictionary *values;
	NSFileManager *fileManager;
}

@property (nonatomic, readonly) NSMutableDictionary *values;
@property (nonatomic, strong) NSFileManager *fileManager;

@end

@implementation GRHttpPost

@synthesize values, fileManager;

- (HttpPostStream *) stream {
	return [[HttpPostStream alloc] initWithPost:self];
}

+ (NSMutableURLRequest *) POST:(NSURL *)url values:(NSDictionary<NSString *,id> *)values {
	GRHttpPost *post = [self withValues:values];
	return [self POST:url withPost:post];
}

+ (NSMutableURLRequest *) POST:(NSURL *)url withPost:(GRHttpPost *)post {
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
	return [post configureURLRequest:request];
}

+ (NSMutableURLRequest *) POST:(NSURL *)url cache:(NSURLRequestCachePolicy)cachePolicy timeout:(NSTimeInterval)timeout values:(NSDictionary<NSString *,id> *)values
{
	GRHttpPost *post = [self withValues:values];
	return [self POST:url cache:cachePolicy timeout:timeout post:post];
}

+ (NSMutableURLRequest *) POST:(NSURL *)url cache:(NSURLRequestCachePolicy)cachePolicy timeout:(NSTimeInterval)timeout post:(GRHttpPost *)post
{
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url cachePolicy:cachePolicy timeoutInterval:timeout];
	return [post configureURLRequest:request];
}

+ (instancetype) withValues:(NSDictionary<NSString *,id> *)values {
	GRHttpPost *post = [[GRHttpPost alloc] init];
	[values enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
		if (obj == [NSNull null]) {
			return;
		}
		else if ([obj isKindOfClass:[NSString class]]) {
			[post takeString:obj forKey:key];
		}
		else if ([obj isKindOfClass:[NSNumber class]]) {
			if      (obj == (id)kCFBooleanTrue)  { [post takeString:@"true" forKey:key];  }
			else if (obj == (id)kCFBooleanFalse) { [post takeString:@"false" forKey:key]; }
			else {
				[post takeString:[obj stringValue] forKey:key];
			}
		}
		else if ([obj isKindOfClass:[NSDictionary class]]) {
			NSDictionary *dict = obj;
			if (dict[@"path"]) {
				// file
				[post takeFile:dict[@"path"] ofType:dict[@"contentType"] forKey:key];
			}
			else if (dict[@"data"]) {
				// data
				[post takeData:dict[@"data"] ofType:dict[@"contentType"] forKey:key];
			}
			else {
				@throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"unsupported dictionary value %@.  Dictionary values must have either a 'path' or a 'data' key", dict] userInfo:nil];
			}
		}
		else {
			@throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"invalid dictionary value of type '%@'", NSStringFromClass([obj class])] userInfo:nil];
		}
	}];
	return post;
}

- (NSUInteger) countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(__unsafe_unretained id  _Nonnull *)buffer count:(NSUInteger)len {
	return [values countByEnumeratingWithState:state objects:buffer count:len];
}

- (id) objectForKeyedSubscript:(id<NSCopying>)subscript {
	return values[subscript];
}

- (NSUInteger) count {
	return values.count;
}

- (void) setValues:(NSMutableDictionary *)_values {
	values = _values;
}

- (NSString *) description {
	return [NSString stringWithFormat:@"%@", values];
}

- (id) init {
	self = [super init];
	self.values = [NSMutableDictionary dictionary];
	self.fileManager = [[NSFileManager alloc] init];
	return self;
}


- (BOOL) takeString:(NSString *)str forKey :(NSString *)key {
	[values setObject:str forKey:key];
	return YES;
}

- (BOOL) takeFile:(NSString *)path ofType:(NSString *)contentType forKey:(NSString *)key {
	BOOL isDir = NO;
	if ([fileManager fileExistsAtPath:path isDirectory:&isDir] == NO || isDir == YES) {
		return NO;
	}
	FileParam *param = [[FileParam alloc] init];
	param.path = path;
	if (contentType == nil) {
		contentType = @"application/octet-stream";
	}
	param.contentType = contentType;
	NSError *error = nil;
	param.size = [[fileManager attributesOfItemAtPath:path error:&error] fileSize];
	if (error) {
		DDLogError(@"error getting attributes of file '%@': %@", path, [error localizedDescription]);
	}
	[values setObject:param forKey:key];
	return YES;
}

- (BOOL) takeData:(NSData *)_data ofType:(NSString *)_contentType forKey:(NSString *)key {
	DataParam *param = [[DataParam alloc] init];
	param.data = _data;
	param.contentType = _contentType;
	[values setObject:param forKey:key];
	return YES;
}

- (NSMutableURLRequest *) configureURLRequest:(NSURLRequest *)incoming {
	NSMutableURLRequest *request = nil;
	if (![incoming isKindOfClass:[NSMutableURLRequest class]]) {
		request = [incoming mutableCopy];
	}
	else {
		request = (NSMutableURLRequest *)incoming;
	}
	request.HTTPMethod = @"POST";
	HttpPostStream *stream = self.stream;
	request.HTTPBodyStream = stream;
	[request addValue:[NSString stringWithFormat:@"multipart/form-data;boundary=%@", stream.boundary] forHTTPHeaderField:@"Content-Type"];
	[request addValue:[[NSNumber numberWithLongLong:stream.contentLength] stringValue] forHTTPHeaderField:@"Content-Length"];
	return request;
}


@end
