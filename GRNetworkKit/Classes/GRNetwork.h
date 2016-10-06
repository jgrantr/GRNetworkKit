//
//  GRNetwork.h
//

#import <Foundation/Foundation.h>

extern BOOL kGRNetworkAllowInsecureConnections;

extern NSString *kNetworkConnectionStarted;
extern NSString *kNetworkConnectionFinished;

@class GRNetwork;

typedef enum ProgressType {
	UploadProgress = 1,
	DownloadProgress = 2
} ProgressType;

typedef enum GRRedirectPolicy {
	GRRedirectPolicyCloneOriginalRequest,
	GRRedirectPolicyDiscardOriginalRequest,
	GRRedirectPolicyUseSystemDefault,
} GRRedirectPolicy;

typedef void (^GRProgressCallback)(GRNetwork *conn, ProgressType type, int64_t byteCount, int64_t totalBytes);
typedef void (^GRConnComplete)(GRNetwork *conn, NSMutableData *data, NSError *error);


@interface GRNetwork : NSObject

@property (strong, nonatomic) dispatch_queue_t queue;

+ (NSURLRequest *) canonicalRequestForRequest:(NSURLRequest *)request;

+ (BOOL) checkURLIsValid:(NSString *)url;

+ (void) setRedirectPolicy:(GRRedirectPolicy)policy forHTTPStatusCode:(NSInteger)statusCode;

+ (NSTimeInterval) clockDrift;
/* returns a connection that is started automatically */
+ (GRNetwork *) connWithRequest:(NSURLRequest *)request progress:(GRProgressCallback)progress completion:(GRConnComplete)completion;
+ (GRNetwork *) connWithRequest:(NSURLRequest *)request progress:(GRProgressCallback)progress completion:(GRConnComplete)completion queue:(dispatch_queue_t)queue;

/* returns a connection that must be started manually */
- (GRNetwork *) initWithRequest:(NSURLRequest *)request progress:(GRProgressCallback)progress completion:(GRConnComplete)completion;
- (GRNetwork *) initWithRequest:(NSURLRequest *)request progress:(GRProgressCallback)progress completion:(GRConnComplete)completion queue:(dispatch_queue_t)queue;

- (GRNetwork *) start;
- (NSURLResponse *) response;
- (NSInteger) statusCode;
- (NSURL *) url;
- (NSDictionary *) headers;
- (void) cancel;

@end