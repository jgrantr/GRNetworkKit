//
//  GRNetwork.m
//

#import "GRNetwork.h"
#import "CanonicalRequest.h"
#import "MyLogging.h"
#import <UIKit/UIKit.h>
#import <CocoaLumberjack/CocoaLumberjack.h>

#ifndef GR_STATIC_FRAMEWORK
BOOL kGRNetworkAllowInsecureConnections = NO;
#endif

NSString *kNetworkConnectionStarted = @"GRNetworkConnectionStarted";
NSString *kNetworkConnectionFinished = @"GRNetworkConnectionFinished";
static NSMutableDictionary *redirectPolicies;
static NSTimeInterval clockDrift;
static dispatch_queue_t _policyDispatchQueue;

@interface GRNetwork ()
{
	GRProgressCallback progressBlock;
	GRConnComplete completeBlock;
	NSURLRequest *request;
	NSMutableData *responseData;
	NSHTTPURLResponse *response;
	BOOL autoStarted;
	NSURLAuthenticationChallenge *challenge;
	int64_t contentLength;
	BOOL startNotificationSent;
	NSURLConnection *conn;
}

@property (nonatomic, copy) GRProgressCallback progressBlock;
@property (nonatomic, copy) GRConnComplete completeBlock;
@property (nonatomic, strong) NSURLRequest *request;
@property (nonatomic, strong) NSMutableData *responseData;
@property (nonatomic, assign) BOOL autoStarted;
@property (nonatomic, strong) NSURLAuthenticationChallenge *challenge;


- (GRConnComplete) notifyDelegate:(id)data error:(NSError *)error;

@end

static NSNumber* getRedirectPolicyForStatusCode(NSInteger httpStatusCode) {
	__block NSNumber *policy = nil;
	dispatch_sync(_policyDispatchQueue, ^{
		policy = redirectPolicies[@(httpStatusCode)];
	});
	return policy;
}

@implementation GRNetwork


+ (DDLogLevel) ddLogLevel {
	return ddLogLevel;
}

+ (void) ddSetLogLevel:(DDLogLevel)logLevel {
	ddLogLevel = logLevel;
}

@synthesize progressBlock, completeBlock, request, responseData, autoStarted, challenge, queue;

+ (void) load {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		_policyDispatchQueue = dispatch_queue_create("net.mr-r.GRToolkit.GRNetworkPrivateQueue", NULL);
		redirectPolicies = [NSMutableDictionary dictionaryWithCapacity:6];
		redirectPolicies[@302] = @(GRRedirectPolicyUseSystemDefault);
		redirectPolicies[@307] = @(GRRedirectPolicyCloneOriginalRequest);
	});
	clockDrift = 0;
}

+ (NSURLRequest *) canonicalRequestForRequest:(NSURLRequest *)request {
	return CanonicalRequestForRequest(request);
}

+ (void) setRedirectPolicy:(GRRedirectPolicy)policy forHTTPStatusCode:(NSInteger)statusCode {
	dispatch_sync(_policyDispatchQueue, ^{
		redirectPolicies[@(statusCode)] = @(policy);
	});
}

+ (BOOL) checkURLIsValid:(NSString *)url {
	static NSRegularExpression *schemeRegex;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		NSError *error = nil;
		schemeRegex = [[NSRegularExpression alloc] initWithPattern:@"[a-z][a-z0-9\\+\\-\\.]*:" options:NSRegularExpressionCaseInsensitive error:&error];
	});
	if (url.length == 0) {
		return NO;
	}
	NSTextCheckingResult *match = [schemeRegex firstMatchInString:url options:NSMatchingAnchored range:NSMakeRange(0, url.length)];
	if (!match) {
		return NO;
	}
	return YES;
}

+ (void) updateDriftBetweenDate:(NSDate *)date andHeader:(NSString *)dateHeader {
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	NSLocale *usLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
	[dateFormatter setLocale:usLocale];
	[dateFormatter setDateFormat:@"EEE',' dd' 'MMM' 'yyyy HH':'mm':'ss zzz"];
	NSDate *dateFromHeader = [dateFormatter dateFromString:dateHeader];
	if (dateFromHeader) {
		clockDrift = [date timeIntervalSinceDate:dateFromHeader];
		DDLogVerbose(@"new clock drift is %.20g seconds", clockDrift);
	}
}

+ (NSTimeInterval) clockDrift {
	return clockDrift;
}

+ (GRNetwork *) connWithRequest:(NSURLRequest *)request progress:(GRProgressCallback)progress completion:(GRConnComplete)completion {
	return [self connWithRequest:request progress:progress completion:completion queue:nil];
}

+ (GRNetwork *) connWithRequest:(NSURLRequest *)request progress:(GRProgressCallback)progress completion:(GRConnComplete)completion queue:(dispatch_queue_t)queue
{
	GRNetwork *network = [[GRNetwork alloc] initWithRequest:request progress:progress completion:completion queue:queue];
	network.autoStarted = YES;
	return [network start];
}

- (GRNetwork *) initWithRequest:(NSURLRequest *)_request progress:(GRProgressCallback)progress completion:(GRConnComplete)completion
{
	return [self initWithRequest:_request progress:progress completion:completion queue:dispatch_get_main_queue()];
}

- (GRNetwork *) initWithRequest:(NSURLRequest *)_request progress:(GRProgressCallback)progress completion:(GRConnComplete)completion queue:(dispatch_queue_t)_queue
{
	self = [super init];
	if (self) {
		self.request = _request;
		self.progressBlock = progress;
		self.completeBlock = completion;
		autoStarted = NO;
		if (_queue == nil) {
			self.queue = dispatch_get_main_queue();
		}
		else {
			self.queue = _queue;
		}
		startNotificationSent = NO;
	}
	return self;
}

- (GRNetwork *) start {
	conn = [NSURLConnection connectionWithRequest:request delegate:self];
	if (conn == nil) {
		DDLogError(@"error making connection");
		NSError *error = [NSError errorWithDomain:@"WebService"
											 code:-1
										 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
												   [NSString stringWithFormat:@"error making connection to '%@'", request.URL],
												   NSLocalizedDescriptionKey,nil]];
		if (!autoStarted) {
			dispatch_async(queue, ^{
				[self notifyDelegate:nil error:error];
			});
		}
		return nil;
	}
	else {
		startNotificationSent = YES;
		dispatch_async(dispatch_get_main_queue(), ^{
			NSNotificationCenter *dc = [NSNotificationCenter defaultCenter];
			[dc postNotificationName:kNetworkConnectionStarted object:self];
		});
	}
	return self;
}

- (GRConnComplete) notifyDelegate:(id)data error:(NSError *)error {
	GRConnComplete complete = completeBlock;
	BOOL shouldSendFinishedNotification = startNotificationSent;
	self.completeBlock = nil;
	self.progressBlock = nil;
	if (complete) {
		dispatch_async(queue, ^{
			if (shouldSendFinishedNotification) {
				dispatch_async(dispatch_get_main_queue(), ^{
					NSNotificationCenter *dc = [NSNotificationCenter defaultCenter];
					[dc postNotificationName:kNetworkConnectionFinished object:self];
				});
			}
			complete(self, data, error);
		});
	}
	if (complete) {
		DDLogVerbose(@"complete block is still valid");
	}
	conn = nil;
	return complete;
}

- (NSInteger) statusCode {
	return response.statusCode;
}

- (NSDictionary *) headers {
	return response.allHeaderFields;
}

- (NSURL *) url {
	return request.URL;
}

- (NSURLResponse *) response {
	return response;
}

- (void) cancel {
	if (conn) {
		[conn cancel];
		conn = nil;
	}
}

#pragma mark -
#pragma mark NSURLConnection delegate methods

- (BOOL) connection:(NSURLConnection *)connection
canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace
{
	if ([protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
		if (kGRNetworkAllowInsecureConnections) {
			return YES;
		}
		else {
			return NO;
		}
	}
	return NO;
}

- (void) connection:(NSURLConnection *)connection
didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)_challenge
{
	DDLogVerbose(@"auth challenge: host = %@", _challenge);
	NSURLProtectionSpace *space = [_challenge protectionSpace];
	if ([[space authenticationMethod] isEqualToString:NSURLAuthenticationMethodServerTrust]) {
		if (kGRNetworkAllowInsecureConnections == NO) {
			self.challenge = _challenge;
			NSString *title = @"There is a problem with the server certificate.";
			NSString *message = @"Would you like to connect anyway?";
			if ([challenge error]) {
				NSDictionary *userInfo = [[challenge error] userInfo];
				if ([[challenge error] localizedDescription]) {
					title = [[challenge error] localizedDescription];
				}
				if ([userInfo objectForKey:NSLocalizedRecoverySuggestionErrorKey]) {
					message = [userInfo objectForKey:NSLocalizedRecoverySuggestionErrorKey];
				}
			}
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
															message:message
														   delegate:self
												  cancelButtonTitle:@"Cancel"
												  otherButtonTitles:@"OK",nil];
			[alert show];
		}
		else {
			[_challenge.sender
			 useCredential:[NSURLCredential credentialForTrust:_challenge.protectionSpace.serverTrust]
			 forAuthenticationChallenge:_challenge
			 ];
		}
	}
}

- (void) connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	[self notifyDelegate:responseData error:error];
}

- (NSURLRequest *) connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)inRequest redirectResponse:(NSURLResponse *)redirectResponse
{
	GRRedirectPolicy policy = GRRedirectPolicyCloneOriginalRequest;
	if (redirectResponse) {
		if ([redirectResponse isKindOfClass:[NSHTTPURLResponse class]]) {
			NSInteger statusCode = [(NSHTTPURLResponse *)redirectResponse statusCode];
			NSNumber *policyWrapper = getRedirectPolicyForStatusCode(statusCode);
			if (policyWrapper) {
				policy = (GRRedirectPolicy)policyWrapper.intValue;
			}
		}
		DDLogInfo(@"request to '%@' being re-directed to '%@'", request.URL, inRequest.URL);
		switch (policy) {
			case GRRedirectPolicyCloneOriginalRequest:
			{
				DDLogInfo(@"using redirect-policy GRRedirectPolicyCloneOriginalRequest");
				NSMutableURLRequest *redirectRequest = [request mutableCopy];
				redirectRequest.URL = inRequest.URL;
				return redirectRequest;
				break;
			}
			case GRRedirectPolicyDiscardOriginalRequest:
			case GRRedirectPolicyUseSystemDefault:
			{
				return inRequest;
				break;
			}
		}
	}
	else {
		return inRequest;
	}
}

- (void) connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)_response {
	NSDate *curDate = [NSDate date];
	self.responseData = nil;
	response = (NSHTTPURLResponse *)_response;
	if ([response expectedContentLength] != NSURLResponseUnknownLength) {
		contentLength = [response expectedContentLength];
		self.responseData = [NSMutableData dataWithCapacity:(NSUInteger)contentLength];
	}
	else {
		contentLength = -1;
		self.responseData = [NSMutableData dataWithCapacity:1024];
	}
	NSDictionary *headers = [response allHeaderFields];
	NSString *date = [headers objectForKey:@"Date"];
	if (date) {
		// parse the HTTP date header and calculate a time diff
		[GRNetwork updateDriftBetweenDate:curDate andHeader:date];
	}
}

- (void) connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	[responseData appendData:data];
	if (progressBlock) {
		GRProgressCallback localProgress = progressBlock;
		dispatch_async(queue, ^{
			localProgress(self, DownloadProgress, [responseData length], contentLength);
		});
	}
}

- (void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite
{
	if (progressBlock) {
		GRProgressCallback localProgress = progressBlock;
		dispatch_async(queue, ^{
			localProgress(self, UploadProgress, totalBytesWritten, totalBytesExpectedToWrite);
		});
	}
}

- (void) connectionDidFinishLoading:(NSURLConnection *)connection {
	//	NSLog(@"connection finished (%d), response len: %d", [self.response statusCode], [responseObj.responseData length]);
	[self notifyDelegate:responseData error:nil];
}

#pragma mark - UIAlertView delegate

- (void) alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
	if (alertView.cancelButtonIndex != buttonIndex) {
		if (challenge) {
			[challenge.sender
			 useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust]
			 forAuthenticationChallenge:challenge
			 ];
			self.challenge = nil;
		}
	}
}

@end