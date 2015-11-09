//
//  SESessionManager.m
//  WorkWithServerAPI
//
//  Created by EugeneS on 30.01.15.
//  Copyright (c) 2015 Connexity. All rights reserved.
//

#import "ESNetworkManager.h"
#import "BZRFailedOperationManager.h"

#import "BZRNetworkOperation.h"

#import "BZRReachabilityHelper.h"

#import "BZRErrorHandler.h"

#import "BZRAlertFacade.h"

#import "BZRRenewSessionTokenRequest.h"
#import "BZRGetClientCredentialsRequest.h"

static CGFloat const kRequestTimeInterval = 60.f;
static NSInteger const kMaxConcurentRequests = 100.f;
static NSInteger const kAllCleansCount = 1.f;

static NSString *const kCleanSessionLock = @"CleanSessionLock";

@interface ESNetworkManager ()

@property (copy, nonatomic) CleanBlock cleanBlock;

@property (strong, nonatomic) AFHTTPSessionManager *sessionManager;
@property (strong, nonatomic) AFHTTPRequestOperationManager *requestOperationManager;
@property (strong, nonatomic) BZRFailedOperationManager *failedOperationManager;

@property (assign, nonatomic) AFNetworkReachabilityStatus reachabilityStatus;

@property (strong, readwrite, nonatomic) NSURL *baseURL;

@property (strong, nonatomic) NSMutableArray *operationsQueue;
@property (strong, nonatomic) NSLock *lock;

@property (assign, nonatomic) NSUInteger cleanCount;

@property (strong, nonatomic) AFHTTPRequestSerializer *HTTPRequestSerializer;
@property (strong, nonatomic) AFJSONRequestSerializer *JSONRequestSerializer;

@end

@implementation ESNetworkManager

#pragma mark - Accessors

- (BZRFailedOperationManager *)failedOperationManager
{
    if (!_failedOperationManager) {
        _failedOperationManager = [BZRFailedOperationManager sharedManager];
    }
    return _failedOperationManager;
}

- (AFJSONRequestSerializer *)JSONRequestSerializer
{
    if (!_JSONRequestSerializer) {
        _JSONRequestSerializer = [AFJSONRequestSerializer serializer];
    }
    return _JSONRequestSerializer;
}

- (AFHTTPRequestSerializer *)HTTPRequestSerializer
{
    if (!_HTTPRequestSerializer) {
        _HTTPRequestSerializer = [AFHTTPRequestSerializer serializer];
    }
    return _HTTPRequestSerializer;
}

#pragma mark - Lifecycle

- (id)initWithBaseURL:(NSURL*)url
{
    if (self = [super init]) {
        
        _baseURL = url;
        
        if ([NSURLSession class]) {
            NSURLSessionConfiguration* taskConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
            
            taskConfig.HTTPMaximumConnectionsPerHost = kMaxConcurentRequests;
            taskConfig.timeoutIntervalForRequest = kRequestTimeInterval;
            taskConfig.timeoutIntervalForResource = kRequestTimeInterval;
            taskConfig.allowsCellularAccess = YES;
            
            _sessionManager = [[AFHTTPSessionManager alloc] initWithBaseURL:url sessionConfiguration:taskConfig];
            
            [_sessionManager setResponseSerializer:[AFJSONResponseSerializer serializer]];
            [_sessionManager.responseSerializer setAcceptableContentTypes:[NSSet setWithObjects:@"application/schema+json", @"application/json", @"application/x-www-form-urlencoded", @"application/hal+json", nil]];
        } else { //iOS6 and less
            _requestOperationManager = [[AFHTTPRequestOperationManager alloc] initWithBaseURL:url];
            [_requestOperationManager setResponseSerializer:[AFJSONResponseSerializer serializer]];
            [_requestOperationManager.responseSerializer setAcceptableContentTypes:[NSSet setWithObjects:@"application/schema+json", @"application/json", @"application/x-www-form-urlencoded", @"application/hal+json", nil]];
        }
        
        _lock = [[NSLock alloc] init];
        _lock.name = kCleanSessionLock;
        
        _operationsQueue = [NSMutableArray array];
        
        WEAK_SELF;
        [[AFNetworkReachabilityManager sharedManager] startMonitoring];
        
        weakSelf.reachabilityStatus = [AFNetworkReachabilityManager sharedManager].networkReachabilityStatus;
        
        [[AFNetworkReachabilityManager sharedManager] setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
            
            weakSelf.reachabilityStatus = status;
            
#ifdef DEBUG
            NSString* stateText = nil;
            switch (weakSelf.reachabilityStatus) {
                case AFNetworkReachabilityStatusUnknown: {
                    stateText = @"Network reachability is unknown";
                    break;
                }
                case AFNetworkReachabilityStatusNotReachable: {
                    stateText = @"Network is not reachable";
                    break;
                }
                case AFNetworkReachabilityStatusReachableViaWWAN: {
                    stateText = @"Network is reachable via WWAN";
                    break;
                }
                case AFNetworkReachabilityStatusReachableViaWiFi: {
                    stateText = @"Network is reachable via WiFi";
                    break;
                }
            }
            DLog(@"%@", stateText);
#endif
        }];

        _requestNumber = 0;
        
    }
    return self;
}

#pragma mark - Actions

- (void)cleanManagersWithCompletionBlock:(CleanBlock)block
{
    if ([NSURLSession class]) {
        self.cleanCount = 0;
        self.cleanBlock = block;
        WEAK_SELF;
        [_sessionManager setSessionDidBecomeInvalidBlock:^(NSURLSession *session, NSError *error) {
            [weakSelf syncCleans];
            weakSelf.sessionManager = nil;
        }];
        [_sessionManager invalidateSessionCancelingTasks:YES];
    } else {
        _requestOperationManager = nil;
        if (block) {
            block();
        }
    }
}

- (void)syncCleans
{
    [self.lock lock];
    self.cleanCount++;
    [self.lock unlock];
    
    if (self.cleanCount == kAllCleansCount) {
        if (self.cleanBlock) {
            self.cleanBlock();
        }
    }
}

- (id)manager
{
    if (_sessionManager) {
        return _sessionManager;
    } else if (_requestOperationManager) {
        return _requestOperationManager;
    }
    return nil;
}

-(void)dealloc
{
    [[AFNetworkReachabilityManager sharedManager] stopMonitoring];
}

#pragma mark - Operation cycle

- (BZRNetworkOperation*)createOperationWithNetworkRequest:(BZRNetworkRequest*)networkRequest success:(SuccessOperationBlock)success
                                                  failure:(FailureOperationBlock)failure
{
    //set success&failure blocks to failed operation manager. This step adds a possibility to restart operation if connection failed
    if (networkRequest.retryIfConnectionFailed) {
        [self.failedOperationManager setFailedOperationSuccessBlock:success andFailureBlock:failure];
    }
    
    NSError *error = nil;
    id manager = nil;
    
    if ([NSURLSession class]) {
        manager = _sessionManager;
    } else {
        manager = _requestOperationManager;
    }
    
    switch (networkRequest.serializationType) {
        case BZRRequestSerializationTypeHTTP:
            [(AFHTTPSessionManager *)manager setRequestSerializer:self.HTTPRequestSerializer];
            break;
            
        case BZRRequestSerializationTypeJSON:
            [(AFHTTPSessionManager *)manager setRequestSerializer:self.JSONRequestSerializer];
            break;
            
        default:
            break;
    }
    
    BZRNetworkOperation *operation = [[BZRNetworkOperation alloc] initWithNetworkRequest:networkRequest networkManager:manager error:&error];
    
    WEAK_SELF;
    if (error && failure) {
        failure(operation ,error, NO);
    } else {
        [self enqueueOperation:operation success:^(BZRNetworkOperation *operation) {
            
            [weakSelf finishOperationInQueue:operation];
            if (success) {
                success(operation);
            }
            
        } failure:^(BZRNetworkOperation *operation, NSError *error, BOOL isCanceled) {
            
            [weakSelf finishOperationInQueue:operation];
            
            if ([BZRErrorHandler errorIsNetworkError:error] && operation.networkRequest.retryIfConnectionFailed) {
                
                [BZRAlertFacade showRetryInternetConnectionAlertForController:nil withCompletion:^(BOOL retry) {
                    if (!retry && failure) {
                        failure(operation, error, isCanceled);
                    } else {
                        [weakSelf.failedOperationManager addAndRestartFailedOperation:operation];
                    }
                }];
            } else if (failure) {
                failure(operation, error, isCanceled);
            }
        }];
    }
    return operation;
}

- (void)enqueueOperation:(BZRNetworkOperation*)operation success:(SuccessOperationBlock)success failure:(FailureOperationBlock)failure
{
    WEAK_SELF;
    //check reachability
    [BZRReachabilityHelper checkConnectionOnSuccess:^{
        
        [operation setCompletionBlockAfterProcessingWithSuccess:success failure:failure];
        [weakSelf addOperationToQueue:operation];
        
    } failure:^(NSError *error) {
        if (failure) {
            failure(operation, error, NO);
        }
    }];
}

/**
 *  Cancel all operations
 */
- (void)cancelAllOperations
{
    if ([NSURLSession class]) {
        @autoreleasepool {
            for (BZRNetworkOperation *operation in self.operationsQueue) {
                [operation cancel];
            }
            [self.sessionManager.operationQueue cancelAllOperations];
        }
    } else {
        [self.requestOperationManager.operationQueue cancelAllOperations];
    }
}

/**
 *  Check whether operation is in process
 *
 *  @return Returns 'YES' in any operation is in process
 */
- (BOOL)isOperationInProcess
{
    @autoreleasepool {
        for (BZRNetworkOperation *operation in self.operationsQueue) {
            if ([operation isInProcess]) {
                return YES;
            }
        }
        return NO;
    }
}

/**
 *  Remove operation from normal queue
 *
 *  @param operation Operation that has to be removed
 */
- (void)finishOperationInQueue:(BZRNetworkOperation*)operation
{
    [self.operationsQueue removeObject:operation];
}

/**
 *  Add new operation to normal queue
 *
 *  @param operation Operation that has to be added to queue
 */
- (void)addOperationToQueue:(BZRNetworkOperation*)operation
{
    [self.operationsQueue addObject:operation];
    
    [operation start];
}

@end
