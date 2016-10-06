//
//  HttpPost.h
//  Shout
//
//  Created by Grant Robinson on 8/27/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 
 File that simplifies making a multi-part HTTP POST to a server.  Initialize it the values you want to send,
 and then you can use it like this:
 
 GRHttpPost *post = ...;
 
 NSMutableURLRequest *request = [GRHttpPost POST:@"http://someserver.com/somepath" withPost:post];
 
 That's it, and now you are ready to send a multi-part post.  Pass it to GRNetwork, NSURLSession, NSURLConnection
 or any other networking API that works off NSURLRequest.
 
 */
@interface GRHttpPost : NSObject <NSFastEnumeration>

/**
   Use when you want to do a shorthand.  For example:
 
       GRHttpPost *post = [GRHttpPost withValues:@{
           @"param1" : @"some value", // simple string
           @"param2" : @{@"contentType" : @"image/jpeg", @"data" : <some NSData object}, // data object
           @"param3" : @{@"path" : <NSString or file:// NSURL with fully-qualified path to file>, @"contentType" : @"image/png"} // file object
       };
 */
+ (instancetype) withValues:(NSDictionary <NSString*,id> *)values;

+ (NSMutableURLRequest *) POST:(NSURL *)url values:(NSDictionary <NSString*,id> *)values;
+ (NSMutableURLRequest *) POST:(NSURL *)url cache:(NSURLRequestCachePolicy)cachePolicy timeout:(NSTimeInterval)timeout values:(NSDictionary <NSString*,id> *)values;
+ (NSMutableURLRequest *) POST:(NSURL *)url withPost:(GRHttpPost *)post;
+ (NSMutableURLRequest *) POST:(NSURL *)url cache:(NSURLRequestCachePolicy)cachePolicy timeout:(NSTimeInterval)timeout post:(GRHttpPost *)post;

@property (readonly, nonatomic) NSUInteger count;
- (id) objectForKeyedSubscript:(id <NSCopying>)subscript;

- (BOOL) takeString:(NSString *)str forKey:(NSString *)key;
- (BOOL) takeFile:(NSString *)path ofType:(NSString *)contentType forKey:(NSString *)key;
- (BOOL) takeData:(NSData *)data ofType:(NSString *)contentType forKey:(NSString *)key;

- (NSMutableURLRequest *) configureURLRequest:(NSURLRequest *)request;

@end

