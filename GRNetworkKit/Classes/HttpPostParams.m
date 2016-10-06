//
//  HttpPostParams.m
//  Pods
//
//  Created by Grant Robinson on 10/6/16.
//
//

#import "HttpPostParams.h"

@interface FileParam ()
{
	NSString *path;
	NSString *contentType;
	int64_t size;
}


@end

@implementation FileParam

@synthesize path, contentType, size;

- (NSString *) description {
	return [NSString stringWithFormat:@"FileParam <%p> {path: %@, contentType: %@, size: %lld}", self, path, contentType, size];
}

@end

@interface DataParam ()
{
	NSString *contentType;
	NSData *data;
}

@end

@implementation DataParam

@synthesize data, contentType;

- (NSString *) description {
	return [NSString stringWithFormat:@"DataParam <%p> {data: %@, contentType: %@}", self, data, contentType];
}

@end
