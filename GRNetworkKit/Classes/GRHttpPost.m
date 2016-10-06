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

- (NSInputStream *) stream {
	return [[HttpPostStream alloc] initWithPost:self];
}

+ (instancetype) withValues:(NSDictionary<NSString *,id> *)values {
	GRHttpPost *post = [[GRHttpPost alloc] init];
	[values enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
		if ([obj isKindOfClass:[NSString class]]) {
			[post takeString:obj forKey:key];
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


@end
