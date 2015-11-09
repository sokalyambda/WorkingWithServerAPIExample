//
//  SESessionManager.m
//  WorkWithServerAPI
//
//  Created by EugeneS on 30.01.15.
//  Copyright (c) 2015 ThinkMobiles. All rights reserved.
//

#import "ESNetworkManager.h"
#import "ESNetworkOperation.h"
#import "ESNetworkRequest.h"

#import <AFNetworking.h>

static CGFloat const kRequestTimeInterval = 60.f;
static NSInteger const kMaxConcurentRequests = 100.f;
static NSInteger const kAllCleansCount = 1.f;

static NSString *const kCleanSessionLock = @"CleanSessionLock";

@interface ESNetworkManager ()

@property (copy, nonatomic) CleanBlock cleanBlock;

@property (strong, nonatomic) AFHTTPSessionManager *sessionManager;
@property (strong, nonatomic) AFHTTPRequestOperationManager *requestOperationManager;

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
        
        [[AFNetworkReachabilityManager sharedManager] startMonitoring];
        
        self.reachabilityStatus = [AFNetworkReachabilityManager sharedManager].networkReachabilityStatus;
        
        __weak typeof(self)weakSelf = self;
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
        
        __weak typeof(self)weakSelf = self;
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

- (ESNetworkOperation*)createOperationWithNetworkRequest:(ESNetworkRequest*)networkRequest success:(SuccessOperationBlock)success
                                                  failure:(FailureOperationBlock)failure
{
    NSError *error = nil;
    id manager = nil;
    
    if ([NSURLSession class]) {
        manager = _sessionManager;
    } else {
        manager = _requestOperationManager;
    }
    
    //Set needed request serializer
    switch (networkRequest.serializationType) {
        case ESRequestSerializationTypeHTTP:
            [(AFHTTPSessionManager *)manager setRequestSerializer:self.HTTPRequestSerializer];
            break;
            
        case ESRequestSerializationTypeJSON:
            [(AFHTTPSessionManager *)manager setRequestSerializer:self.JSONRequestSerializer];
            break;
            
        default:
            break;
    }
    
    ESNetworkOperation *operation = [[ESNetworkOperation alloc] initWithNetworkRequest:networkRequest networkManager:manager error:&error];
    
    __weak typeof(self)weakSelf = self;
    if (error && failure) {
        failure(operation ,error, NO);
    } else {
        [self enqueueOperation:operation success:^(ESNetworkOperation *operation) {
            
            [weakSelf finishOperationInQueue:operation];
            if (success) {
                success(operation);
            }
            
        } failure:^(ESNetworkOperation *operation, NSError *error, BOOL isCanceled) {
            
            [weakSelf finishOperationInQueue:operation];
            if (failure) {
                failure(operation, error, isCanceled);
            }
        }];
    }
    return operation;
}

- (void)enqueueOperation:(ESNetworkOperation*)operation success:(SuccessOperationBlock)success failure:(FailureOperationBlock)failure
{
    //check reachability here
    [operation setCompletionBlockAfterProcessingWithSuccess:success failure:failure];
    [self addOperationToQueue:operation];
}

/**
 *  Cancel all operations
 */
- (void)cancelAllOperations
{
    if ([NSURLSession class]) {
        for (ESNetworkOperation *operation in self.operationsQueue) {
            [operation cancel];
        }
        [self.sessionManager.operationQueue cancelAllOperations];
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
    for (ESNetworkOperation *operation in self.operationsQueue) {
        if ([operation isInProcess]) {
            return YES;
        }
    }
    return NO;
}

/**
 *  Remove operation from normal queue
 *
 *  @param operation Operation that has to be removed
 */
- (void)finishOperationInQueue:(ESNetworkOperation*)operation
{
    [self.operationsQueue removeObject:operation];
}

/**
 *  Add new operation to normal queue
 *
 *  @param operation Operation that has to be added to queue
 */
- (void)addOperationToQueue:(ESNetworkOperation*)operation
{
    [self.operationsQueue addObject:operation];
    
    [operation start];
}

@end
