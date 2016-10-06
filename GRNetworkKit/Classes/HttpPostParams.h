//
//  HttpPostParams.h
//  Pods
//
//  Created by Grant Robinson on 10/6/16.
//
//

#import <Foundation/Foundation.h>

@interface FileParam : NSObject

@property (nonatomic, strong) NSString *path;
@property (nonatomic, strong) NSString *contentType;
@property (nonatomic, assign) int64_t size;

@end

@interface DataParam : NSObject

@property (nonatomic, strong) NSString *contentType;
@property (nonatomic, strong) NSData *data;

@end
