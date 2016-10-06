//
//  HttpPost.h
//  Shout
//
//  Created by Grant Robinson on 8/27/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

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

@property (readonly, copy) NSInputStream *stream;
@property (readonly, nonatomic) NSUInteger count;

- (id) objectForKeyedSubscript:(id <NSCopying>)subscript;

- (BOOL) takeString:(NSString *)str forKey:(NSString *)key;
- (BOOL) takeFile:(NSString *)path ofType:(NSString *)contentType forKey:(NSString *)key;
- (BOOL) takeData:(NSData *)data ofType:(NSString *)contentType forKey:(NSString *)key;

@end

